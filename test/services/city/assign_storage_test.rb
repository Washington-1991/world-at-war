require "test_helper"

class City::AssignStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "assigns a valid solid resource to resource_depot and records ledger" do
    user = create_user!
    city = create_city!(user: user)

    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)

    assert_difference "LedgerEvent.count", 1 do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "food"
      )

      assert result.ok?
    end

    cb.reload
    assert_equal "food", cb.assigned_resource

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "assign_storage", event.action_type
    assert_equal city.id, event.city_id
    assert_equal user.id, event.actor_user_id
    assert_equal({}, event.delta)
    assert_equal cb.id, event.meta["city_building_id"]
    assert_equal "resource_depot", event.meta["building_key"]
    assert_nil event.meta["previous_assigned_resource"]
    assert_equal "food", event.meta["assigned_resource"]
  end

  test "assigns a valid fluid resource to fluid_depot" do
    user = create_user!
    city = create_city!(user: user)

    depot_building = fluid_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)

    assert_difference "LedgerEvent.count", 1 do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "fuel"
      )

      assert result.ok?
    end

    cb.reload
    assert_equal "fuel", cb.assigned_resource
  end

  test "rejects incompatible resource for resource_depot" do
    user = create_user!
    city = create_city!(user: user)

    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "fuel"
      )

      assert_not result.ok?
      assert_equal :incompatible_resource, result.error
    end

    cb.reload
    assert_nil cb.assigned_resource
  end

  test "rejects non assignable building" do
    user = create_user!
    city = create_city!(user: user)

    farm = create_building!(
      key: "test_assign_storage_non_assignable_#{SecureRandom.hex(6)}",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 0 }
        }
      }
    )

    cb = create_city_building!(city: city, building: farm, level: 1, workers_assigned: 0)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "food"
      )

      assert_not result.ok?
      assert_equal :building_not_assignable, result.error
    end
  end

  test "forbids assigning storage in a city not owned by user" do
    owner = create_user!(email: "owner-storage@example.com")
    attacker = create_user!(email: "attacker-storage@example.com")

    city = create_city!(user: owner)
    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignStorage.call(
        user: attacker,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "food"
      )

      assert_not result.ok?
      assert_equal :forbidden, result.error
    end
  end

  test "returns ok without ledger when resource assignment is unchanged" do
    user = create_user!
    city = create_city!(user: user)

    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)
    cb.update!(assigned_resource: "food")

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "food"
      )

      assert result.ok?
      assert_equal true, result.details[:noop]
    end
  end

  test "allows reassignment when previous resource does not overflow" do
    user = create_user!
    city = create_city!(user: user, food: 5_000, coal: 0)

    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)
    cb.update!(assigned_resource: "food")

    extra_food_depot = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)
    extra_food_depot.update!(assigned_resource: "food")

    assert_difference "LedgerEvent.count", 1 do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "coal"
      )

      assert result.ok?
    end

    cb.reload
    assert_equal "coal", cb.assigned_resource
  end

  test "rejects reassignment when it would overflow previous resource" do
    user = create_user!
    city = create_city!(user: user, food: 8_000, coal: 0)

    depot_building = resource_depot_building!
    cb = create_city_building!(city: city, building: depot_building, level: 1, workers_assigned: 0)
    cb.update!(assigned_resource: "food")

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignStorage.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        assigned_resource: "coal"
      )

      assert_not result.ok?
      assert_equal :overflow_after_reassignment, result.error
    end

    cb.reload
    assert_equal "food", cb.assigned_resource
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
