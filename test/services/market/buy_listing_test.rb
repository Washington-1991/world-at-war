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

  test "creates purchase correctly and creates logistic operation with neutral tariff" do
    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

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
    assert_equal listing.id, operation.market_listing_id
    assert_equal 4_000, operation.market_total_price
    assert_equal "food", operation.resource
    assert_equal 400, operation.amount
    assert_equal 2, operation.trucks_assigned
    assert_equal "in_transit", operation.status

    assert_equal 600, listing.amount_available
    assert_equal "partially_filled", listing.status
    assert_nil listing.sold_out_at

    assert_equal 15_600, @buyer_city.money

    event = latest_purchase_event

    assert_not_nil event
    assert_equal({ "money" => -4_400 }, event.delta)
    assert_equal listing.id, event.meta["listing_id"]
    assert_equal @buyer_city.id, event.meta["buyer_city_id"]
    assert_equal @seller_city.id, event.meta["seller_city_id"]
    assert_equal @buyer_user.id, event.meta["buyer_user_id"]
    assert_equal @seller_user.id, event.meta["seller_user_id"]
    assert_equal "food", event.meta["good_key"]
    assert_equal 400, event.meta["amount"]
    assert_equal 10, event.meta["price_per_unit"]
    assert_equal 4_000, event.meta["base_price"]
    assert_equal 4_000, event.meta["seller_receives_price"]
    assert_equal 1_000, event.meta["tariff_rate_basis_points"]
    assert_equal 400, event.meta["tariff_amount"]
    assert_equal 4_400, event.meta["total_buyer_cost"]
    assert_equal 4_400, event.meta["total_price"]
    assert_equal "money_sink", event.meta["tariff_destination"]
    assert_equal operation.id, event.meta["logistic_operation_id"]

    diplomacy = event.meta["diplomacy"]
    assert_equal @buyer_user.id, diplomacy["importer_user_id"]
    assert_equal @seller_user.id, diplomacy["exporter_user_id"]
    assert_equal false, diplomacy["same_user"]
    assert_equal true, diplomacy["allowed"]
    assert_nil diplomacy["blocked_reason"]
    assert_equal "neutral", diplomacy["importer_relation_state"]
    assert_equal "neutral", diplomacy["exporter_relation_state"]
    assert_equal "open", diplomacy["importer_effective_trade_policy"]
    assert_equal "open", diplomacy["exporter_effective_trade_policy"]
    assert_equal 1_000, diplomacy["tariff_rate_basis_points"]
    assert_equal 400, diplomacy["tariff_amount"]
    assert_equal 4_400, diplomacy["total_buyer_cost"]
  end

  test "friendly relation applies reduced tariff" do
    DiplomaticRelation.create!(
      source_user: @buyer_user,
      target_user: @seller_user,
      relation_state: :friendly
    )

    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

    Market::BuyListing.new(
      listing: listing,
      buyer_city: @buyer_city,
      actor_user: @buyer_user,
      amount: 400,
      trucks_assigned: 2,
      eta_hours: 1
    ).call

    @buyer_city.reload
    event = latest_purchase_event

    assert_equal 15_800, @buyer_city.money
    assert_equal({ "money" => -4_200 }, event.delta)
    assert_equal 4_000, event.meta["base_price"]
    assert_equal 500, event.meta["tariff_rate_basis_points"]
    assert_equal 200, event.meta["tariff_amount"]
    assert_equal 4_200, event.meta["total_buyer_cost"]
  end

  test "ally relation applies zero tariff" do
    DiplomaticRelation.create!(
      source_user: @buyer_user,
      target_user: @seller_user,
      relation_state: :ally
    )

    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

    operation = Market::BuyListing.new(
      listing: listing,
      buyer_city: @buyer_city,
      actor_user: @buyer_user,
      amount: 400,
      trucks_assigned: 2,
      eta_hours: 1
    ).call

    @buyer_city.reload
    event = latest_purchase_event

    assert_equal 16_000, @buyer_city.money
    assert_equal 4_000, operation.market_total_price
    assert_equal({ "money" => -4_000 }, event.delta)
    assert_equal 0, event.meta["tariff_rate_basis_points"]
    assert_equal 0, event.meta["tariff_amount"]
    assert_equal 4_000, event.meta["total_buyer_cost"]
  end

  test "hostile relation applies high tariff when trade is open" do
    DiplomaticRelation.create!(
      source_user: @buyer_user,
      target_user: @seller_user,
      relation_state: :hostile,
      trade_policy: :open
    )

    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

    Market::BuyListing.new(
      listing: listing,
      buyer_city: @buyer_city,
      actor_user: @buyer_user,
      amount: 400,
      trucks_assigned: 2,
      eta_hours: 1
    ).call

    @buyer_city.reload
    event = latest_purchase_event

    assert_equal 15_000, @buyer_city.money
    assert_equal 2_500, event.meta["tariff_rate_basis_points"]
    assert_equal 1_000, event.meta["tariff_amount"]
    assert_equal 5_000, event.meta["total_buyer_cost"]
  end

  test "blocks purchase when buyer embargoes seller" do
    DiplomaticRelation.create!(
      source_user: @buyer_user,
      target_user: @seller_user,
      relation_state: :hostile,
      trade_policy: :embargoed
    )

    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 400,
        trucks_assigned: 2,
        eta_hours: 1
      ).call
    end

    assert_equal "trade blocked by diplomacy: importer_embargo", error.message

    listing.reload
    @buyer_city.reload

    assert_equal 1_000, listing.amount_available
    assert_equal "active", listing.status
    assert_equal 20_000, @buyer_city.money
    assert_equal 0, LogisticOperation.where(market_listing: listing).count
  end

  test "blocks purchase when seller embargoes buyer" do
    DiplomaticRelation.create!(
      source_user: @seller_user,
      target_user: @buyer_user,
      relation_state: :enemy,
      trade_policy: :open
    )

    listing = create_food_listing(amount: 1_000, price_per_unit: 10)

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 400,
        trucks_assigned: 2,
        eta_hours: 1
      ).call
    end

    assert_equal "trade blocked by diplomacy: exporter_embargo", error.message

    listing.reload
    @buyer_city.reload

    assert_equal 1_000, listing.amount_available
    assert_equal "active", listing.status
    assert_equal 20_000, @buyer_city.money
    assert_equal 0, LogisticOperation.where(market_listing: listing).count
  end

  test "marks listing sold_out when purchase consumes all available amount" do
    listing = create_food_listing(amount: 300, price_per_unit: 10)

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
    assert_equal 16_700, @buyer_city.money
  end

  test "rejects insufficient money in buyer city including tariff" do
    listing = create_food_listing(amount: 1_000, price_per_unit: 100)

    error = assert_raises(Market::BuyListing::Error) do
      Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 200,
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
    listing = create_food_listing(amount: 200, price_per_unit: 10)

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
    listing = create_food_listing(amount: 500, price_per_unit: 10)

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
    listing = create_food_listing(amount: 500, price_per_unit: 10)

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

    listing = create_food_listing(amount: 500, price_per_unit: 10)

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

  def create_food_listing(amount:, price_per_unit:)
    Market::CreateListing.new(
      seller_city: @seller_city,
      actor_user: @seller_user,
      good_key: "food",
      amount: amount,
      price_per_unit: price_per_unit
    ).call
  end

  def latest_purchase_event
    LedgerEvent.where(
      city: @buyer_city,
      action_type: "market_purchase_started"
    ).order(:created_at).last
  end

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
