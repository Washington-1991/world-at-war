class CityBuilding < ApplicationRecord
  belongs_to :city
  belongs_to :building

  SOLID_STORAGE_RESOURCES = %w[
    food
    coal
    iron_ore
    stone
    wood
  ].freeze

  FLUID_STORAGE_RESOURCES = %w[
    crude_oil
    fuel
  ].freeze

  HALL_IDENTIFIERS = %w[
    hall
    town_hall
    townhall
    town-hall
    town hall
  ].freeze

  DEPOSIT_BUILDING_IDENTIFIERS = %w[
    resource_depot
    resource depot
    resource-depot
    resourcedepot
    deposit
    deposits
    storage_deposit
    storage deposit
    storage-deposit
  ].freeze

  FLUID_DEPOT_IDENTIFIERS = %w[
    fluid_depot
    fluid depot
    fluid-depot
    fluiddepot
    fluid_deposit
    fluid deposit
    fluid-deposit
    fluiddeposit
  ].freeze

  LOGISTIC_STATION_IDENTIFIERS = %w[
    logistic_station
    logistic station
    logistic-station
    logisticstation
  ].freeze

  before_validation :normalize_assigned_resource

  validate :hall_must_be_unique_per_city

  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :workers_assigned, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enabled, inclusion: { in: [ true, false ] }

  validates :hp,     numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_hp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :hp_must_be_nil_when_building_has_no_hp
  validate :workers_assigned_cannot_exceed_required
  validate :assigned_resource_must_match_building_type

  def workers_required
    return 0 if building.nil? || level.nil?
    building.workers_required_for(level).to_i
  end

  def trucks_capacity
    return 0 unless enabled?
    return 0 unless logistic_station_building?
    return 0 if building.nil? || level.nil?

    building.trucks_capacity_for(level).to_i
  end

  def hall_building?
    (normalized_building_identifiers & HALL_IDENTIFIERS).any?
  end

  def deposit_building?
    (normalized_building_identifiers & DEPOSIT_BUILDING_IDENTIFIERS).any?
  end

  def resource_depot_building?
    deposit_building?
  end

  def fluid_depot_building?
    (normalized_building_identifiers & FLUID_DEPOT_IDENTIFIERS).any?
  end

  def logistic_station_building?
    (normalized_building_identifiers & LOGISTIC_STATION_IDENTIFIERS).any?
  end

  def assignable_storage_building?
    deposit_building? || fluid_depot_building?
  end

  def allowed_assigned_resources
    return deposit_storage_goods if deposit_building?
    return fluid_storage_goods if fluid_depot_building?

    []
  end

  private

  def normalize_assigned_resource
    self.assigned_resource = assigned_resource.to_s.strip.downcase.presence
  end

  def normalized_building_identifiers
    return [] if building.nil?

    [
      building.try(:key),
      building.try(:code),
      building.try(:slug),
      building.try(:kind),
      building.try(:name)
    ].compact.map { |value| value.to_s.strip.downcase }
  end

  def hall_must_be_unique_per_city
    return unless city.present? && building.present?
    return unless hall_building?

    existing_hall = city.city_buildings
                        .includes(:building)
                        .where.not(id: id)
                        .any?(&:hall_building?)

    return unless existing_hall

    errors.add(:building_id, "hall is unique per city")
  end

  def hp_must_be_nil_when_building_has_no_hp
    return if building.nil? || building.has_hp?

    errors.add(:hp, "must be nil for this building") unless hp.nil?
    errors.add(:max_hp, "must be nil for this building") unless max_hp.nil?
  end

  def workers_assigned_cannot_exceed_required
    return if building.nil? || level.nil? || workers_assigned.nil?

    required = workers_required
    return if workers_assigned <= required

    errors.add(:workers_assigned, "cannot exceed workers_required (#{required}) for this level")
  end

  def assigned_resource_must_match_building_type
    return if building.nil?

    if deposit_building?
      return if assigned_resource.nil?
      return if deposit_storage_goods.include?(assigned_resource)

      errors.add(:assigned_resource, "is not compatible with resource_depot")
      return
    end

    if fluid_depot_building?
      return if assigned_resource.nil?
      return if fluid_storage_goods.include?(assigned_resource)

      errors.add(:assigned_resource, "is not compatible with fluid_depot")
      return
    end

    if assigned_resource.present?
      errors.add(:assigned_resource, "must be nil for non-storage buildings")
    end
  end

  def deposit_storage_goods
    GoodCatalog.keys.select do |good_key|
      GoodCatalog.final_storage_target_for(good_key) == "deposit"
    end
  end

  def fluid_storage_goods
    GoodCatalog.keys.select do |good_key|
      GoodCatalog.final_storage_target_for(good_key) == "fluid_deposit"
    end
  end
end
