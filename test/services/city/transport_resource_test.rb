require "test_helper"

class City::TransportResourceTest < ActiveSupport::TestCase
  include WawFactories

  test "creates a transport operation, deducts origin resource and reserves trucks" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    origin.update!(wood: 1_000)
    destination.update!(wood: 0)

    ensure_logistic_station!(origin, trucks_capacity: 100)

    now = Time.current
    operation = nil

    assert_difference("LogisticOperation.count", 1) do
      operation = City::TransportResource.new(
        origin_city: origin,
        destination_city: destination,
        actor_user: user,
        resource_key: "wood",
        amount: 300,
        trucks_assigned: 40,
        eta_hours: 3,
        now: now
      ).call
    end

    origin.reload
    destination.reload
    operation.reload

    assert_equal "in_transit", operation.status
    assert_equal origin.id, operation.origin_city_id
    assert_equal destination.id, operation.destination_city_id
    assert_equal "wood", operation.resource
    assert_equal 300, operation.amount
    assert_equal 40, operation.trucks_assigned
    assert_equal now.to_i, operation.started_at.to_i
    assert_equal (now + 3.hours).to_i, operation.arrival_at.to_i

    assert_equal 700, origin.wood
    assert_equal 0, destination.wood
    assert_equal 60, origin.available_trucks_capacity
  end

  test "rejects transport when origin resource is insufficient" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    origin.update!(wood: 50)
    destination.update!(wood: 0)

    ensure_logistic_station!(origin, trucks_capacity: 100)

    assert_no_difference("LogisticOperation.count") do
      error = assert_raises(City::TransportResource::Error) do
        City::TransportResource.new(
          origin_city: origin,
          destination_city: destination,
          actor_user: user,
          resource_key: "wood",
          amount: 300,
          trucks_assigned: 20
        ).call
      end

      assert_equal "insufficient resource in origin city", error.message
    end

    origin.reload
    destination.reload

    assert_equal 50, origin.wood
    assert_equal 0, destination.wood
    assert_equal 100, origin.available_trucks_capacity
  end

  test "rejects transport when available trucks are insufficient" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    origin.update!(wood: 1_000)
    destination.update!(wood: 0)

    ensure_logistic_station!(origin, trucks_capacity: 10)

    assert_no_difference("LogisticOperation.count") do
      error = assert_raises(City::TransportResource::Error) do
        City::TransportResource.new(
          origin_city: origin,
          destination_city: destination,
          actor_user: user,
          resource_key: "wood",
          amount: 100,
          trucks_assigned: 20
        ).call
      end

      assert_equal "insufficient available trucks", error.message
    end

    origin.reload
    destination.reload

    assert_equal 1_000, origin.wood
    assert_equal 0, destination.wood
    assert_equal 10, origin.available_trucks_capacity
  end

  test "rejects transport between cities not owned by actor" do
    owner = create_user!
    intruder = create_user!

    origin = create_city!(user: owner)
    destination = create_city!(user: owner)

    origin.update!(wood: 1_000)
    destination.update!(wood: 0)

    ensure_logistic_station!(origin, trucks_capacity: 100)

    assert_no_difference("LogisticOperation.count") do
      error = assert_raises(City::TransportResource::Error) do
        City::TransportResource.new(
          origin_city: origin,
          destination_city: destination,
          actor_user: intruder,
          resource_key: "wood",
          amount: 100,
          trucks_assigned: 20
        ).call
      end

      assert_equal "forbidden for origin city", error.message
    end

    origin.reload
    destination.reload

    assert_equal 1_000, origin.wood
    assert_equal 0, destination.wood
    assert_equal 100, origin.available_trucks_capacity
  end

  test "rejects transport when origin and destination are the same city" do
    user = create_user!
    city = create_city!(user: user)

    city.update!(wood: 1_000)

    ensure_logistic_station!(city, trucks_capacity: 100)

    assert_no_difference("LogisticOperation.count") do
      error = assert_raises(City::TransportResource::Error) do
        City::TransportResource.new(
          origin_city: city,
          destination_city: city,
          actor_user: user,
          resource_key: "wood",
          amount: 100,
          trucks_assigned: 20
        ).call
      end

      assert_equal "origin and destination must be different cities", error.message
    end

    city.reload
    assert_equal 1_000, city.wood
    assert_equal 100, city.available_trucks_capacity
  end

  private

  def ensure_logistic_station!(city, trucks_capacity:)
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
          "trucks_capacity" => trucks_capacity
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
