require "test_helper"

class Market::BuyListingTest < ActiveSupport::TestCase
  include WawFactories

  def setup
    @seller_user = create_user!
    @buyer_user = create_user!

    @seller_city = create_city!(user: @seller_user, food: 10_000)
    @buyer_city = create_city!(user: @buyer_user, money: 20_000)

    ensure_hall_for!(@seller_city)
    ensure_hall_for!(@buyer_city)
    ensure_logistic_station_for!(@seller_city)
    ensure_logistic_station_for!(@buyer_city)

    @seller_city.reload
    @buyer_city.reload
  end

  test "creates purchase correctly and creates logistic operation" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 1_000,
      price_per_unit: 10
    ).call

    operation = Market::BuyListing.new(
      listing: listing,
      buyer_city: @buyer_city,
      actor_user: @buyer_user,
      amount: 400,
      trucks_assigned: 2,
      eta_hours: 2
    ).call

    listing.reload
    @buyer_city.reload

    assert operation.persisted?
    assert_equal @seller_city.id, operation.origin_city_id
    assert_equal @buyer_city.id, operation.destination_city_id
    assert_equal "food", operation.resource
    assert_equal 400, operation.amount
    assert_equal 2, operation.trucks_assigned
    assert_equal "in_transit", operation.status

    assert_equal 600, listing.amount_available
    assert_equal "partially_filled", listing.status
    assert_nil listing.sold_out_at

    assert_equal 16_000, @buyer_city.money

    event = LedgerEvent.where(
      city: @buyer_city,
      action_type: "market_purchase_started"
    ).order(:created_at).last

    assert_not_nil event
    assert_equal({ "money" => -4_000 }, event.delta)
    assert_equal listing.id, event.meta["listing_id"]
    assert_equal @buyer_city.id, event.meta["buyer_city_id"]
    assert_equal @seller_city.id, event.meta["seller_city_id"]
    assert_equal "food", event.meta["good_key"]
    assert_equal 400, event.meta["amount"]
    assert_equal 10, event.meta["price_per_unit"]
    assert_equal 4_000, event.meta["total_price"]
    assert_equal operation.id, event.meta["logistic_operation_id"]
  end

  test "marks listing sold_out when purchase consumes all available amount" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 300,
      price_per_unit: 10
    ).call

    Market::BuyListing.new(
      listing: listing,
      buyer_city: @buyer_city,
      actor_user: @buyer_user,
      amount: 300,
      trucks_assigned: 1,
      eta_hours: 1
    ).call

    listing.reload
    @buyer_city.reload

    assert_equal 0, listing.amount_available
    assert_equal "sold_out", listing.status
    assert_not_nil listing.sold_out_at
    assert_equal 17_000, @buyer_city.money
  end

  test "rejects insufficient money in buyer city" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 1_000,
      price_per_unit: 100
    ).call

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 500,
        trucks_assigned: 2,
        eta_hours: 1
      ).call
    end

    assert_equal "insufficient money in buyer city", error.message

    listing.reload
    @buyer_city.reload

    assert_equal 1_000, listing.amount_available
    assert_equal "active", listing.status
    assert_equal 20_000, @buyer_city.money
  end

  test "rejects insufficient listing amount available" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 200,
      price_per_unit: 10
    ).call

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 300,
        trucks_assigned: 2,
        eta_hours: 1
      ).call
    end

    assert_equal "insufficient listing amount available", error.message
  end

  test "rejects insufficient free logistic capacity in buyer city" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 500,
      price_per_unit: 10
    ).call

    fill_buyer_logistics_to_capacity_for!("food")

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 100,
        trucks_assigned: 1,
        eta_hours: 1
      ).call
    end

    assert_equal "insufficient free logistic capacity in buyer city", error.message
  end

  test "rejects insufficient available trucks in seller city" do
    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 500,
      price_per_unit: 10
    ).call

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 100,
        trucks_assigned: 999,
        eta_hours: 1
      ).call
    end

    assert_equal "insufficient available trucks in seller city", error.message
  end

  test "rejects forbidden buyer city ownership" do
    intruder = create_user!

    listing = Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: 500,
      price_per_unit: 10
    ).call

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: intruder,
        amount: 100,
        trucks_assigned: 1,
        eta_hours: 1
      ).call
    end

    assert_equal "forbidden for buyer city", error.message
  end

  test "rejects cancelled listing" do
    listing = MarketListing.create!(
      seller_user: @seller_user,
      seller_city: @seller_city,
      good_key: "food",
      amount_total: 500,
      amount_available: 0,
      amount_return_pending: 500,
      price_per_unit: 10,
      currency_key: "money",
      status: "cancelled",
      cancelled_at: Time.current
    )

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 100,
        trucks_assigned: 1,
        eta_hours: 1
      ).call
    end

    assert_equal "listing is cancelled", error.message
  end

  private

  def ensure_hall_for!(city)
    hall_building = Building.find_or_create_by!(key: "hall") do |building|
      building.name = "Hall"
      building.infrastructure_cost = 0
      building.rules = {
        "levels" => {
          "1" => {
            "workers_required" => 0
          }
        }
      }
    end

    CityBuilding.find_or_create_by!(city: city, building: hall_building) do |city_building|
      city_building.level = 1
      city_building.workers_assigned = 0
      city_building.enabled = true
    end
  end

  def ensure_logistic_station_for!(city)
    station_building = Building.find_or_initialize_by(key: "logistic_station")
    station_building.name = "Logistic Station"
    station_building.infrastructure_cost = 0
    station_building.rules = {
      "levels" => {
        "1" => {
          "workers_required" => 0,
          "trucks_capacity" => 100
        }
      }
    }
    station_building.save!

    CityBuilding.find_or_create_by!(city: city, building: station_building) do |city_building|
      city_building.level = 1
      city_building.workers_assigned = 0
      city_building.enabled = true
    end
  end

  def fill_buyer_logistics_to_capacity_for!(good_key)
    capacity = @buyer_city.logistic_capacity_for(good_key)

    stock = @buyer_city.city_logistic_stocks.find_or_initialize_by(good_key: good_key)
    stock.amount = capacity
    stock.save!
  end
end
