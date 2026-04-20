require "test_helper"

class Market::WithdrawPendingReturnTest < ActiveSupport::TestCase
  include WawFactories

  def setup
    @user = create_user!
    @city = create_city!(user: @user)
    ensure_hall_for!(@city)
    @city.reload
  end

  test "withdraws full pending return when enough storage is available" do
    listing = create_cancelled_listing_with_pending(amount: 500)

    @city.update!(food: @city.max_storage_for("food") - 500)

    result = Market::WithdrawPendingReturn.new(
      listing: listing,
      actor_user: @user
    ).call

    @city.reload
    result.reload

    assert_equal 0, result.amount_return_pending
    assert_equal @city.max_storage_for("food"), @city.food

    event = LedgerEvent.where(
      city: @city,
      action_type: "market_return_withdrawn"
    ).order(:created_at).last

    assert_not_nil event
    assert_equal({ "food" => 500 }, event.delta)
    assert_equal listing.id, event.meta["listing_id"]
    assert_equal 500, event.meta["amount"]
  end

  test "withdraws partially when storage is limited" do
    listing = create_cancelled_listing_with_pending(amount: 500)

    @city.update!(food: @city.max_storage_for("food") - 200)

    result = Market::WithdrawPendingReturn.new(
      listing: listing,
      actor_user: @user
    ).call

    @city.reload
    result.reload

    assert_equal 300, result.amount_return_pending
    assert_equal @city.max_storage_for("food"), @city.food

    event = LedgerEvent.where(
      city: @city,
      action_type: "market_return_withdrawn"
    ).order(:created_at).last

    assert_not_nil event
    assert_equal({ "food" => 200 }, event.delta)
    assert_equal 200, event.meta["amount"]
  end

  test "rejects when there are no pending returns" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 100,
      price_per_unit: 2
    ).call

    error = assert_raises(Market::WithdrawPendingReturn::Error) do
      Market::WithdrawPendingReturn.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    assert_equal "no pending returns to withdraw", error.message
  end

  test "rejects when there is no storage capacity available" do
    listing = create_cancelled_listing_with_pending(amount: 500)

    @city.update!(food: @city.max_storage_for("food"))

    error = assert_raises(Market::WithdrawPendingReturn::Error) do
      Market::WithdrawPendingReturn.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    assert_equal "no storage capacity available", error.message
  end

  test "rejects withdrawal by non owner" do
    other_user = create_user!
    listing = create_cancelled_listing_with_pending(amount: 500)

    error = assert_raises(Market::WithdrawPendingReturn::Error) do
      Market::WithdrawPendingReturn.new(
        listing: listing,
        actor_user: other_user
      ).call
    end

    assert_equal "forbidden for listing seller city", error.message
  end

  test "creates ledger event on successful withdrawal" do
    listing = create_cancelled_listing_with_pending(amount: 300)

    @city.update!(food: @city.max_storage_for("food") - 300)

    assert_difference "LedgerEvent.count", +1 do
      Market::WithdrawPendingReturn.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    event = LedgerEvent.where(
      city: @city,
      action_type: "market_return_withdrawn"
    ).order(:created_at).last

    assert_not_nil event
    assert_equal "market_return_withdrawn", event.action_type
    assert_equal @city.id, event.city_id
    assert_equal listing.id, event.meta["listing_id"]
    assert_equal 300, event.meta["amount"]
  end

  private

  def create_cancelled_listing_with_pending(amount:)
    MarketListing.create!(
      seller_user: @user,
      seller_city: @city,
      good_key: "food",
      amount_total: amount,
      amount_available: 0,
      amount_return_pending: amount,
      price_per_unit: 2,
      currency_key: "money",
      status: "cancelled",
      cancelled_at: Time.current
    )
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
end
