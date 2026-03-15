class City < ApplicationRecord
  belongs_to :user
  has_many :city_buildings, dependent: :destroy
  has_many :ledger_events, dependent: :destroy

  has_many :outgoing_logistic_operations,
           class_name: "LogisticOperation",
           foreign_key: :origin_city_id,
           inverse_of: :origin_city,
           dependent: :destroy

  has_many :incoming_logistic_operations,
           class_name: "LogisticOperation",
           foreign_key: :destination_city_id,
           inverse_of: :destination_city,
           dependent: :destroy

  INITIAL_POPULATION = 10_000
  STARTER_PACK       = 10_000

  # ✅ Paso 3: Regla determinística de workforce (sin floats)
  WORKFORCE_RATE_NUM = 60
  WORKFORCE_RATE_DEN = 100

  # ✅ Phase 5: infraestructura
  BASE_INFRASTRUCTURE_CAPACITY = 500
  INFRASTRUCTURE_CAPACITY_PER_LEVEL = 500
  MAX_INFRASTRUCTURE_LEVEL = 10

  HALL_BUILDING_KEYS = %w[hall town_hall].freeze

  # ✅ Storage base del Hall
  HALL_BASE_STORAGE = {
    "food"     => 10_000,
    "wood"     => 10_000,
    "stone"    => 10_000,
    "iron_ore" => 10_000
  }.freeze

  # ✅ Phase 5 Step 2 / Step 3: storage
  STORAGE_RULES = {
    "food"      => { building_key: "resource_depot", per_level: 10_000 },
    "coal"      => { building_key: "resource_depot", per_level: 10_000 },
    "iron_ore"  => { building_key: "resource_depot", per_level: 10_000 },
    "stone"     => { building_key: "resource_depot", per_level: 10_000 },
    "wood"      => { building_key: "resource_depot", per_level: 10_000 },
    "crude_oil" => { building_key: "fluid_depot",    per_level: 10_000 },
    "fuel"      => { building_key: "fluid_depot",    per_level: 10_000 },
    "knowledge" => { building_key: "library",        per_level: 5_000 }
  }.freeze

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

  validates :infrastructure_level,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: MAX_INFRASTRUCTURE_LEVEL
            }

  validate :population_must_balance

  def tick!(now: Time.current)
    City::Tick.new(self, now: now).call
  end

  def infrastructure_capacity
    BASE_INFRASTRUCTURE_CAPACITY + (infrastructure_level * INFRASTRUCTURE_CAPACITY_PER_LEVEL)
  end

  def infrastructure_used
    city_buildings.includes(:building).sum do |city_building|
      city_building.building.infrastructure_cost_value
    end
  end

  def infrastructure_free
    infrastructure_capacity - infrastructure_used
  end

  def enough_infrastructure_for?(building)
    infrastructure_free >= building.infrastructure_cost_value
  end

  # ✅ Paso 2 — Capacidad logística server-authoritative
  def total_trucks_capacity
    city_buildings.includes(:building).sum(&:trucks_capacity)
  end

  def occupied_trucks_capacity
    outgoing_logistic_operations.active.sum(:trucks_assigned).to_i
  end

  def available_trucks_capacity
    free = total_trucks_capacity - occupied_trucks_capacity
    free.positive? ? free : 0
  end

  def enough_trucks_for?(requested_trucks)
    available_trucks_capacity >= requested_trucks.to_i
  end

  # ✅ Phase 5 Step 3 + Hall base storage
  def max_storage_for(resource)
    normalized = resource.to_s
    rule = storage_rule_for(normalized)

    hall_base = hall_base_storage_for(normalized)

    total_levels =
      case rule[:building_key]
      when "resource_depot", "fluid_depot"
        city_buildings
          .joins(:building)
          .where(buildings: { key: rule[:building_key] }, assigned_resource: normalized)
          .sum(:level)
          .to_i
      when "library"
        city_buildings
          .joins(:building)
          .where(buildings: { key: rule[:building_key] })
          .sum(:level)
          .to_i
      else
        0
      end

    hall_base + (total_levels * rule[:per_level])
  end

  # ✅ Phase 5 Step 2 / Step 3: espacio libre restante para un recurso
  def storage_free_for(resource)
    free = max_storage_for(resource) - current_resource_amount(resource)
    free.positive? ? free : 0
  end

  def population_breakdown_sum
    free_population + workers_population + military_population +
      university_population + laboratory_population
  end

  # ✅ Paso 3: calcula la capacidad de workforce desde población (server-authoritative)
  # Nota: excluimos poblaciones "especiales" para evitar free negativo.
  def compute_workers_population(total_pop = total_population)
    total = total_pop.to_i

    non_civil = military_population.to_i + university_population.to_i + laboratory_population.to_i
    base = total - non_civil
    base = 0 if base.negative?

    (base * WORKFORCE_RATE_NUM) / WORKFORCE_RATE_DEN
  end

  # ✅ Paso 3: sincroniza workforce con población y mantiene coherencia con asignaciones
  # - Recalcula workers_population desde total_population
  # - Ajusta free_population para mantener balance
  # - Deshabilitados -> workers_assigned = 0 (hardening)
  # - Rebalancea si sum(workers_assigned) > workers_population
  #
  # already_locked: true si lo llamas dentro de city.with_lock (por ejemplo, en Tick)
  def sync_workforce!(already_locked: false)
    if already_locked
      run_sync_workforce!
    else
      with_lock { run_sync_workforce! }
    end
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

      # ✅ Paso 3: inicializa workforce coherente desde el primer día
      target_workers = compute_workers_population(INITIAL_POPULATION)

      # Mantener balance exacto (otros grupos están en 0 aquí)
      self.workers_population = target_workers
      self.free_population    = INITIAL_POPULATION - target_workers
    end

    # Starter pack (solo setea si el campo está en 0; no pisa valores manuales)
    self.food  = STARTER_PACK if food.zero?
    self.wood  = STARTER_PACK if wood.zero?
    self.stone = STARTER_PACK if stone.zero?
    self.money = STARTER_PACK if money.zero?

    # ✅ Phase 5: infraestructura inicial
    self.infrastructure_level = 0 if infrastructure_level.nil?
  end

  def population_must_balance
    return if total_population == population_breakdown_sum

    errors.add(:total_population, "must equal sum of all population groups")
  end

  def storage_rule_for(resource)
    normalized = resource.to_s
    rule = STORAGE_RULES[normalized]
    raise ArgumentError, "Unsupported storage resource: #{normalized}" if rule.nil?

    rule
  end

  def hall_base_storage_for(resource)
    normalized = resource.to_s
    return 0 unless HALL_BASE_STORAGE.key?(normalized)

    hall_exists = city_buildings
                    .joins(:building)
                    .where(buildings: { key: HALL_BUILDING_KEYS })
                    .exists?

    hall_exists ? HALL_BASE_STORAGE[normalized] : 0
  end

  def current_resource_amount(resource)
    normalized = resource.to_s
    raise ArgumentError, "Unsupported storage resource: #{normalized}" unless STORAGE_RULES.key?(normalized)

    public_send(normalized).to_i
  end

  def run_sync_workforce!
    # 1) Recalcular workforce capacity
    target_workers = compute_workers_population(total_population)

    # 2) Ajustar free_population para mantener el balance (sin tocar grupos especiales)
    non_free = military_population.to_i + university_population.to_i + laboratory_population.to_i + target_workers
    new_free = total_population.to_i - non_free

    # Estado inválido (debería ser imposible si el resto está bien)
    if new_free.negative?
      raise ActiveRecord::RecordInvalid.new(self), "Invalid population breakdown: free would be negative"
    end

    update!(workers_population: target_workers, free_population: new_free)

    # 3) Hardening: buildings deshabilitados no deben consumir workforce
    city_buildings.where(enabled: false).where.not(workers_assigned: 0)
                  .update_all(workers_assigned: 0, updated_at: Time.current)

    # 4) Rebalance determinístico si hay overflow de asignaciones
    total_assigned = city_buildings.sum(:workers_assigned).to_i
    overflow = total_assigned - workers_population.to_i
    return if overflow <= 0

    city_buildings.order(id: :desc).find_each do |cb|
      break if overflow <= 0

      wa = cb.workers_assigned.to_i
      next if wa <= 0

      reduce_by = [ wa, overflow ].min
      cb.update!(workers_assigned: wa - reduce_by)
      overflow -= reduce_by
    end
  end
end
