require "test_helper"

class CityLogisticStockTest < ActiveSupport::TestCase
  include WawFactories

  test "is valid with supported good key" do
    user = create_user!
    city = create_city!(user: user)

    stock = CityLogisticStock.new(
      city: city,
      good_key: "steel",
      amount: 500
    )

    assert stock.valid?
  end

  test "is invalid with unsupported good key" do
    user = create_user!
    city = create_city!(user: user)

    stock = CityLogisticStock.new(
      city: city,
      good_key: "unknown_good",
      amount: 500
    )

    assert_not stock.valid?
    assert_includes stock.errors[:good_key], "is not included in the list"
  end
end
