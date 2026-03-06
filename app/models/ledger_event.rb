class LedgerEvent < ApplicationRecord
  ACTION_TYPES = %w[
    tick
    assign_workers
    build
    upgrade
    admin_adjustment
  ].freeze

  ALLOWED_DELTA_KEYS = %w[
    food
    coal
    iron_ore
    stone
    wood
    crude_oil
    fuel
    energy
    knowledge
    money
  ].freeze

  MAX_ABS_DELTA_VALUE = 10_000_000

  belongs_to :city
  belongs_to :actor_user, class_name: "User", optional: true

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }

  validate :delta_must_be_a_hash
  validate :meta_must_be_a_hash
  validate :delta_keys_must_be_allowed
  validate :delta_values_must_be_integers
  validate :delta_values_must_be_within_safe_bounds

  private

  def delta_must_be_a_hash
    errors.add(:delta, "must be a hash") unless delta.is_a?(Hash)
  end

  def meta_must_be_a_hash
    errors.add(:meta, "must be a hash") unless meta.is_a?(Hash)
  end

  def delta_keys_must_be_allowed
    return unless delta.is_a?(Hash)

    invalid_keys = delta.keys.map(&:to_s) - ALLOWED_DELTA_KEYS
    return if invalid_keys.empty?

    errors.add(:delta, "contains invalid keys: #{invalid_keys.join(', ')}")
  end

  def delta_values_must_be_integers
    return unless delta.is_a?(Hash)

    invalid_pairs = delta.select do |_key, value|
      !value.is_a?(Integer)
    end

    return if invalid_pairs.empty?

    errors.add(:delta, "values must all be integers")
  end

  def delta_values_must_be_within_safe_bounds
    return unless delta.is_a?(Hash)

    out_of_bounds = delta.select do |_key, value|
      value.is_a?(Integer) && value.abs > MAX_ABS_DELTA_VALUE
    end

    return if out_of_bounds.empty?

    errors.add(:delta, "contains values outside allowed bounds")
  end
end
