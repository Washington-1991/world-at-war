require "test_helper"

class LedgerEventTest < ActiveSupport::TestCase
  include WawFactories

  test "is valid with allowed attributes for resource delta" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      actor_user: user,
      action_type: "tick",
      delta: { "food" => 10, "money" => -5 },
      meta: { "hours" => 1, "source" => "tick" }
    )

    assert event.valid?
  end

  test "is valid with empty delta for non-resource audit event" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      actor_user: user,
      action_type: "assign_workers",
      delta: {},
      meta: {
        "city_building_id" => SecureRandom.uuid,
        "workers_before" => 0,
        "workers_after" => 5
      }
    )

    assert event.valid?
  end

  test "is invalid with unknown action_type" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "hack_money",
      delta: {},
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:action_type], "is not included in the list"
  end

  test "is invalid when delta is not a hash" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: "oops",
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:delta], "must be a hash"
  end

  test "is invalid when meta is not a hash" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: {},
      meta: "oops"
    )

    assert_not event.valid?
    assert_includes event.errors[:meta], "must be a hash"
  end

  test "is invalid with unknown delta keys" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: { "gold" => 100 },
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:delta].join, "contains invalid keys"
  end

  test "is invalid when delta values are not integers" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: { "food" => "100" },
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:delta], "values must all be integers"
  end

  test "is invalid when delta value exceeds safe bounds" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: { "food" => LedgerEvent::MAX_ABS_DELTA_VALUE + 1 },
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:delta], "contains values outside allowed bounds"
  end

  test "is valid with negative integer delta inside safe bounds" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.new(
      city: city,
      action_type: "tick",
      delta: { "food" => -250 },
      meta: { "hours" => 2 }
    )

    assert event.valid?
  end

  test "belongs to city and optional actor_user" do
    user = create_user!
    city = create_city!(user: user)

    event = LedgerEvent.create!(
      city: city,
      actor_user: nil,
      action_type: "tick",
      delta: { "food" => -10 },
      meta: { "hours" => 1, "source" => "tick" }
    )

    assert_equal city.id, event.city_id
    assert_nil event.actor_user_id
  end
end
