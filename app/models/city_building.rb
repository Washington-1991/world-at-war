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

  RESOURCE_DEPOT_IDENTIFIERS = %w[
    resource_depot
    resource depot
    resource-depot
    resourcedepot
  ].freeze

  FLUID_DEPOT_IDENTIFIERS = %w[
    fluid_depot
    fluid depot
    fluid-depot
    fluiddepot
  ].freeze

  before_validation :normalize_assigned_resource

  # Solo el Hall es único por ciudad.
  # El resto de edificios son stackable.
  validate :hall_must_be_unique_per_city

  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :workers_assigned, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enabled, inclusion: { in: [ true, false ] }

  # Por ahora permitimos nil (porque aún no definimos PV por tipo/nivel)
  validates :hp,     numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_hp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :hp_must_be_nil_when_building_has_no_hp

  # ✅ Paso 2: defensa extra (anti-exploit / anti-corrupción)
  # Impide que workers_assigned supere workers_required definido en Building.rules[level]
  validate :workers_assigned_cannot_exceed_required

  # ✅ Phase 5 Step 3: assigned storage validation
  validate :assigned_resource_must_match_building_type

  # Helper usado por el service y por esta validación
  def workers_required
    return 0 if building.nil? || level.nil?
    building.workers_required_for(level).to_i
  end

  # Detecta si este CityBuilding corresponde al Hall.
  # Se intenta de forma flexible para adaptarse al schema actual.
  def hall_building?
    normalized_building_identifiers.include?("hall")
  end

  def resource_depot_building?
    (normalized_building_identifiers & RESOURCE_DEPOT_IDENTIFIERS).any?
  end

  def fluid_depot_building?
    (normalized_building_identifiers & FLUID_DEPOT_IDENTIFIERS).any?
  end

  def assignable_storage_building?
    resource_depot_building? || fluid_depot_building?
  end

  def allowed_assigned_resources
    return SOLID_STORAGE_RESOURCES if resource_depot_building?
    return FLUID_STORAGE_RESOURCES if fluid_depot_building?

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

    if resource_depot_building?
      return if assigned_resource.nil?
      return if SOLID_STORAGE_RESOURCES.include?(assigned_resource)

      errors.add(:assigned_resource, "is not compatible with resource_depot")
      return
    end

    if fluid_depot_building?
      return if assigned_resource.nil?
      return if FLUID_STORAGE_RESOURCES.include?(assigned_resource)

      errors.add(:assigned_resource, "is not compatible with fluid_depot")
      return
    end

    if assigned_resource.present?
      errors.add(:assigned_resource, "must be nil for non-storage buildings")
    end
  end
end
