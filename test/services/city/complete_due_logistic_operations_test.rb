require "test_helper"

class City::CompleteDueLogisticOperationsTest < ActiveSupport::TestCase
  include WawFactories

  test "completes due in_transit operation and delivers deposit-backed good to destination" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")

    destination.update!(wood: 0)
    create_assigned_deposit_for!(destination, resource: "wood", level: 1)
    ensure_logistic_station!(destination)

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 120,
      trucks_assigned: 10,
      status: "in_transit",
      started_at: now - 2.hours,
      eta_at: now - 5.minutes
    )

    assert_difference("LedgerEvent.count", 1) do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal 120, destination.wood
    assert_equal 0, destination.logistic_stock_for("wood")

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "transport_completed", event.action_type
    assert_equal destination.id, event.city_id
    assert_equal 120, event.delta["wood"]
  end

  test "completes due in_transit operation and delivers product to generic stored goods" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")

    create_assigned_deposit_for!(destination, resource: "steel", level: 1)
    ensure_logistic_station!(destination)

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "steel",
      amount: 150,
      trucks_assigned: 12,
      status: "in_transit",
      started_at: now - 2.hours,
      eta_at: now - 5.minutes
    )

    assert_difference("LedgerEvent.count", 1) do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal 150, destination.available_good_amount("steel")
    assert_equal 0, destination.logistic_stock_for("steel")

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "transport_completed", event.action_type
    assert_equal destination.id, event.city_id
    assert_equal 150, event.delta["steel"]
  end

  test "keeps overflow in logistic station when final storage is full" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")

    create_assigned_deposit_for!(destination, resource: "steel", level: 1)
    ensure_logistic_station!(destination)
    destination.city_stored_goods.create!(good_key: "steel", amount: 10_000)

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "steel",
      amount: 200,
      trucks_assigned: 10,
      status: "in_transit",
      started_at: now - 2.hours,
      eta_at: now - 5.minutes
    )

    assert_difference("LedgerEvent.count", 1) do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal 10_000, destination.available_good_amount("steel")
    assert_equal 200, destination.logistic_stock_for("steel")
  end

  test "does not process future in_transit operation" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")

    destination.update!(stone: 0)
    create_assigned_deposit_for!(destination, resource: "stone", level: 1)
    ensure_logistic_station!(destination)

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "stone",
      amount: 80,
      trucks_assigned: 8,
      status: "in_transit",
      started_at: now - 30.minutes,
      eta_at: now + 30.minutes
    )

    assert_no_difference("LedgerEvent.count") do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    operation.reload
    destination.reload

    assert_equal "in_transit", operation.status
    assert_nil operation.completed_at
    assert_equal 0, destination.stone
    assert_equal 0, destination.logistic_stock_for("stone")
  end

  test "running service twice does not duplicate delivered goods" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")

    destination.update!(crude_oil: 0)
    create_assigned_fluid_deposit_for!(destination, resource: "crude_oil", level: 1)
    ensure_logistic_station!(destination)

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "crude_oil",
      amount: 90,
      trucks_assigned: 9,
      status: "in_transit",
      started_at: now - 3.hours,
      eta_at: now - 20.minutes
    )

    assert_difference("LedgerEvent.count", 1) do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    snapshot_amount = destination.reload.crude_oil
    snapshot_completed_at = operation.reload.completed_at

    assert_no_difference("LedgerEvent.count") do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    destination.reload
    operation.reload

    assert_equal "completed", operation.status
    assert_equal snapshot_completed_at.to_i, operation.completed_at.to_i
    assert_equal snapshot_amount, destination.crude_oil
    assert_equal 90, destination.crude_oil
    assert_equal 0, destination.logistic_stock_for("crude_oil")
  end

  private

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

  def create_assigned_fluid_deposit_for!(city, resource:, level: 1)
    depot_building = Building.find_or_create_by!(key: "fluid_deposit") do |building|
      building.name = "Fluid Depot"
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

  def ensure_logistic_station!(city, trucks_capacity: 100)
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
