module Diplomacy
  class UpsertRelation
    class Error < StandardError; end

    def self.call(actor_user:, target_user:, relation_state: nil, trade_policy: nil, now: Time.current)
      new(
        actor_user: actor_user,
        target_user: target_user,
        relation_state: relation_state,
        trade_policy: trade_policy,
        now: now
      ).call
    end

    def initialize(actor_user:, target_user:, relation_state: nil, trade_policy: nil, now: Time.current)
      @actor_user = actor_user
      @target_user = target_user
      @relation_state = relation_state
      @trade_policy = trade_policy
      @now = now
    end

    def call
      validate_basic_rules!

      DiplomaticRelation.transaction do
        relation = find_or_initialize_relation

        previous_snapshot = snapshot_for(relation)
        action_type = relation.persisted? ? "updated" : "created"

        apply_changes!(relation)
        relation.save!

        new_snapshot = snapshot_for(relation)

        if changed_snapshot?(previous_snapshot, new_snapshot) || action_type == "created"
          create_event!(
            relation: relation,
            action_type: action_type,
            previous_snapshot: previous_snapshot,
            new_snapshot: new_snapshot
          )
        end

        relation
      end
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    end

    private

    attr_reader :actor_user, :target_user, :relation_state, :trade_policy, :now

    def validate_basic_rules!
      raise Error, "actor_user must be a persisted User" unless persisted_user?(actor_user)
      raise Error, "target_user must be a persisted User" unless persisted_user?(target_user)
      raise Error, "target_user must be different from actor_user" if actor_user.id == target_user.id

      if relation_state.present? && !DiplomaticRelation.relation_states.key?(relation_state.to_s)
        raise Error, "invalid relation_state"
      end

      if trade_policy.present? && !DiplomaticRelation.trade_policies.key?(trade_policy.to_s)
        raise Error, "invalid trade_policy"
      end
    end

    def persisted_user?(user)
      user.present? && user.is_a?(User) && user.persisted?
    end

    def find_or_initialize_relation
      DiplomaticRelation
        .lock
        .where(source_user: actor_user, target_user: target_user)
        .first_or_initialize
    end

    def apply_changes!(relation)
      relation.relation_state = relation_state.to_s if relation_state.present?
      relation.trade_policy = trade_policy.to_s if trade_policy.present?
    end

    def snapshot_for(relation)
      {
        relation_state: relation.relation_state,
        trade_policy: relation.trade_policy,
        effective_trade_policy: relation.effective_trade_policy,
        tariff_rate_basis_points: relation.tariff_rate_basis_points
      }
    end

    def changed_snapshot?(previous_snapshot, new_snapshot)
      previous_snapshot != new_snapshot
    end

    def create_event!(relation:, action_type:, previous_snapshot:, new_snapshot:)
      DiplomaticRelationEvent.create!(
        diplomatic_relation: relation,
        actor_user: actor_user,
        source_user: actor_user,
        target_user: target_user,
        action_type: action_type,
        previous_relation_state: previous_snapshot[:relation_state],
        new_relation_state: new_snapshot[:relation_state],
        previous_trade_policy: previous_snapshot[:trade_policy],
        new_trade_policy: new_snapshot[:trade_policy],
        previous_effective_trade_policy: previous_snapshot[:effective_trade_policy],
        new_effective_trade_policy: new_snapshot[:effective_trade_policy],
        previous_tariff_rate_basis_points: previous_snapshot[:tariff_rate_basis_points],
        new_tariff_rate_basis_points: new_snapshot[:tariff_rate_basis_points],
        meta: {
          "source" => "diplomacy",
          "notification_type" => "diplomatic_relation_changed",
          "source_user_id" => actor_user.id,
          "target_user_id" => target_user.id,
          "relation_id" => relation.id,
          "changed_at" => now.iso8601
        },
        created_at: now,
        updated_at: now
      )
    end
  end
end
