require "test_helper"

class Market::CancelListingTest < ActiveSupport::TestCase
  include WawFactories

  def setup
    @user = create_user!
    @city = create_city!(user: @user)
    ensure_hall_for!(@city)
    @city.reload
  end

  test "cancels listing and returns goods when enough storage" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 1_000,
      price_per_unit: 2
    ).call

    result = Market::CancelListing.new(
      listing: listing,
      actor_user: @user
    ).call

    @city.reload
    result.reload

    assert result.cancelled?
    assert_equal 0, result.amount_available
    assert_equal 0, result.amount_return_pending
    assert_equal 10_000, @city.food
  end

  test "moves excess to return_pending when storage is insufficient" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 500,
      price_per_unit: 2
    ).call

    # Simulamos que la ciudad volvió a llenarse antes de cancelar
    @city.update!(food: @city.max_storage_for("food"))

    result = Market::CancelListing.new(
      listing: listing,
      actor_user: @user
    ).call

    @city.reload
    result.reload

    assert result.cancelled?
    assert_equal 0, result.amount_available
    assert_equal 500, result.amount_return_pending
    assert_equal @city.max_storage_for("food"), @city.food
  end

  test "returns partially when storage is partially free" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 500,
      price_per_unit: 2
    ).call

    # Dejamos exactamente 200 de espacio libre antes de cancelar
    @city.update!(food: @city.max_storage_for("food") - 200)

    result = Market::CancelListing.new(
      listing: listing,
      actor_user: @user
    ).call

    @city.reload
    result.reload

    assert result.cancelled?
    assert_equal 0, result.amount_available
    assert_equal 300, result.amount_return_pending
    assert_equal @city.max_storage_for("food"), @city.food
  end

  test "rejects cancellation by non owner" do
    other_user = create_user!

    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 100,
      price_per_unit: 2
    ).call

    error = assert_raises(Market::CancelListing::Error) do
      Market::CancelListing.new(
        listing: listing,
        actor_user: other_user
      ).call
    end

    assert_equal "forbidden for listing seller city", error.message
  end

  test "rejects cancelling already cancelled listing" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 100,
      price_per_unit: 2
    ).call

    Market::CancelListing.new(
      listing: listing,
      actor_user: @user
    ).call

    error = assert_raises(Market::CancelListing::Error) do
      Market::CancelListing.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    assert_equal "listing is already cancelled", error.message
  end

  test "rejects cancelling sold_out listing" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 100,
      price_per_unit: 2
    ).call

    listing.update!(status: "sold_out", amount_available: 0)

    error = assert_raises(Market::CancelListing::Error) do
      Market::CancelListing.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    assert_equal "listing is already sold out", error.message
  end

  test "creates ledger event on cancel" do
    listing = Market::CreateListing.new(
      seller_city: @city,
      actor_user: @user,
      good_key: "food",
      amount: 100,
      price_per_unit: 2
    ).call

    assert_difference "LedgerEvent.count", +1 do
      Market::CancelListing.new(
        listing: listing,
        actor_user: @user
      ).call
    end

    event = LedgerEvent.where(
      city: @city,
      action_type: "market_listing_cancelled"
    ).order(:created_at).last

    assert_not_nil event
    assert_equal "market_listing_cancelled", event.action_type
    assert_equal @city.id, event.city_id
    assert_equal listing.id, event.meta["listing_id"]
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
end
