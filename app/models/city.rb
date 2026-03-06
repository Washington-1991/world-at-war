class City < ApplicationRecord
  belongs_to :user
  has_many :city_buildings, dependent: :destroy

  INITIAL_POPULATION = 10_000
  STARTER_PACK       = 10_000

  # ✅ Paso 3: Regla determinística de workforce (sin floats)
  WORKFORCE_RATE_NUM = 60
  WORKFORCE_RATE_DEN = 100

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
  end

  def population_must_balance
    return if total_population == population_breakdown_sum
    errors.add(:total_population, "must equal sum of all population groups")
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
