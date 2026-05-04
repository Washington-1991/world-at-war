class DiplomaticRelation < ApplicationRecord
  belongs_to :source_user, class_name: "User"
  belongs_to :target_user, class_name: "User"

  has_many :diplomatic_relation_events,
           inverse_of: :diplomatic_relation,
           dependent: :restrict_with_exception

  enum :relation_state, {
    neutral: 0,
    friendly: 1,
    ally: 2,
    hostile: 3,
    enemy: 4,
    war: 5
  }

  enum :trade_policy, {
    open: 0,
    embargoed: 1
  }

  validates :source_user, presence: true
  validates :target_user, presence: true
  validates :source_user_id,
            uniqueness: { scope: :target_user_id }

  validate :source_and_target_must_be_different
  validate :manual_embargo_requires_negative_relation_state
  validate :ally_cannot_be_embargoed

  def effective_trade_policy
    return "embargoed" if enemy? || war?

    trade_policy
  end

  def effectively_embargoed?
    effective_trade_policy == "embargoed"
  end

  def tariff_rate_basis_points
    case relation_state
    when "ally"
      0
    when "friendly"
      500
    when "neutral"
      1_000
    when "hostile"
      2_500
    when "enemy", "war"
      nil
    else
      raise ArgumentError, "Unknown relation_state: #{relation_state}"
    end
  end

  private

  def source_and_target_must_be_different
    return if source_user_id.blank? || target_user_id.blank?

    if source_user_id == target_user_id
      errors.add(:target_user_id, "must be different from source_user_id")
    end
  end

  def manual_embargo_requires_negative_relation_state
    return unless embargoed?

    unless hostile? || enemy? || war?
      errors.add(:trade_policy, "can only be embargoed when relation_state is hostile, enemy, or war")
    end
  end

  def ally_cannot_be_embargoed
    return unless ally? && embargoed?

    errors.add(:trade_policy, "cannot be embargoed when relation_state is ally")
  end
end
