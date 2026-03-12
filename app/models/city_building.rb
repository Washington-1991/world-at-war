class CityBuilding < ApplicationRecord
  belongs_to :city
  belongs_to :building

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

  # Helper usado por el service y por esta validación
  def workers_required
    return 0 if building.nil? || level.nil?
    building.workers_required_for(level).to_i
  end

  # Detecta si este CityBuilding corresponde al Hall.
  # Se intenta de forma flexible para adaptarse al schema actual.
  def hall_building?
    return false if building.nil?

    candidates = []

    candidates << building.try(:key)
    candidates << building.try(:code)
    candidates << building.try(:slug)
    candidates << building.try(:kind)
    candidates << building.try(:name)

    candidates.compact.any? { |value| value.to_s.strip.downcase == "hall" }
  end

  private

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
end
