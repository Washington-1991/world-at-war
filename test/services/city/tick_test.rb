require "test_helper"

class CityTickTest < ActiveSupport::TestCase
  include WawFactories

  test "first tick sets last_tick_at and does not process hours" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(last_tick_at: nil)

    now = Time.current

    assert_no_difference "LedgerEvent.count" do
      city.tick!(now: now)
    end

    city.reload
    assert_equal now.to_i, city.last_tick_at.to_i
  end

  test "tick does nothing when no full hour elapsed (anti time-travel)" do
    user = create_user!
    city = create_city!(user: user)

    now = Time.current
    city.update!(last_tick_at: now)

    snapshot = city.reload.attributes.slice("food", "money", "total_population", "free_population", "workers_population")

    assert_no_difference "LedgerEvent.count" do
      city.tick!(now: now) # 0 horas
    end

    snapshot2 = city.reload.attributes.slice("food", "money", "total_population", "free_population", "workers_population")

    assert_equal snapshot, snapshot2
  end

  test "tick caps catch-up to 72h and advances last_tick_at by processed hours" do
    user = create_user!
    city = create_city!(user: user)

    start = Time.current - 100.hours
    now = Time.current
    city.update!(last_tick_at: start)

    before_pop = city.total_population

    assert_difference "LedgerEvent.count", 1 do
      city.tick!(now: now)
    end

    city.reload

    # last_tick_at avanza 72h, no a now
    assert_equal (start + 72.hours).to_i, city.last_tick_at.to_i

    # crecimiento aplicado por 72 horas
    assert_equal before_pop + (72 * City::Tick::BASE_POP_GROWTH_PER_HOUR), city.total_population

    # balance poblacional se mantiene
    assert_equal city.total_population, city.population_breakdown_sum

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "tick", event.action_type
    assert_nil event.actor_user_id
    assert_equal city.id, event.city_id
    assert_equal 72, event.meta["hours"]
    assert_equal "tick", event.meta["source"]
    assert event.delta.key?("food"), "tick ledger should include food delta when consumption occurs"
  end

  test "tick is idempotent when called twice with the same now" do
    user = create_user!
    city = create_city!(user: user)

    now = Time.current
    city.update!(last_tick_at: now - 2.hours)

    assert_difference "LedgerEvent.count", 1 do
      city.tick!(now: now)
    end

    snapshot = city.reload.attributes.slice(
      "food", "money", "energy", "knowledge",
      "total_population", "free_population", "workers_population",
      "last_tick_at"
    )

    assert_no_difference "LedgerEvent.count" do
      city.tick!(now: now)
    end

    snapshot2 = city.reload.attributes.slice(
      "food", "money", "energy", "knowledge",
      "total_population", "free_population", "workers_population",
      "last_tick_at"
    )

    assert_equal snapshot, snapshot2
  end

  test "tick integrates building economy when rules exist and workers are sufficient" do
    user = create_user!
    city = create_city!(user: user)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    building = create_building!(
      rules: {
        "1" => {
          "workers_required" => 10,
          "outputs" => { "food" => 100 },
          "inputs" => {},
          "maintenance" => {},
          "energy" => 0
        }
      }
    )
    create_city_building!(city: city, building: building, level: 1, enabled: true, workers_assigned: 10)

    city.reload
    before_food = city.food
    before_pop  = city.total_population
    hours = 1

    # Consumo esperado según la implementación actual:
    # primero crece población y luego consume usando el total_population ya crecido
    pop_after_growth = before_pop + (hours * City::Tick::BASE_POP_GROWTH_PER_HOUR)
    civil = ((pop_after_growth * hours) + (City::Tick::CIVIL_DENOM / 2)) / City::Tick::CIVIL_DENOM
    military = ((city.military_population * hours) + (City::Tick::MILITARY_DENOM / 2)) / City::Tick::MILITARY_DENOM
    expected_consumption = civil + military

    assert_difference "LedgerEvent.count", 1 do
      city.tick!(now: now)
    end

    after_food = city.reload.food

    expected_after = before_food - expected_consumption + 100
    assert_equal expected_after, after_food

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "tick", event.action_type
    assert_nil event.actor_user_id
    assert_equal city.id, event.city_id
    assert_equal 1, event.meta["hours"]
    assert_equal "tick", event.meta["source"]
    assert_equal expected_after - before_food, event.delta["food"]
  end

  test "tick does not produce if workers are insufficient" do
    user = create_user!
    city = create_city!(user: user)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    building = create_building!(
      rules: {
        "1" => {
          "workers_required" => 10,
          "outputs" => { "food" => 100 }
        }
      }
    )
    create_city_building!(city: city, building: building, level: 1, enabled: true, workers_assigned: 0)

    city.reload
    before_food = city.food
    before_pop  = city.total_population
    hours = 1

    pop_after_growth = before_pop + (hours * City::Tick::BASE_POP_GROWTH_PER_HOUR)
    civil = ((pop_after_growth * hours) + (City::Tick::CIVIL_DENOM / 2)) / City::Tick::CIVIL_DENOM
    military = ((city.military_population * hours) + (City::Tick::MILITARY_DENOM / 2)) / City::Tick::MILITARY_DENOM
    expected_consumption = civil + military

    assert_difference "LedgerEvent.count", 1 do
      city.tick!(now: now)
    end

    after_food = city.reload.food

    expected_after = before_food - expected_consumption
    assert_equal expected_after, after_food

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "tick", event.action_type
    assert_equal expected_after - before_food, event.delta["food"]
    assert_equal 1, event.meta["hours"]
  end

  test "food never goes negative (anti-underflow)" do
    user = create_user!
    city = create_city!(user: user)

    now = Time.current
    city.update!(last_tick_at: now - 10.hours, food: 0)

    assert_no_difference "LedgerEvent.count" do
      city.tick!(now: now)
    end

    city.reload

    assert city.food >= 0
  end
end
