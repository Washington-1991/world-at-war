# app/services/city/tick.rb
class City::Tick
  BASE_POP_GROWTH_PER_HOUR = 100

  # Consumo civil: 1 hab = 0.01 comida/h => 1/100
  CIVIL_DENOM = 100

  # Consumo militar: 1 soldado = 0.0333 comida/h ~ 1/30
  MILITARY_DENOM = 30

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

      apply_population_growth(hours)
      apply_food_consumption(hours)

      # TODO: producción por edificios, energía, dinero, conocimiento, moral/emigración, etc.

      @city.last_tick_at = @now
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
end
