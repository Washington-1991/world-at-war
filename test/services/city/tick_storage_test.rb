require "test_helper"

class CityTickStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "tick caps solid resource production at storage limit" do
    user = create_user!
    city = create_city!(user: user, food: 19_900)

    create_hall_for!(city)
    assign_resource_depot!(city: city, resource: "food", level: 1)

    building = create_building!(
      key: "food_output_#{SecureRandom.hex(4)}",
      rules: {
        "levels" => {
          "1" => {
            "workers_required" => 10,
            "outputs" => { "food" => 200 }
          }
        }
      }
    )

    create_city_building!(city: city, building: building, level: 1, workers_assigned: 10)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    city.tick!(now: now)

    city.reload
    assert_equal 20_000, city.food
  end

  test "tick caps fluid resource production at storage limit" do
    user = create_user!
    city = create_city!(user: user, fuel: 9_900)

    create_hall_for!(city)
    assign_fluid_depot!(city: city, resource: "fuel", level: 1)

    building = create_building!(
      key: "fuel_output_#{SecureRandom.hex(4)}",
      rules: {
        "levels" => {
          "1" => {
            "workers_required" => 10,
            "outputs" => { "fuel" => 200 }
          }
        }
      }
    )

    create_city_building!(city: city, building: building, level: 1, workers_assigned: 10)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    city.tick!(now: now)

    city.reload
    assert_equal 10_000, city.fuel
  end

  test "tick records truncated_resources in ledger meta when storage cap is hit" do
    user = create_user!
    city = create_city!(user: user, food: 9_950)

    create_hall_for!(city)
    # Hall protege wood y stone; food queda solo con su storage base del hall.
    # No añadimos resource_depot para food para que food sea el único truncado.
    building = create_building!(
      key: "food_truncate_#{SecureRandom.hex(4)}",
      rules: {
        "levels" => {
          "1" => {
            "workers_required" => 10,
            "outputs" => { "food" => 100 }
          }
        }
      }
    )

    create_city_building!(city: city, building: building, level: 1, workers_assigned: 10)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    assert_difference "LedgerEvent.count", 1 do
      city.tick!(now: now)
    end

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "tick", event.action_type
    assert_equal [ "food" ], event.meta["truncated_resources"]
  end

  private

  def create_hall_for!(city, level: 1)
    hall = Building.find_or_create_by!(key: "hall") do |building|
      building.name = "Hall"
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

    create_city_building!(
      city: city,
      building: hall,
      level: level,
      workers_assigned: 0
    )
  end

  def assign_resource_depot!(city:, resource:, level: 1)
    depot = Building.find_or_create_by!(key: "resource_depot") do |building|
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

    create_city_building!(
      city: city,
      building: depot,
      level: level,
      workers_assigned: 0,
      assigned_resource: resource
    )
  end

  def assign_fluid_depot!(city:, resource:, level: 1)
    depot = Building.find_or_create_by!(key: "fluid_depot") do |building|
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

    create_city_building!(
      city: city,
      building: depot,
      level: level,
      workers_assigned: 0,
      assigned_resource: resource
    )
  end
end
