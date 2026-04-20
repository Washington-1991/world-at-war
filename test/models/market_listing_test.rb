require "test_helper"

class MarketListingTest < ActiveSupport::TestCase
  include WawFactories

  def build_listing(attrs = {})
    seller_user = attrs.delete(:seller_user) || create_user!
    seller_city = attrs.delete(:seller_city) || create_city!(user: seller_user)

    MarketListing.new(
      {
        seller_user: seller_user,
        seller_city: seller_city,
        good_key: "steel",
        amount_total: 1_000,
        amount_available: 1_000,
        amount_return_pending: 0,
        price_per_unit: 20,
        currency_key: "money",
        status: "active"
      }.merge(attrs)
    )
  end

  test "is valid with valid attributes" do
    listing = build_listing

    assert listing.valid?
  end

  test "rejects invalid good_key" do
    listing = build_listing(good_key: "invalid_good")

    assert_not listing.valid?
    assert_includes listing.errors[:good_key], "is not included in GoodCatalog"
  end

  test "rejects blank good_key" do
    listing = build_listing(good_key: nil)

    assert_not listing.valid?
    assert listing.errors[:good_key].any?
  end

  test "rejects non positive amount_total" do
    listing = build_listing(amount_total: 0)

    assert_not listing.valid?
    assert listing.errors[:amount_total].any?
  end

  test "rejects negative amount_available" do
    listing = build_listing(amount_available: -1)

    assert_not listing.valid?
    assert listing.errors[:amount_available].any?
  end

  test "rejects negative amount_return_pending" do
    listing = build_listing(amount_return_pending: -1)

    assert_not listing.valid?
    assert listing.errors[:amount_return_pending].any?
  end

  test "rejects non positive price_per_unit" do
    listing = build_listing(price_per_unit: 0)

    assert_not listing.valid?
    assert listing.errors[:price_per_unit].any?
  end

  test "rejects invalid currency_key" do
    listing = build_listing(currency_key: "gold")

    assert_not listing.valid?
    assert listing.errors[:currency_key].any?
  end

  test "rejects invalid status" do
    listing = build_listing(status: "archived")

    assert_not listing.valid?
    assert listing.errors[:status].any?
  end

  test "rejects amount_available greater than amount_total" do
    listing = build_listing(amount_total: 500, amount_available: 600)

    assert_not listing.valid?
    assert_includes listing.errors[:amount_available], "cannot exceed amount_total"
  end

  test "rejects available plus return pending greater than total" do
    listing = build_listing(
      amount_total: 1_000,
      amount_available: 700,
      amount_return_pending: 400
    )

    assert_not listing.valid?
    assert_includes listing.errors[:base], "amount_available plus amount_return_pending cannot exceed amount_total"
  end

  test "sold_amount returns already sold quantity" do
    listing = build_listing(
      amount_total: 1_000,
      amount_available: 600,
      amount_return_pending: 150
    )

    assert_equal 250, listing.sold_amount
  end

  test "purchasable returns true for active" do
    listing = build_listing(status: "active")

    assert listing.purchasable?
  end

  test "purchasable returns true for partially_filled" do
    listing = build_listing(status: "partially_filled")

    assert listing.purchasable?
  end

  test "purchasable returns false for sold_out" do
    listing = build_listing(status: "sold_out")

    assert_not listing.purchasable?
  end

  test "purchasable returns false for cancelled" do
    listing = build_listing(status: "cancelled")

    assert_not listing.purchasable?
  end
end
