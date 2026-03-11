require "test_helper"

class CityInfrastructureTest < ActiveSupport::TestCase
  include WawFactories

  test "infrastructure_capacity is 500 at level 0" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(infrastructure_level: 0)

    assert_equal 500, city.infrastructure_capacity
  end

  test "infrastructure_capacity is 1000 at level 1" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(infrastructure_level: 1)

    assert_equal 1000, city.infrastructure_capacity
  end

  test "infrastructure_capacity is 5500 at level 10" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(infrastructure_level: 10)

    assert_equal 5500, city.infrastructure_capacity
  end

  test "infrastructure_used sums building infrastructure costs" do
    user = create_user!
    city = create_city!(user: user)

    farm = Building.create!(
      key: "infra_test_farm",
      name: "Infra Test Farm",
      description: "",
      image: "",
      infrastructure_cost: 8,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 120,
            "workers_required" => 100
          }
        }
      }
    )

    library = Building.create!(
      key: "infra_test_library",
      name: "Infra Test Library",
      description: "",
      image: "",
      infrastructure_cost: 5,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 100,
            "workers_required" => 10
          }
        }
      }
    )

    CityBuilding.create!(
      city: city,
      building: farm,
      level: 1,
      workers_assigned: 0,
      enabled: true,
      hp: 120,
      max_hp: 120
    )

    CityBuilding.create!(
      city: city,
      building: library,
      level: 1,
      workers_assigned: 0,
      enabled: true,
      hp: 100,
      max_hp: 100
    )

    assert_equal 13, city.infrastructure_used
  end

  test "infrastructure_free subtracts used from capacity" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(infrastructure_level: 0)

    farm = Building.create!(
      key: "infra_free_farm",
      name: "Infra Free Farm",
      description: "",
      image: "",
      infrastructure_cost: 8,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 120,
            "workers_required" => 100
          }
        }
      }
    )

    CityBuilding.create!(
      city: city,
      building: farm,
      level: 1,
      workers_assigned: 0,
      enabled: true,
      hp: 120,
      max_hp: 120
    )

    assert_equal 492, city.infrastructure_free
  end

  test "enough_infrastructure_for? returns true when city has enough free capacity" do
    user = create_user!
    city = create_city!(user: user)

    building = Building.create!(
      key: "infra_true_building",
      name: "Infra True Building",
      description: "",
      image: "",
      infrastructure_cost: 400,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 150,
            "workers_required" => 100
          }
        }
      }
    )

    assert_equal true, city.enough_infrastructure_for?(building)
  end

  test "enough_infrastructure_for? returns false when city does not have enough free capacity" do
    user = create_user!
    city = create_city!(user: user)

    building = Building.create!(
      key: "infra_false_building",
      name: "Infra False Building",
      description: "",
      image: "",
      infrastructure_cost: 600,
      has_hp: true,
      rules: {
        "levels" => {
          "1" => {
            "hp_base" => 150,
            "workers_required" => 100
          }
        }
      }
    )

    assert_equal false, city.enough_infrastructure_for?(building)
  end

  test "infrastructure_level cannot be negative" do
    user = create_user!
    city = create_city!(user: user)

    city.infrastructure_level = -1

    assert_not city.valid?
    assert_includes city.errors[:infrastructure_level], "must be greater than or equal to 0"
  end

  test "infrastructure_level cannot be greater than 10" do
    user = create_user!
    city = create_city!(user: user)

    city.infrastructure_level = 11

    assert_not city.valid?
    assert_includes city.errors[:infrastructure_level], "must be less than or equal to 10"
  end
end
