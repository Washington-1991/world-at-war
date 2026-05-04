require "test_helper"

class DiplomaticRelationEventTest < ActiveSupport::TestCase
  setup do
    token = SecureRandom.hex(4)

    @source_user = create_test_user!(
      email: "source-event-#{token}@example.com",
      name: "Source"
    )

    @target_user = create_test_user!(
      email: "target-event-#{token}@example.com",
      name: "Target"
    )

    @relation = DiplomaticRelation.create!(
      source_user: @source_user,
      target_user: @target_user,
      relation_state: :friendly
    )
  end

  test "is valid with required attributes" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @source_user,
      source_user: @source_user,
      target_user: @target_user,
      action_type: "created",
      previous_relation_state: "neutral",
      new_relation_state: "friendly",
      previous_trade_policy: "open",
      new_trade_policy: "open",
      previous_effective_trade_policy: "open",
      new_effective_trade_policy: "open",
      previous_tariff_rate_basis_points: 1_000,
      new_tariff_rate_basis_points: 500,
      meta: { "source" => "test" }
    )

    assert event.valid?
    assert event.unread?
    assert_not event.read?
  end

  test "requires actor to be source" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @target_user,
      source_user: @source_user,
      target_user: @target_user,
      action_type: "created",
      new_relation_state: "friendly",
      new_trade_policy: "open",
      new_effective_trade_policy: "open",
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:actor_user_id], "must be the same as source_user_id"
  end

  test "does not allow self relation event" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @source_user,
      source_user: @source_user,
      target_user: @source_user,
      action_type: "created",
      new_relation_state: "friendly",
      new_trade_policy: "open",
      new_effective_trade_policy: "open",
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:target_user_id], "must be different from source_user_id"
  end

  test "requires valid action type" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @source_user,
      source_user: @source_user,
      target_user: @target_user,
      action_type: "invalid",
      new_relation_state: "friendly",
      new_trade_policy: "open",
      new_effective_trade_policy: "open",
      meta: {}
    )

    assert_not event.valid?
  end

  test "requires valid diplomatic states" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @source_user,
      source_user: @source_user,
      target_user: @target_user,
      action_type: "created",
      new_relation_state: "invalid",
      new_trade_policy: "open",
      new_effective_trade_policy: "open",
      meta: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:base], "invalid relation_state: invalid"
  end

  test "requires meta to be a hash" do
    event = DiplomaticRelationEvent.new(
      diplomatic_relation: @relation,
      actor_user: @source_user,
      source_user: @source_user,
      target_user: @target_user,
      action_type: "created",
      new_relation_state: "friendly",
      new_trade_policy: "open",
      new_effective_trade_policy: "open",
      meta: "invalid"
    )

    assert_not event.valid?
    assert_includes event.errors[:meta], "must be a hash"
  end

  private

  def create_test_user!(email:, name:)
    User.create!(
      email: email,
      name: name,
      birth_date: Date.new(1991, 1, 1),
      birth_country: "Uruguay",
      role: :player
    )
  end
end
