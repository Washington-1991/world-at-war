# app/services/city/tick.rb
class City::Tick
  BASE_POP_GROWTH_PER_HOUR = 100

  # Consumo civil: 1 hab = 0.01 comida/h => 1/100
  CIVIL_DENOM = 100

  # Consumo militar: 1 soldado = 0.0333 comida/h ~ 1/30
  MILITARY_DENOM = 30

  # ✅ Anti-DoS / anti-overflow: máximo catch-up por request
  MAX_HOURS_PER_TICK = 72

  RESOURCE_KEYS = %w[
    food
    coal
    iron_ore
    stone
    wood
    crude_oil
    fuel
    energy
    knowledge
    money
  ].freeze

  STORAGE_CAPPED_RESOURCE_KEYS = %w[
    food
    coal
    iron_ore
    stone
    wood
    crude_oil
    fuel
    knowledge
  ].freeze

  def initialize(city, now: Time.current)
    @city = city
    @now  = now
  end

  def call
    @city.with_lock do
      # Primer tick: fijamos el punto de partida (evita “ticks gigantes” al crear)
      if @city.last_tick_at.nil?
        @city.last_tick_at = @now
        @city.save!
        return @city
      end

      hours = hours_elapsed
      return @city if hours <= 0

      # ✅ Cap: evita que un jugador fuerce catch-up enorme y te tumbe el servidor
      hours = [ hours, MAX_HOURS_PER_TICK ].min

      before_resources = resource_snapshot

      apply_population_growth(hours)
      apply_food_consumption(hours)

      # ✅ Paso 3: recalcula workers_population desde población y rebalancea asignaciones si hace falta
      @city.sync_workforce!(already_locked: true)

      # ✅ Paso 4: producción económica por edificios (server-authoritative)
      City::ApplyBuildingEconomy.call(city: @city, hours: hours, already_locked: true)

      # ✅ Phase 5 Step 2: hard cap de almacenamiento (anti-overflow)
      truncated_resources = enforce_storage_caps!

      after_resources = resource_snapshot
      delta = compute_resource_delta(before_resources, after_resources)

      record_tick_ledger_event!(delta: delta, hours: hours, truncated_resources: truncated_resources) if delta.any? || truncated_resources.any?

      # ✅ Idempotencia: avanzamos last_tick_at solo lo procesado
      @city.last_tick_at = @city.last_tick_at + hours.hours
      @city.save!
    end

    @city
  end

  private

  def hours_elapsed
    ((@now - @city.last_tick_at) / 1.hour).floor
  end

  def apply_population_growth(hours)
    growth = BASE_POP_GROWTH_PER_HOUR * hours
    @city.total_population += growth
    @city.free_population  += growth
  end

  def apply_food_consumption(hours)
    civil = ((@city.total_population * hours) + (CIVIL_DENOM / 2)) / CIVIL_DENOM
    military = ((@city.military_population * hours) + (MILITARY_DENOM / 2)) / MILITARY_DENOM
    total = civil + military

    @city.food -= total
    @city.food = 0 if @city.food < 0
  end

  def enforce_storage_caps!
    truncated = []

    STORAGE_CAPPED_RESOURCE_KEYS.each do |resource|
      current_amount = @city.public_send(resource).to_i
      max_storage = @city.max_storage_for(resource)

      next if current_amount <= max_storage

      @city.public_send("#{resource}=", max_storage)
      truncated << resource
    end

    truncated
  end

  def resource_snapshot
    RESOURCE_KEYS.index_with do |key|
      @city.public_send(key).to_i
    end
  end

  def compute_resource_delta(before_resources, after_resources)
    RESOURCE_KEYS.each_with_object({}) do |key, acc|
      diff = after_resources.fetch(key).to_i - before_resources.fetch(key).to_i
      acc[key] = diff if diff != 0
    end
  end

  def record_tick_ledger_event!(delta:, hours:, truncated_resources:)
    meta = {
      "hours" => hours,
      "source" => "tick"
    }

    meta["truncated_resources"] = truncated_resources if truncated_resources.any?

    LedgerEvent.create!(
      city: @city,
      actor_user: nil,
      action_type: "tick",
      delta: delta,
      meta: meta
    )
  end
end
