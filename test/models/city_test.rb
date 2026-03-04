require "test_helper"

class CityTest < ActiveSupport::TestCase
  test "defaults to 10_000 pop and starter pack when empty" do
    user = users(:one)

    city = user.cities.new
    assert city.valid?, city.errors.full_messages.to_sentence

    assert_equal 10_000, city.total_population
    assert_equal 10_000, city.free_population

    assert_equal 10_000, city.food
    assert_equal 10_000, city.wood
    assert_equal 10_000, city.stone
    assert_equal 10_000, city.money
  end

  test "does not override manually provided resource values" do
    user = users(:one)

    city = user.cities.new(food: 50_000)
    assert city.valid?, city.errors.full_messages.to_sentence

    assert_equal 10_000, city.total_population
    assert_equal 10_000, city.free_population

    assert_equal 50_000, city.food
    assert_equal 10_000, city.wood
    assert_equal 10_000, city.stone
    assert_equal 10_000, city.money
  end

  test "is valid when population balances" do
    user = users(:one)

    city = user.cities.new(
      total_population: 10,
      free_population: 10,
      food: 0, wood: 0, stone: 0, money: 0
    )

    assert city.valid?, city.errors.full_messages.to_sentence
  end

  test "is invalid when population does not balance" do
    user = users(:one)

    city = user.cities.new(
      total_population: 11,
      free_population: 10,
      food: 0, wood: 0, stone: 0, money: 0
    )

    assert_not city.valid?
    assert_includes city.errors[:total_population], "must equal sum of all population groups"
  end
end
