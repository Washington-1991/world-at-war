require "test_helper"

class Market::CreateListingTest < ActiveSupport::TestCase
  include WawFactories

  test "creates listing correctly for legacy city good" do
    user = create_user!
    city = create_city!(user: user, food: 10_000)

    listing = Market::CreateListing.new(
      seller_city: city,
      actor_user: user,
      good_key: "food",
      amount: 500,
      price_per_unit: 12
    ).call

    city.reload

    assert listing.persisted?
    assert_equal user.id, listing.seller_user_id
    assert_equal city.id, listing.seller_city_id
    assert_equal "food", listing.good_key
    assert_equal 500, listing.amount_total
    assert_equal 500, listing.amount_available
    assert_equal 0, listing.amount_return_pending
    assert_equal 12, listing.price_per_unit
    assert_equal "money", listing.currency_key
    assert_equal "active", listing.status

    assert_equal 9_500, city.food

    event = city.ledger_events.order(:created_at).last
    assert_equal "market_listing_created", event.action_type
    assert_equal({ "food" => -500 }, event.delta)
    assert_equal listing.id, event.meta["listing_id"]
    assert_equal city.id, event.meta["seller_city_id"]
    assert_equal "food", event.meta["good_key"]
    assert_equal 500, event.meta["amount"]
    assert_equal 12, event.meta["price_per_unit"]
  end

  test "creates listing correctly for generic stored good" do
    user = create_user!
    city = create_city!(user: user)

    CityStoredGood.create!(
      city: city,
      good_key: "steel",
      amount: 1_000
    )

    listing = Market::CreateListing.new(
      seller_city: city,
      actor_user: user,
      good_key: "steel",
      amount: 300,
      price_per_unit: 20
    ).call

    city.reload
    stored_good = city.city_stored_goods.find_by!(good_key: "steel")

    assert listing.persisted?
    assert_equal "steel", listing.good_key
    assert_equal 300, listing.amount_total
    assert_equal 300, listing.amount_available
    assert_equal 700, stored_good.amount

    event = city.ledger_events.order(:created_at).last
    assert_equal "market_listing_created", event.action_type
    assert_equal({ "steel" => -300 }, event.delta)
  end

  test "rejects invalid good" do
    user = create_user!
    city = create_city!(user: user)

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: user,
        good_key: "gold",
        amount: 100,
        price_per_unit: 10
      ).call
    end

    assert_equal "good is invalid", error.message
  end

  test "rejects non positive amount" do
    user = create_user!
    city = create_city!(user: user)

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: user,
        good_key: "food",
        amount: 0,
        price_per_unit: 10
      ).call
    end

    assert_equal "amount must be greater than 0", error.message
  end

  test "rejects non positive price_per_unit" do
    user = create_user!
    city = create_city!(user: user)

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: user,
        good_key: "food",
        amount: 100,
        price_per_unit: 0
      ).call
    end

    assert_equal "price_per_unit must be greater than 0", error.message
  end

  test "rejects insufficient stock for legacy city good" do
    user = create_user!
    city = create_city!(user: user, food: 100)

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: user,
        good_key: "food",
        amount: 500,
        price_per_unit: 10
      ).call
    end

    assert_equal "insufficient stock in seller city", error.message
    assert_equal 0, MarketListing.count
    assert_equal 0, city.ledger_events.count
  end

  test "rejects insufficient stock for generic stored good" do
    user = create_user!
    city = create_city!(user: user)

    CityStoredGood.create!(
      city: city,
      good_key: "steel",
      amount: 100
    )

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: user,
        good_key: "steel",
        amount: 500,
        price_per_unit: 10
      ).call
    end

    assert_equal "insufficient stock in seller city", error.message
    assert_equal 0, MarketListing.count
    assert_equal 0, city.ledger_events.count
  end

  test "rejects forbidden seller city ownership" do
    owner = create_user!
    intruder = create_user!
    city = create_city!(user: owner, food: 5_000)

    error = assert_raises(Market::CreateListing::Error) do
      Market::CreateListing.new(
        seller_city: city,
        actor_user: intruder,
        good_key: "food",
        amount: 500,
        price_per_unit: 10
      ).call
    end

    assert_equal "forbidden for seller city", error.message

    city.reload
    assert_equal 5_000, city.food
    assert_equal 0, MarketListing.count
    assert_equal 0, city.ledger_events.count
  end
end
