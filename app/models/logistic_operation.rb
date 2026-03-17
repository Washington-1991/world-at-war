class LogisticOperation < ApplicationRecord
  TRANSPORTABLE_RESOURCES = %w[
    food
    coal
    iron_ore
    stone
    wood
    crude_oil
    fuel
  ].freeze

  STATUSES = {
    loading: "loading",
    in_transit: "in_transit",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  belongs_to :origin_city,
             class_name: "City",
             foreign_key: :origin_city_id,
             inverse_of: :outgoing_logistic_operations

  belongs_to :destination_city,
             class_name: "City",
             foreign_key: :destination_city_id,
             inverse_of: :incoming_logistic_operations

  before_validation :normalize_resource
  before_validation :normalize_status_value
  before_validation :apply_numeric_defaults

  enum :status, STATUSES, validate: true

  scope :active, -> { where(status: [ STATUSES[:loading], STATUSES[:in_transit] ]) }
  scope :due_for_completion, ->(now = Time.current) { in_transit.where("arrival_at <= ?", now) }

  validates :origin_city, presence: true
  validates :destination_city, presence: true

  validates :resource,
            presence: true,
            inclusion: { in: TRANSPORTABLE_RESOURCES }

  validates :amount,
            numericality: { only_integer: true, greater_than: 0 }

  validates :trucks_assigned,
            numericality: { only_integer: true, greater_than: 0 }

  validates :fuel_cost,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validates :distance_km,
            numericality: { greater_than_or_equal_to: 0 }

  validates :started_at, presence: true
  validates :arrival_at, presence: true

  validate :cities_must_be_different
  validate :arrival_must_be_after_start
  validate :completed_at_must_match_status

  # Compatibilidad legacy
  def resource_key
    resource
  end

  def resource_key=(value)
    self.resource = value
  end

  def eta_at
    arrival_at
  end

  def eta_at=(value)
    self.arrival_at = value
  end

  def fuel
    fuel_cost
  end

  def fuel=(value)
    self.fuel_cost = value
  end

  def distance
    distance_km
  end

  def distance=(value)
    self.distance_km = value
  end

  private

  def normalize_resource
    self.resource = resource.to_s.strip.downcase.presence
  end

  def normalize_status_value
    self.status = status.to_s.strip.downcase.presence if status.present?
  end

  def apply_numeric_defaults
    self.fuel_cost = 0 if fuel_cost.nil?
    self.distance_km = 0 if distance_km.nil?
  end

  def cities_must_be_different
    return if origin_city_id.blank? || destination_city_id.blank?
    return unless origin_city_id == destination_city_id

    errors.add(:destination_city_id, "must be different from origin_city_id")
  end

  def arrival_must_be_after_start
    return if started_at.blank? || arrival_at.blank?
    return if arrival_at > started_at

    errors.add(:arrival_at, "must be after started_at")
  end

  def completed_at_must_match_status
    if completed?
      errors.add(:completed_at, "must be present when status is completed") if completed_at.blank?
    else
      errors.add(:completed_at, "must be blank unless status is completed") if completed_at.present?
    end
  end
end
