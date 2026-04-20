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

  test "completes market logistic operation and settles market sale" do
    seller_user = create_user!
    buyer_user = create_user!

    seller_city = create_city!(user: seller_user, food: 10_000)
    buyer_city = create_city!(user: buyer_user, money: 20_000)

    seller_city.update_columns(money: 0)
    buyer_city.update_columns(money: 20_000)

    seller_city.reload
    buyer_city.reload

    ensure_hall_for!(seller_city)
    ensure_hall_for!(buyer_city)
    create_assigned_deposit_for!(buyer_city, resource: "food", level: 1)
    ensure_logistic_station!(seller_city)
    ensure_logistic_station!(buyer_city)

    now = Time.zone.parse("2026-03-15 12:00:00")

    assert_equal 0, seller_city.reload.money

    listing = Market::CreateListing.new(
      seller_city: seller_city,
      actor_user: seller_user,
      good_key: "food",
      amount: 1_000,
      price_per_unit: 10
    ).call

    operation = Market::BuyListing.new(
      listing: listing,
      buyer_city: buyer_city,
      actor_user: buyer_user,
      amount: 500,
      trucks_assigned: 1,
      eta_hours: 1,
      now: now - 2.hours
    ).call

    operation.update!(arrival_at: now - 5.minutes)

    assert_difference("LedgerEvent.count", 2) do
      City::CompleteDueLogisticOperations.call(now: now)
    end

    operation.reload
    seller_city.reload
    buyer_city.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal 5_000, seller_city.money

    received = buyer_city.logistic_stock_for("food") + buyer_city.available_good_amount("food")
    assert received >= 500

    market_event = LedgerEvent.where(
      city: seller_city,
      action_type: "market_sale_completed"
    ).order(:created_at).last

    assert_not_nil market_event
    assert_equal({ "money" => 5_000 }, market_event.delta)
    assert_equal operation.id, market_event.meta["logistic_operation_id"]
    assert_equal listing.id, market_event.meta["listing_id"]
    assert_equal buyer_city.id, market_event.meta["buyer_city_id"]
    assert_equal seller_city.id, market_event.meta["seller_city_id"]
    assert_equal "food", market_event.meta["good_key"]
    assert_equal 500, market_event.meta["amount"]
    assert_equal 5_000, market_event.meta["market_total_price"]
  end

  test "does not double settle market sale when completion service runs twice" do
    seller_user = create_user!
    buyer_user = create_user!

    seller_city = create_city!(user: seller_user, food: 10_000)
    buyer_city = create_city!(user: buyer_user, money: 20_000)

    seller_city.update_columns(money: 0)
    buyer_city.update_columns(money: 20_000)

    seller_city.reload
    buyer_city.reload

    ensure_hall_for!(seller_city)
    ensure_hall_for!(buyer_city)
    create_assigned_deposit_for!(buyer_city, resource: "food", level: 1)
    ensure_logistic_station!(seller_city)
    ensure_logistic_station!(buyer_city)

    now = Time.zone.parse("2026-03-15 12:00:00")

    assert_equal 0, seller_city.reload.money

    listing = Market::CreateListing.new(
      seller_city: seller_city,
      actor_user: seller_user,
      good_key: "food",
      amount: 500,
      price_per_unit: 10
    ).call

    operation = Market::BuyListing.new(
      listing: listing,
      buyer_city: buyer_city,
      actor_user: buyer_user,
      amount: 500,
      trucks_assigned: 1,
      eta_hours: 1,
      now: now - 2.hours
    ).call

    operation.update!(arrival_at: now - 5.minutes)

    City::CompleteDueLogisticOperations.call(now: now)
    City::CompleteDueLogisticOperations.call(now: now)

    seller_city.reload
    operation.reload

    assert_equal "completed", operation.status
    assert_equal 5_000, seller_city.money

    events = LedgerEvent.where(
      city: seller_city,
      action_type: "market_sale_completed"
    )

    assert_equal 1, events.count
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

  def ensure_hall_for!(city)
    building = Building.find_or_create_by!(key: "hall") do |b|
      b.name = "Hall"
      b.description = ""
      b.image = ""
      b.infrastructure_cost = 0
      b.has_hp = true
      b.rules = {
        "levels" => {
          "1" => {
            "workers_required" => 0
          }
        }
      }
    end

    city_building = CityBuilding.find_or_initialize_by(city: city, building: building)
    city_building.level = 1
    city_building.workers_assigned = 0
    city_building.enabled = true
    city_building.save!
  end
end
