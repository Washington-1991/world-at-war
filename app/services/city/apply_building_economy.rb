# frozen_string_literal: true

class City
  class ApplyBuildingEconomy
    Result = Struct.new(:ok?, :error, :details, keyword_init: true)

    ERROR_INVALID_INPUT = :invalid_input

    # Whitelist: evita que rules JSONB toquen columnas no previstas (anti-exploit)
    RESOURCE_FIELDS = %i[
      food coal iron_ore stone wood crude_oil fuel
      energy knowledge money
    ].freeze

    MAX_RULE_AMOUNT = 1_000_000_000 # anti-overflow si rules están corruptas

    # hours: cantidad de horas discretas a procesar (server-side)
    def self.call(city:, hours: 1, already_locked: false)
      new(city: city, hours: hours, already_locked: already_locked).call
    end

    def initialize(city:, hours:, already_locked:)
      @city = city
      @hours_raw = hours
      @already_locked = already_locked
    end

    def call
      hours = parse_hours(@hours_raw)
      return Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { hours: @hours_raw }) if hours.nil?

      if @already_locked
        run(hours)
      else
        @city.with_lock { run(hours) }
      end
    end

    private

    def parse_hours(raw)
      h = Integer(raw)
      return nil if h <= 0
      h
    rescue ArgumentError, TypeError
      nil
    end

    def run(hours)
      # Procesar por hora evita inconsistencias cuando los recursos se agotan en medio del catch-up
      hours.times { apply_one_hour! }
      Result.new(ok?: true, details: { hours: hours })
    end

    def apply_one_hour!
      # find_each itera por PK asc (determinístico)
      @city.city_buildings.where(enabled: true).find_each do |cb|
        rules = cb.building.rules_for(cb.level)
        next if rules.blank?

        workers_required = rules.fetch("workers_required", 0).to_i
        if workers_required.positive? && cb.workers_assigned.to_i < workers_required
          next # sin workforce suficiente -> 0 producción
        end

        inputs      = normalize_resource_hash(rules["inputs"])
        outputs     = normalize_resource_hash(rules["outputs"])
        maintenance = normalize_resource_hash(rules["maintenance"])
        energy_cost = rules.fetch("energy", 0).to_i # >0 consume, <0 genera

        # Regla determinística: ALL-OR-NOTHING
        # Si falta cualquier input/maintenance/energy -> no produce
        next unless can_pay_hash?(inputs)
        next unless can_pay_hash?(maintenance)
        next if energy_cost.positive? && @city.energy.to_i < energy_cost

        # Consumir
        pay_hash!(inputs)
        pay_hash!(maintenance)
        @city.energy = @city.energy.to_i - energy_cost if energy_cost != 0

        # Producir
        gain_hash!(outputs)
      end

      # Guardar una sola vez por hora (coherencia + rendimiento)
      @city.save!
    end

    def normalize_resource_hash(h)
      return {} unless h.is_a?(Hash)

      out = {}
      h.each do |k, v|
        sym = k.to_s.to_sym
        next unless RESOURCE_FIELDS.include?(sym)

        amount = safe_amount(v)
        next if amount <= 0

        out[sym] = (out[sym] || 0) + amount
      end
      out
    end

    def safe_amount(v)
      n = Integer(v)
      return 0 if n <= 0
      return MAX_RULE_AMOUNT if n > MAX_RULE_AMOUNT
      n
    rescue ArgumentError, TypeError
      0
    end

    def can_pay_hash?(costs)
      costs.all? { |field, amount| @city.public_send(field).to_i >= amount }
    end

    def pay_hash!(costs)
      costs.each do |field, amount|
        @city.public_send("#{field}=", @city.public_send(field).to_i - amount)
      end
    end

    def gain_hash!(gains)
      gains.each do |field, amount|
        @city.public_send("#{field}=", @city.public_send(field).to_i + amount)
      end
    end
  end
end
