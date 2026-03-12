# test/services/city/tick_storage_test.rb
require "test_helper"

class CityTickStorageTest < ActiveSupport::TestCase
  include WawFactories

  test "tick caps solid resource production at storage limit" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(food: 19_900)

    depot = ensure_building!("resource_depot")
    CityBuilding.create!(city: city, building: depot, level: 2, workers_assigned: 0, enabled: true)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    replacement = lambda do |city:, hours:, already_locked:|
      assert_equal 1, hours
      assert_equal true, already_locked

      city.food += 300
    end

    with_apply_building_economy_stub(replacement) do
      City::Tick.new(city, now: now).call
    end

    city.reload
    assert_equal 20_000, city.food
  end

  test "tick caps fluid resource production at storage limit" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(fuel: 9_900)

    fluid_depot = ensure_building!("fluid_depot")
    CityBuilding.create!(city: city, building: fluid_depot, level: 1, workers_assigned: 0, enabled: true)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    replacement = lambda do |city:, **|
      city.fuel += 500
    end

    with_apply_building_economy_stub(replacement) do
      City::Tick.new(city, now: now).call
    end

    city.reload
    assert_equal 10_000, city.fuel
  end

  test "tick caps knowledge production at storage limit" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(knowledge: 4_900)

    library = ensure_building!("library")
    CityBuilding.create!(city: city, building: library, level: 1, workers_assigned: 0, enabled: true)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    replacement = lambda do |city:, **|
      city.knowledge += 500
    end

    with_apply_building_economy_stub(replacement) do
      City::Tick.new(city, now: now).call
    end

    city.reload
    assert_equal 5_000, city.knowledge
  end

  test "tick records truncated resources in ledger meta when storage cap is hit" do
    user = create_user!
    city = create_city!(user: user)
    city.update!(food: 19_900)

    depot = ensure_building!("resource_depot")
    CityBuilding.create!(city: city, building: depot, level: 2, workers_assigned: 0, enabled: true)

    now = Time.current
    city.update!(last_tick_at: now - 1.hour)

    replacement = lambda do |city:, **|
      city.food += 300
    end

    with_apply_building_economy_stub(replacement) do
      City::Tick.new(city, now: now).call
    end

    event = city.ledger_events.order(created_at: :desc).first
    assert_not_nil event
    assert_equal "tick", event.action_type
    assert_equal [ "food" ], event.meta["truncated_resources"]
    assert_equal 100, event.delta["food"]
  end

  test "tick remains deterministic with storage caps" do
    user = create_user!

    city_a = create_city!(user: user)
    city_b = create_city!(user: user)

    city_a.update!(food: 19_900, fuel: 9_900, knowledge: 4_900)
    city_b.update!(food: 19_900, fuel: 9_900, knowledge: 4_900)

    depot = ensure_building!("resource_depot")
    fluid_depot = ensure_building!("fluid_depot")
    library = ensure_building!("library")

    [ city_a, city_b ].each do |city|
      CityBuilding.create!(city: city, building: depot, level: 2, workers_assigned: 0, enabled: true)
      CityBuilding.create!(city: city, building: fluid_depot, level: 1, workers_assigned: 0, enabled: true)
      CityBuilding.create!(city: city, building: library, level: 1, workers_assigned: 0, enabled: true)
    end

    now = Time.current
    city_a.update!(last_tick_at: now - 1.hour)
    city_b.update!(last_tick_at: now - 1.hour)

    replacement = lambda do |city:, **|
      city.food += 300
      city.fuel += 500
      city.knowledge += 500
    end

    with_apply_building_economy_stub(replacement) do
      City::Tick.new(city_a, now: now).call
      City::Tick.new(city_b, now: now).call
    end

    city_a.reload
    city_b.reload

    assert_equal city_a.food, city_b.food
    assert_equal city_a.fuel, city_b.fuel
    assert_equal city_a.knowledge, city_b.knowledge
    assert_equal city_a.last_tick_at.to_i, city_b.last_tick_at.to_i
  end

  private

  def ensure_building!(key)
    Building.find_or_create_by!(key: key) do |building|
      building.name = key.humanize
      building.description = ""
      building.image = ""
      building.infrastructure_cost = 0
      building.has_hp = true
      building.rules = {}
    end
  end

  def with_apply_building_economy_stub(replacement)
    singleton = City::ApplyBuildingEconomy.singleton_class
    original_defined = singleton.method_defined?(:call)

    singleton.alias_method :__original_call_for_test__, :call if original_defined

    singleton.define_method(:call) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end

    yield
  ensure
    singleton.send(:remove_method, :call) if singleton.method_defined?(:call)

    if original_defined
      singleton.alias_method :call, :__original_call_for_test__
      singleton.send(:remove_method, :__original_call_for_test__)
    end
  end
end
