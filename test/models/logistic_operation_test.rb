require "test_helper"

class LogisticOperationTest < ActiveSupport::TestCase
  include WawFactories

  test "is valid with safe transport attributes" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    operation = LogisticOperation.new(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    assert operation.valid?
  end

  test "is invalid when origin and destination are the same city" do
    user = create_user!
    city = create_city!(user: user)

    operation = LogisticOperation.new(
      origin_city: city,
      destination_city: city,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    assert_not operation.valid?
    assert_includes operation.errors[:destination_city_id], "must be different from origin_city_id"
  end

  test "active scope returns loading and in_transit operations only" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    loading = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "loading",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    in_transit = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "stone",
      amount: 100,
      trucks_assigned: 10,
      status: "in_transit",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    completed = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "coal",
      amount: 100,
      trucks_assigned: 10,
      status: "completed",
      started_at: Time.current,
      eta_at: 2.hours.from_now,
      completed_at: Time.current
    )

    cancelled = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "food",
      amount: 100,
      trucks_assigned: 10,
      status: "cancelled",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    assert_includes LogisticOperation.active, loading
    assert_includes LogisticOperation.active, in_transit
    assert_not_includes LogisticOperation.active, completed
    assert_not_includes LogisticOperation.active, cancelled
  end

  test "due_for_completion returns only in_transit operations due at or before now" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)
    now = Time.current

    due_past = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: 3.hours.ago,
      eta_at: 1.hour.ago
    )

    due_now = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "stone",
      amount: 100,
      trucks_assigned: 10,
      status: "in_transit",
      started_at: 2.hours.ago,
      eta_at: now
    )

    future_in_transit = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "coal",
      amount: 100,
      trucks_assigned: 10,
      status: "in_transit",
      started_at: now,
      eta_at: 1.hour.from_now
    )

    loading_due = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "food",
      amount: 100,
      trucks_assigned: 10,
      status: "loading",
      started_at: 3.hours.ago,
      eta_at: 1.hour.ago
    )

    completed_due = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "fuel",
      amount: 100,
      trucks_assigned: 10,
      status: "completed",
      started_at: 3.hours.ago,
      eta_at: 1.hour.ago,
      completed_at: now
    )

    cancelled_due = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "crude_oil",
      amount: 100,
      trucks_assigned: 10,
      status: "cancelled",
      started_at: 3.hours.ago,
      eta_at: 1.hour.ago
    )

    result = LogisticOperation.due_for_completion(now)

    assert_includes result, due_past
    assert_includes result, due_now
    assert_not_includes result, future_in_transit
    assert_not_includes result, loading_due
    assert_not_includes result, completed_due
    assert_not_includes result, cancelled_due
  end

  test "due_for_completion uses provided now parameter" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    reference_now = Time.zone.parse("2026-03-15 12:00:00")

    due_before_reference = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: reference_now - 2.hours,
      eta_at: reference_now - 5.minutes
    )

    due_after_reference = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "stone",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: reference_now - 1.hour,
      eta_at: reference_now + 5.minutes
    )

    result = LogisticOperation.due_for_completion(reference_now)

    assert_includes result, due_before_reference
    assert_not_includes result, due_after_reference
  end

  test "is invalid when status is completed without completed_at" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    operation = LogisticOperation.new(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "completed",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    assert_not operation.valid?
    assert_includes operation.errors[:completed_at], "must be present when status is completed"
  end

  test "is invalid when completed_at is present but status is not completed" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    operation = LogisticOperation.new(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: Time.current,
      eta_at: 2.hours.from_now,
      completed_at: Time.current
    )

    assert_not operation.valid?
    assert_includes operation.errors[:completed_at], "must be blank unless status is completed"
  end
end
