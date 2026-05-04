require "test_helper"

module Diplomacy
  class UpsertRelationTest < ActiveSupport::TestCase
    setup do
      token = SecureRandom.hex(4)

      @actor_user = create_test_user!(
        email: "actor-upsert-#{token}@example.com",
        name: "Actor"
      )

      @target_user = create_test_user!(
        email: "target-upsert-#{token}@example.com",
        name: "Target"
      )
    end

    test "creates directed relation and event" do
      now = Time.current.change(usec: 0)

      relation = Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :friendly,
        now: now
      )

      assert relation.persisted?
      assert_equal @actor_user.id, relation.source_user_id
      assert_equal @target_user.id, relation.target_user_id
      assert_equal "friendly", relation.relation_state
      assert_equal "open", relation.trade_policy

      event = DiplomaticRelationEvent.order(:created_at).last

      assert_not_nil event
      assert_equal relation.id, event.diplomatic_relation_id
      assert_equal @actor_user.id, event.actor_user_id
      assert_equal @actor_user.id, event.source_user_id
      assert_equal @target_user.id, event.target_user_id
      assert_equal "created", event.action_type
      assert_equal "neutral", event.previous_relation_state
      assert_equal "friendly", event.new_relation_state
      assert_equal "open", event.previous_trade_policy
      assert_equal "open", event.new_trade_policy
      assert_equal 1_000, event.previous_tariff_rate_basis_points
      assert_equal 500, event.new_tariff_rate_basis_points
      assert_nil event.read_at
      assert_equal "diplomatic_relation_changed", event.meta["notification_type"]
    end

    test "updates only actor directed relation and does not touch inverse relation" do
      inverse = DiplomaticRelation.create!(
        source_user: @target_user,
        target_user: @actor_user,
        relation_state: :neutral
      )

      relation = Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :hostile
      )

      inverse.reload

      assert_equal "hostile", relation.relation_state
      assert_equal "neutral", inverse.relation_state
    end

    test "creates event when relation is updated" do
      relation = Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :friendly
      )

      assert_difference("DiplomaticRelationEvent.count", 1) do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @target_user,
          relation_state: :hostile
        )
      end

      relation.reload
      event = DiplomaticRelationEvent.order(:created_at).last

      assert_equal "hostile", relation.relation_state
      assert_equal "updated", event.action_type
      assert_equal "friendly", event.previous_relation_state
      assert_equal "hostile", event.new_relation_state
      assert_equal 500, event.previous_tariff_rate_basis_points
      assert_equal 2_500, event.new_tariff_rate_basis_points
    end

    test "manual embargo is audited" do
      relation = Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :hostile
      )

      assert_difference("DiplomaticRelationEvent.count", 1) do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @target_user,
          trade_policy: :embargoed
        )
      end

      relation.reload
      event = DiplomaticRelationEvent.order(:created_at).last

      assert_equal "embargoed", relation.trade_policy
      assert_equal "open", event.previous_trade_policy
      assert_equal "embargoed", event.new_trade_policy
      assert_equal "open", event.previous_effective_trade_policy
      assert_equal "embargoed", event.new_effective_trade_policy
    end

    test "enemy creates automatic effective embargo event" do
      relation = Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :enemy
      )

      event = DiplomaticRelationEvent.order(:created_at).last

      assert_equal "enemy", relation.relation_state
      assert_equal "open", relation.trade_policy
      assert_equal "embargoed", relation.effective_trade_policy
      assert_equal "neutral", event.previous_relation_state
      assert_equal "enemy", event.new_relation_state
      assert_equal "open", event.previous_effective_trade_policy
      assert_equal "embargoed", event.new_effective_trade_policy
      assert_nil event.new_tariff_rate_basis_points
    end

    test "does not create event when there is no effective change" do
      Diplomacy::UpsertRelation.call(
        actor_user: @actor_user,
        target_user: @target_user,
        relation_state: :friendly
      )

      assert_no_difference("DiplomaticRelationEvent.count") do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @target_user,
          relation_state: :friendly
        )
      end
    end

    test "rejects invalid manual embargo from neutral state" do
      error = assert_raises(Diplomacy::UpsertRelation::Error) do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @target_user,
          trade_policy: :embargoed
        )
      end

      assert_match "Trade policy can only be embargoed", error.message
    end

    test "rejects self relation" do
      error = assert_raises(Diplomacy::UpsertRelation::Error) do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @actor_user,
          relation_state: :friendly
        )
      end

      assert_equal "target_user must be different from actor_user", error.message
    end

    test "rejects invalid relation state" do
      error = assert_raises(Diplomacy::UpsertRelation::Error) do
        Diplomacy::UpsertRelation.call(
          actor_user: @actor_user,
          target_user: @target_user,
          relation_state: :invalid_state
        )
      end

      assert_equal "invalid relation_state", error.message
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
end
