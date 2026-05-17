require "test_helper"

class CitySpecializedStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "trucks use vehicle_hangar storage" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "vehicle_hangar", level: 1)

    assert_equal 100, city.max_storage_for("trucks")
  end

  test "tanks use vehicle_hangar storage" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "vehicle_hangar", level: 1)

    assert_equal 100, city.max_storage_for("tanks")
  end

  test "trucks and tanks share vehicle_hangar capacity" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "vehicle_hangar", level: 1)

    city.city_stored_goods.create!(good_key: "trucks", amount: 60)
    city.city_stored_goods.create!(good_key: "tanks", amount: 30)

    assert_equal 100, city.max_storage_for("trucks")
    assert_equal 100, city.max_storage_for("tanks")

    assert_equal 10, city.storage_free_for("trucks")
    assert_equal 10, city.storage_free_for("tanks")
  end

  test "specialized hangar capacity scales by 100 per level" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "vehicle_hangar", level: 3)

    assert_equal 300, city.max_storage_for("trucks")
    assert_equal 300, city.max_storage_for("tanks")
  end

  test "artillery_pieces use artillery_hangar storage" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "artillery_hangar", level: 1)

    assert_equal 100, city.max_storage_for("artillery_pieces")
  end

  test "aircraft use air_hangar storage" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_hangar_for!(city, key: "air_hangar", level: 1)

    assert_equal 100, city.max_storage_for("aircraft")
  end

  test "common resource_depot does not provide capacity for specialized military goods" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)

    create_assigned_deposit_for!(city, resource: "steel", level: 10)

    assert_equal 0, city.max_storage_for("trucks")
    assert_equal 0, city.max_storage_for("tanks")
    assert_equal 0, city.max_storage_for("artillery_pieces")
    assert_equal 0, city.max_storage_for("aircraft")
  end

  test "resource_depot cannot be assigned to specialized military goods" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)
    depot = resource_depot_building!

    %w[
      trucks
      tanks
      artillery_pieces
      aircraft
    ].each do |good_key|
      city_building = city.city_buildings.build(
        building: depot,
        level: 1,
        enabled: true,
        workers_assigned: 0,
        assigned_resource: good_key
      )

      refute city_building.valid?, "#{good_key} should not be assignable to resource_depot"
      assert_includes city_building.errors[:assigned_resource], "is not compatible with resource_depot"
    end
  end

  test "specialized hangars do not accept assigned_resource" do
    user = create_user!
    city = create_city!(user: user, food: 0, wood: 0, stone: 0)
    vehicle_hangar = hangar_building!(key: "vehicle_hangar")

    city_building = city.city_buildings.build(
      building: vehicle_hangar,
      level: 1,
      enabled: true,
      workers_assigned: 0,
      assigned_resource: "trucks"
    )

    refute city_building.valid?
    assert_includes city_building.errors[:assigned_resource], "must be nil for non-storage buildings"
  end

  test "receive_good_into_logistics unloads specialized good into vehicle_hangar when capacity exists" do
    user = create_user!
    city = create_city!(user: user)

    create_hangar_for!(city, key: "vehicle_hangar", level: 1)
    ensure_logistic_station!(city)

    result = nil

    city.with_lock do
      result = city.receive_good_into_logistics!("trucks", 50)
    end

    city.reload

    assert_equal 50, city.available_good_amount("trucks")
    assert_equal 0, city.logistic_stock_for("trucks")
    assert_equal 50, result[:received_amount]
    assert_equal 50, result[:unloaded_amount]
    assert_equal 0, result[:remaining_in_logistics]
  end

  test "receive_good_into_logistics keeps specialized overflow in logistic station when hangar is full" do
    user = create_user!
    city = create_city!(user: user)

    create_hangar_for!(city, key: "vehicle_hangar", level: 1)
    ensure_logistic_station!(city)

    city.city_stored_goods.create!(good_key: "trucks", amount: 60)
    city.city_stored_goods.create!(good_key: "tanks", amount: 40)

    result = nil

    city.with_lock do
      result = city.receive_good_into_logistics!("trucks", 5)
    end

    city.reload

    assert_equal 60, city.available_good_amount("trucks")
    assert_equal 40, city.available_good_amount("tanks")
    assert_equal 5, city.logistic_stock_for("trucks")
    assert_equal 5, result[:received_amount]
    assert_equal 0, result[:unloaded_amount]
    assert_equal 5, result[:remaining_in_logistics]
  end

  private

  def create_hangar_for!(city, key:, level: 1)
    building = hangar_building!(key: key)

    create_city_building!(
      city: city,
      building: building,
      level: level,
      enabled: true,
      workers_assigned: 0
    )
  end

  def hangar_building!(key:)
    name = key.split("_").map(&:capitalize).join(" ")

    Building.find_or_create_by!(key: key) do |building|
      building.name = name
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
  end

  def create_assigned_deposit_for!(city, resource:, level: 1)
    depot_building = resource_depot_building!

    create_city_building!(
      city: city,
      building: depot_building,
      level: level,
      enabled: true,
      workers_assigned: 0,
      assigned_resource: resource
    )
  end

  def resource_depot_building!
    Building.find_or_create_by!(key: "resource_depot") do |building|
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
  end

  def ensure_logistic_station!(city)
    station = Building.find_or_create_by!(key: "logistic_station") do |building|
      building.name = "Logistic Station"
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {
        "levels" => {
          "1" => {
            "workers_required" => 0,
            "trucks_capacity" => 100
          }
        }
      }
    end

    create_city_building!(
      city: city,
      building: station,
      level: 1,
      enabled: true,
      workers_assigned: 0
    )
  end
end
