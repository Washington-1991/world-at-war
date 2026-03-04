class City < ApplicationRecord
  belongs_to :user
  has_many :city_buildings, dependent: :destroy

  INITIAL_POPULATION = 10_000
  STARTER_PACK       = 10_000

  before_validation :set_initial_state, on: :create

  NON_NEGATIVE_INTEGERS = %i[
    total_population free_population workers_population military_population
    university_population laboratory_population
    food coal iron_ore stone wood crude_oil fuel
    energy knowledge money
  ].freeze

  NON_NEGATIVE_INTEGERS.each do |field|
    validates field, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  validate :population_must_balance

  def tick!(now: Time.current)
    City::Tick.new(self, now: now).call
  end

  def population_breakdown_sum
    free_population + workers_population + military_population +
      university_population + laboratory_population
  end

  private

  def set_initial_state
    # Población inicial (no depende de recursos)
    if total_population.zero? &&
       free_population.zero? &&
       workers_population.zero? &&
       military_population.zero? &&
       university_population.zero? &&
       laboratory_population.zero?
      self.total_population = INITIAL_POPULATION
      self.free_population  = INITIAL_POPULATION
    end

    # Starter pack (solo setea si el campo está en 0; no pisa valores manuales)
    self.food  = STARTER_PACK if food.zero?
    self.wood  = STARTER_PACK if wood.zero?
    self.stone = STARTER_PACK if stone.zero?
    self.money = STARTER_PACK if money.zero?
  end

  def population_must_balance
    return if total_population == population_breakdown_sum
    errors.add(:total_population, "must equal sum of all population groups")
  end
end
