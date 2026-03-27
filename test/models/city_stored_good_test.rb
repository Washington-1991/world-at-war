require "test_helper"

class CityStoredGoodTest < ActiveSupport::TestCase
  include WawFactories

  test "is valid with supported generic stored good key" do
    user = create_user!
    city = create_city!(user: user)

    stock = CityStoredGood.new(
      city: city,
      good_key: "steel",
      amount: 500
    )

    assert stock.valid?
  end

  test "is invalid for legacy city-column goods" do
    user = create_user!
    city = create_city!(user: user)

    stock = CityStoredGood.new(
      city: city,
      good_key: "wood",
      amount: 500
    )

    assert_not stock.valid?
    assert_includes stock.errors[:good_key], "is not included in the list"
  end
end
