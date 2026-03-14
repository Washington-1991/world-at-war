require "test_helper"

class CityStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "resource_depot capacity stacks across multiple buildings for the same assigned resource" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    depot = resource_depot_building!

    create_city_building!(city: city, building: depot, level: 1, assigned_resource: "food")
    create_city_building!(city: city, building: depot, level: 1, assigned_resource: "food")

    assert_equal 20_000, city.max_storage_for(:food)
    assert_equal 0, city.max_storage_for(:coal)
  end

  test "resource_depot capacity scales with total levels for the assigned resource" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    depot = resource_depot_building!

    create_city_building!(city: city, building: depot, level: 4, assigned_resource: "food")

    assert_equal 40_000, city.max_storage_for(:food)
    assert_equal 0, city.max_storage_for(:wood)
  end

  test "fluid_depot capacity applies only to its assigned fluid" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    depot = fluid_depot_building!

    create_city_building!(city: city, building: depot, level: 2, assigned_resource: "crude_oil")
    create_city_building!(city: city, building: depot, level: 1, assigned_resource: "fuel")

    assert_equal 20_000, city.max_storage_for(:crude_oil)
    assert_equal 10_000, city.max_storage_for(:fuel)
  end

  test "library capacity still applies automatically to knowledge" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    library = library_building!

    create_city_building!(city: city, building: library, level: 2)

    assert_equal 10_000, city.max_storage_for(:knowledge)
  end

  test "unassigned storage building contributes no capacity" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    depot = resource_depot_building!

    create_city_building!(city: city, building: depot, level: 2, assigned_resource: nil)

    assert_equal 0, city.max_storage_for(:food)
    assert_equal 0, city.max_storage_for(:wood)
  end

  test "storage_free_for returns remaining capacity" do
    user = create_user!
    city = create_city!(user: user, food: 5_000, wood: 0, stone: 0)

    depot = resource_depot_building!

    create_city_building!(city: city, building: depot, level: 2, assigned_resource: "food")

    assert_equal 15_000, city.storage_free_for(:food)
  end

  test "storage_free_for never returns negative values" do
    user = create_user!
    city = create_city!(user: user, food: 25_000, wood: 0, stone: 0)

    depot = resource_depot_building!

    create_city_building!(city: city, building: depot, level: 2, assigned_resource: "food")

    assert_equal 0, city.storage_free_for(:food)
  end

  private

  def resource_depot_building!
    Building.find_or_create_by!(key: "resource_depot") do |building|
      building.name = "Resource Depot"
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {
        "levels" => {
          "1" => { "workers_required" => 0 }
        }
      }
    end
  end

  def fluid_depot_building!
    Building.find_or_create_by!(key: "fluid_depot") do |building|
      building.name = "Fluid Depot"
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {
        "levels" => {
          "1" => { "workers_required" => 0 }
        }
      }
    end
  end

  def library_building!
    Building.find_or_create_by!(key: "library") do |building|
      building.name = "Library"
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {
        "levels" => {
          "1" => { "workers_required" => 0 }
        }
      }
    end
  end
end
