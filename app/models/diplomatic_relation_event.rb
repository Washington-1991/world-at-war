class DiplomaticRelationEvent < ApplicationRecord
  ACTION_TYPES = %w[
    created
    updated
  ].freeze

  belongs_to :diplomatic_relation
  belongs_to :actor_user, class_name: "User"
  belongs_to :source_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }

  validates :new_relation_state, presence: true
  validates :new_trade_policy, presence: true
  validates :new_effective_trade_policy, presence: true

  validate :meta_must_be_a_hash
  validate :actor_must_be_source
  validate :source_and_target_must_be_different
  validate :states_must_be_valid_diplomatic_states
  validate :trade_policies_must_be_valid_policies

  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(target_user: user) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  private

  def meta_must_be_a_hash
    errors.add(:meta, "must be a hash") unless meta.is_a?(Hash)
  end

  def actor_must_be_source
    return if actor_user_id.blank? || source_user_id.blank?
    return if actor_user_id == source_user_id

    errors.add(:actor_user_id, "must be the same as source_user_id")
  end

  def source_and_target_must_be_different
    return if source_user_id.blank? || target_user_id.blank?
    return unless source_user_id == target_user_id

    errors.add(:target_user_id, "must be different from source_user_id")
  end

  def states_must_be_valid_diplomatic_states
    valid_states = DiplomaticRelation.relation_states.keys

    [
      previous_relation_state,
      new_relation_state
    ].compact.each do |state|
      next if valid_states.include?(state)

      errors.add(:base, "invalid relation_state: #{state}")
    end
  end

  def trade_policies_must_be_valid_policies
    valid_policies = DiplomaticRelation.trade_policies.keys

    [
      previous_trade_policy,
      new_trade_policy,
      previous_effective_trade_policy,
      new_effective_trade_policy
    ].compact.each do |policy|
      next if valid_policies.include?(policy)

      errors.add(:base, "invalid trade_policy: #{policy}")
    end
  end
end
