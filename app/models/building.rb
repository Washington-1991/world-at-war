class Building < ApplicationRecord
  has_many :city_buildings, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :infrastructure_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # rules: jsonb
  # Estructura esperada:
  # {
  #   "1" => { "workers_required" => 100, "outputs" => {...}, "inputs" => {...}, "maintenance" => {...}, "energy" => 0 },
  #   "2" => { ... }
  # }
  def rules_for(level)
    (rules || {})[level.to_s] || {}
  end

  def workers_required_for(level)
    rules_for(level).fetch("workers_required", 0).to_i
  end
end
