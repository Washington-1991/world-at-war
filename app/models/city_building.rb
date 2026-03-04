class CityBuilding < ApplicationRecord
  belongs_to :city
  belongs_to :building

  validates :building_id, uniqueness: { scope: :city_id }

  validates :level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :workers_assigned, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enabled, inclusion: { in: [ true, false ] }

  # Por ahora permitimos nil (porque aún no definimos PV por tipo/nivel)
  validates :hp,     numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_hp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  validate :hp_must_be_nil_when_building_has_no_hp

  private

  def hp_must_be_nil_when_building_has_no_hp
    return if building.nil? || building.has_hp?

    errors.add(:hp, "must be nil for this building") unless hp.nil?
    errors.add(:max_hp, "must be nil for this building") unless max_hp.nil?
  end
end
