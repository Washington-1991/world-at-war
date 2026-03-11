require "test_helper"

class CityBuildBuildingTest < ActiveSupport::TestCase
  include WawFactories

  test "builds a building when infrastructure and resources are sufficient and records ledger" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(wood: 100, stone: 100, money: 100)

    building = Building.create!(
      key: "test_farm",
      name: "Test Farm",
      description: "",
      image: "",
      infrastructure_cost: 8,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 120,
            "workers_required" => 100,
            "build_cost" => {
              "wood" => 50,
              "stone" => 30,
              "money" => 20
            }
          }
        }
      }
    )

    assert_difference -> { city.city_buildings.count }, +1 do
      assert_difference -> { city.ledger_events.count }, +1 do
        City::BuildBuilding.new(city: city, building_key: building.key, actor_user: user).call
      end
    end

    city.reload
    city_building = city.city_buildings.find_by(building_id: building.id)
    ledger_event = city.ledger_events.order(:created_at).last

    assert_not_nil city_building
    assert_equal 1, city_building.level
    assert_equal 0, city_building.workers_assigned
    assert_equal true, city_building.enabled
    assert_equal 120, city_building.hp
    assert_equal 120, city_building.max_hp
    assert_equal 8, city.infrastructure_used
    assert_equal 492, city.infrastructure_free
    assert_equal 50, city.wood
    assert_equal 70, city.stone
    assert_equal 80, city.money

    assert_not_nil ledger_event
    assert_equal "build", ledger_event.action_type
    assert_equal user.id, ledger_event.actor_user_id
    assert_equal(-50, ledger_event.delta["wood"])
    assert_equal(-30, ledger_event.delta["stone"])
    assert_equal(-20, ledger_event.delta["money"])
    assert_equal "test_farm", ledger_event.meta["building_key"]
    assert_equal 1, ledger_event.meta["level"]
    assert_equal city_building.id, ledger_event.meta["city_building_id"]
  end

  test "raises when building does not exist" do
    user = create_user!
    city = create_city!(user: user)

    assert_raises(City::BuildBuilding::BuildingNotFoundError) do
      City::BuildBuilding.new(city: city, building_key: "missing_building").call
    end

    assert_equal 0, city.ledger_events.count
  end

  test "raises when infrastructure is insufficient" do
    user = create_user!
    city = create_city!(user: user)

    building = Building.create!(
      key: "huge_building",
      name: "Huge Building",
      description: "",
      image: "",
      infrastructure_cost: 999,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 200,
            "workers_required" => 100,
            "build_cost" => {
              "wood" => 10
            }
          }
        }
      }
    )

    assert_raises(City::BuildBuilding::NotEnoughInfrastructureError) do
      City::BuildBuilding.new(city: city, building_key: building.key).call
    end

    assert_equal 0, city.city_buildings.count
    assert_equal 0, city.ledger_events.count
  end

  test "raises when building already exists in the city" do
    user = create_user!
    city = create_city!(user: user)

    building = Building.create!(
      key: "unique_building",
      name: "Unique Building",
      description: "",
      image: "",
      infrastructure_cost: 8,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 150,
            "workers_required" => 100,
            "build_cost" => {
              "wood" => 10
            }
          }
        }
      }
    )

    CityBuilding.create!(
      city: city,
      building: building,
      level: 1,
      workers_assigned: 0,
      enabled: true,
      hp: 150,
      max_hp: 150
    )

    assert_raises(City::BuildBuilding::BuildingAlreadyExistsError) do
      City::BuildBuilding.new(city: city, building_key: building.key).call
    end

    assert_equal 0, city.ledger_events.count
  end

  test "raises when resources are insufficient" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(wood: 10, stone: 5, money: 0)

    building = Building.create!(
      key: "expensive_building",
      name: "Expensive Building",
      description: "",
      image: "",
      infrastructure_cost: 8,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 150,
            "workers_required" => 100,
            "build_cost" => {
              "wood" => 50,
              "stone" => 30,
              "money" => 20
            }
          }
        }
      }
    )

    assert_raises(City::BuildBuilding::NotEnoughResourcesError) do
      City::BuildBuilding.new(city: city, building_key: building.key).call
    end

    city.reload
    assert_equal 0, city.city_buildings.count
    assert_equal 10, city.wood
    assert_equal 5, city.stone
    assert_equal 0, city.money
    assert_equal 0, city.ledger_events.count
  end
end
