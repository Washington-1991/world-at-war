class Building < ApplicationRecord
  has_many :city_buildings, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :infrastructure_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
