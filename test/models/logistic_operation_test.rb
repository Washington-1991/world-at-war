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

  test "active scope returns only in_transit operations" do
    user = create_user!
    origin = create_city!(user: user)
    destination = create_city!(user: user)

    active = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "wood",
      amount: 100,
      trucks_assigned: 20,
      status: "in_transit",
      started_at: Time.current,
      eta_at: 2.hours.from_now
    )

    finished = LogisticOperation.create!(
      origin_city: origin,
      destination_city: destination,
      resource_key: "stone",
      amount: 100,
      trucks_assigned: 10,
      status: "completed",
      started_at: Time.current,
      eta_at: 2.hours.from_now,
      completed_at: Time.current
    )

    assert_includes LogisticOperation.active, active
    assert_not_includes LogisticOperation.active, finished
  end
end
