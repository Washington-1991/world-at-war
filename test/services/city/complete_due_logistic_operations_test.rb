require "test_helper"

class City::CompleteDueLogisticOperationsTest < ActiveSupport::TestCase
  include WawFactories

  test "completes due in_transit operation and credits resource to destination city" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    initial_wood = destination.reload.wood

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

    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal initial_wood + 120, destination.wood
  end

  test "does not process future in_transit operation" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    initial_stone = destination.reload.stone

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

    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "in_transit", operation.status
    assert_nil operation.completed_at
    assert_equal initial_stone, destination.stone
  end

  test "ignores loading operations even if arrival_at is due" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    initial_coal = destination.reload.coal

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "coal",
      amount: 70,
      trucks_assigned: 7,
      status: "loading",
      started_at: now - 2.hours,
      eta_at: now - 10.minutes
    )

    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "loading", operation.status
    assert_nil operation.completed_at
    assert_equal initial_coal, destination.coal
  end

  test "ignores cancelled operations even if arrival_at is due" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    initial_food = destination.reload.food

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "food",
      amount: 60,
      trucks_assigned: 6,
      status: "cancelled",
      started_at: now - 2.hours,
      eta_at: now - 10.minutes
    )

    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "cancelled", operation.status
    assert_nil operation.completed_at
    assert_equal initial_food, destination.food
  end

  test "does not reprocess already completed operation" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    completed_at = now - 15.minutes
    initial_fuel = destination.reload.fuel

    operation = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "fuel",
      amount: 40,
      trucks_assigned: 4,
      status: "completed",
      started_at: now - 2.hours,
      eta_at: now - 1.hour,
      completed_at: completed_at
    )

    destination.update!(fuel: initial_fuel + 40)

    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal completed_at.to_i, operation.completed_at.to_i
    assert_equal initial_fuel + 40, destination.fuel
  end

  test "running service twice does not duplicate delivered resources" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.zone.parse("2026-03-15 12:00:00")
    initial_crude_oil = destination.reload.crude_oil

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

    City::CompleteDueLogisticOperations.call(now: now)
    City::CompleteDueLogisticOperations.call(now: now)

    operation.reload
    destination.reload

    assert_equal "completed", operation.status
    assert_equal now.to_i, operation.completed_at.to_i
    assert_equal initial_crude_oil + 90, destination.crude_oil
  end
end
