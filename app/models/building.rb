class Building < ApplicationRecord
  has_many :city_buildings, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :infrastructure_cost,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # rules: jsonb
  # Estructura esperada:
  # {
  #   "levels" => {
  #     "1" => {
  #       "hp_base" => 120,
  #       "workers_required" => 100,
  #       "build_cost" => { "wood" => 50, "stone" => 30, "money" => 20 },
  #       "outputs" => {...},
  #       "inputs" => {...},
  #       "maintenance" => {...},
  #       "energy" => 0,
  #       "trucks_capacity" => 100
  #     },
  #     "2" => { ... }
  #   }
  # }
  def rules_for(level)
    (rules || {}).dig("levels", level.to_s) || {}
  end

  def workers_required_for(level)
    rules_for(level).fetch("workers_required", 0).to_i
  end

  def hp_base_for(level)
    return 0 unless has_hp?

    rules_for(level).fetch("hp_base", 0).to_i
  end

  def build_cost_for(level)
    rules_for(level).fetch("build_cost", {}).transform_keys(&:to_s)
  end

  def trucks_capacity_for(level)
    rules_for(level).fetch("trucks_capacity", 0).to_i
  end

  def infrastructure_cost_value
    infrastructure_cost.to_i
  end
end
