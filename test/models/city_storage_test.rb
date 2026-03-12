# test/models/city_storage_test.rb
require "test_helper"

class CityStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "resource depot capacity stacks across multiple buildings" do
    user = create_user!
    city = create_city!(user: user)

    depot = ensure_building!("resource_depot")

    CityBuilding.create!(city: city, building: depot, level: 1, workers_assigned: 0, enabled: true)
    CityBuilding.create!(city: city, building: depot, level: 1, workers_assigned: 0, enabled: true)

    assert_equal 20_000, city.max_storage_for(:food)
    assert_equal 20_000, city.max_storage_for(:coal)
    assert_equal 20_000, city.max_storage_for(:iron_ore)
    assert_equal 20_000, city.max_storage_for(:stone)
    assert_equal 20_000, city.max_storage_for(:wood)
  end

  test "resource depot capacity scales with total levels" do
    user = create_user!
    city = create_city!(user: user)

    depot = ensure_building!("resource_depot")

    CityBuilding.create!(city: city, building: depot, level: 1, workers_assigned: 0, enabled: true)
    CityBuilding.create!(city: city, building: depot, level: 3, workers_assigned: 0, enabled: true)

    assert_equal 40_000, city.max_storage_for(:food)
    assert_equal 40_000, city.max_storage_for(:wood)
  end

  test "fluid depot capacity applies to crude oil and fuel" do
    user = create_user!
    city = create_city!(user: user)

    fluid_depot = ensure_building!("fluid_depot")

    CityBuilding.create!(city: city, building: fluid_depot, level: 2, workers_assigned: 0, enabled: true)

    assert_equal 20_000, city.max_storage_for(:crude_oil)
    assert_equal 20_000, city.max_storage_for(:fuel)
  end

  test "library capacity applies to knowledge" do
    user = create_user!
    city = create_city!(user: user)

    library = ensure_building!("library")

    CityBuilding.create!(city: city, building: library, level: 1, workers_assigned: 0, enabled: true)
    CityBuilding.create!(city: city, building: library, level: 2, workers_assigned: 0, enabled: true)

    assert_equal 15_000, city.max_storage_for(:knowledge)
  end

  test "storage_free_for returns remaining capacity" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(food: 19_900)

    depot = ensure_building!("resource_depot")
    CityBuilding.create!(city: city, building: depot, level: 2, workers_assigned: 0, enabled: true)

    assert_equal 20_000, city.max_storage_for(:food)
    assert_equal 100, city.storage_free_for(:food)
  end

  test "storage_free_for never returns negative values" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(food: 25_000)

    depot = ensure_building!("resource_depot")
    CityBuilding.create!(city: city, building: depot, level: 2, workers_assigned: 0, enabled: true)

    assert_equal 20_000, city.max_storage_for(:food)
    assert_equal 0, city.storage_free_for(:food)
  end

  test "unsupported storage resource raises error" do
    user = create_user!
    city = create_city!(user: user)

    assert_raises(ArgumentError) do
      city.max_storage_for(:money)
    end
  end

  private

  def ensure_building!(key)
    Building.find_or_create_by!(key: key) do |building|
      building.name = key.humanize
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {}
    end
  end
end
