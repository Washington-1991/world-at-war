require "test_helper"

class CityBuildingTest < ActiveSupport::TestCase
  include WawFactories

  test "workers_assigned cannot exceed workers_required for its level" do
    user = create_user!
    city = create_city!(user: user)

    building = create_building!(
      key: "test_workers_limit_#{SecureRandom.hex(6)}",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 5 }
        }
      }
    )

    cb = create_city_building!(
      city: city,
      building: building,
      level: 1,
      workers_assigned: 5
    )

    cb.workers_assigned = 6

    assert_not cb.valid?
    assert cb.errors[:workers_assigned].any?
  end

  test "resource_depot accepts a valid solid assigned_resource" do
    user = create_user!
    city = create_city!(user: user)

    depot = resource_depot_building!

    cb = create_city_building!(city: city, building: depot, level: 1, workers_assigned: 0)
    cb.assigned_resource = "food"

    assert cb.valid?, cb.errors.full_messages.to_sentence
  end

  test "resource_depot rejects a fluid assigned_resource" do
    user = create_user!
    city = create_city!(user: user)

    depot = resource_depot_building!

    cb = create_city_building!(city: city, building: depot, level: 1, workers_assigned: 0)
    cb.assigned_resource = "fuel"

    assert_not cb.valid?
    assert_includes cb.errors[:assigned_resource], "is not compatible with resource_depot"
  end

  test "fluid_depot accepts a valid fluid assigned_resource" do
    user = create_user!
    city = create_city!(user: user)

    depot = fluid_depot_building!

    cb = create_city_building!(city: city, building: depot, level: 1, workers_assigned: 0)
    cb.assigned_resource = "fuel"

    assert cb.valid?, cb.errors.full_messages.to_sentence
  end

  test "fluid_depot rejects a solid assigned_resource" do
    user = create_user!
    city = create_city!(user: user)

    depot = fluid_depot_building!

    cb = create_city_building!(city: city, building: depot, level: 1, workers_assigned: 0)
    cb.assigned_resource = "food"

    assert_not cb.valid?
    assert_includes cb.errors[:assigned_resource], "is not compatible with fluid_depot"
  end

  test "non storage building must keep assigned_resource nil" do
    user = create_user!
    city = create_city!(user: user)

    farm = create_building!(
      key: "test_non_storage_#{SecureRandom.hex(6)}",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 0 }
        }
      }
    )

    cb = create_city_building!(city: city, building: farm, level: 1, workers_assigned: 0)
    cb.assigned_resource = "food"

    assert_not cb.valid?
    assert_includes cb.errors[:assigned_resource], "must be nil for non-storage buildings"
  end

  test "storage buildings may keep assigned_resource nil for now" do
    user = create_user!
    city = create_city!(user: user)

    depot = resource_depot_building!

    cb = create_city_building!(city: city, building: depot, level: 1, workers_assigned: 0)
    cb.assigned_resource = nil

    assert cb.valid?, cb.errors.full_messages.to_sentence
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
end
