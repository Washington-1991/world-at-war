require "test_helper"

class CityGoodsStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "receive_good_into_logistics unloads legacy resource into city storage when capacity exists" do
    user = create_user!
    city = create_city!(user: user)

    create_hall_for!(city)
    create_assigned_deposit_for!(city, resource: "wood", level: 1)
    ensure_logistic_station!(city)

    city.update!(wood: 0)

    result = nil

    city.with_lock do
      result = city.receive_good_into_logistics!("wood", 500)
    end

    city.reload

    assert_equal 500, city.wood
    assert_equal 0, city.logistic_stock_for("wood")
    assert_equal 500, result[:received_amount]
    assert_equal 500, result[:unloaded_amount]
    assert_equal 0, result[:remaining_in_logistics]
  end

  test "receive_good_into_logistics unloads product into generic stored goods when deposit capacity exists" do
    user = create_user!
    city = create_city!(user: user)

    create_assigned_deposit_for!(city, resource: "steel", level: 1)
    ensure_logistic_station!(city)

    result = nil

    city.with_lock do
      result = city.receive_good_into_logistics!("steel", 500)
    end

    city.reload

    assert_equal 500, city.available_good_amount("steel")
    assert_equal 0, city.logistic_stock_for("steel")
    assert_equal 500, result[:received_amount]
    assert_equal 500, result[:unloaded_amount]
    assert_equal 0, result[:remaining_in_logistics]
  end

  test "receive_good_into_logistics keeps overflow in logistic station when final storage is full" do
    user = create_user!
    city = create_city!(user: user)

    create_assigned_deposit_for!(city, resource: "steel", level: 1)
    ensure_logistic_station!(city)

    city.city_stored_goods.create!(good_key: "steel", amount: 10_000)

    result = nil

    city.with_lock do
      result = city.receive_good_into_logistics!("steel", 500)
    end

    city.reload

    assert_equal 10_000, city.available_good_amount("steel")
    assert_equal 500, city.logistic_stock_for("steel")
    assert_equal 500, result[:received_amount]
    assert_equal 0, result[:unloaded_amount]
    assert_equal 500, result[:remaining_in_logistics]
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
          "1" => {
            "workers_required" => 0
          }
        }
      }
    end

    create_city_building!(
      city: city,
      building: hall,
      level: level,
      enabled: true,
      workers_assigned: 0
    )
  end

  def create_assigned_deposit_for!(city, resource:, level: 1)
    depot_building = Building.find_or_create_by!(key: "resource_depot") do |building|
      building.name = "Resource Depot"
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {
        "levels" => {
          "1" => {
            "workers_required" => 0
          }
        }
      }
    end

    create_city_building!(
      city: city,
      building: depot_building,
      level: level,
      enabled: true,
      workers_assigned: 0,
      assigned_resource: resource
    )
  end

  def ensure_logistic_station!(city)
    building = Building.find_or_initialize_by(key: "logistic_station")
    building.name = "Logistic Station"
    building.description = ""
    building.image = ""
    building.infrastructure_cost = 6
    building.has_hp = true
    building.rules = {
      "levels" => {
        "1" => {
          "hp_base" => 140,
          "workers_required" => 20,
          "build_cost" => {},
          "trucks_capacity" => 100
        }
      }
    }
    building.save!

    city_building = CityBuilding.find_or_initialize_by(city: city, building: building)
    city_building.level = 1
    city_building.workers_assigned = 0
    city_building.enabled = true
    city_building.save!
  end
end
