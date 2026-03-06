require "test_helper"

class City::AssignWorkersTest < ActiveSupport::TestCase
  include WawFactories

  test "rejects negative workers" do
    user = create_user!
    city = create_city!(user: user)
    b = create_building!(rules: { "1" => { "workers_required" => 10 } })
    cb = create_city_building!(city: city, building: b, workers_assigned: 0)

    result = City::AssignWorkers.call(user: user, city: city, city_building_id: cb.id, workers_assigned: -1)

    assert_not result.ok?
    assert_equal :invalid_input, result.error
  end

  test "rejects workers above workers_required" do
    user = create_user!
    city = create_city!(user: user)
    b = create_building!(rules: { "1" => { "workers_required" => 10 } })
    cb = create_city_building!(city: city, building: b, workers_assigned: 0)

    result = City::AssignWorkers.call(user: user, city: city, city_building_id: cb.id, workers_assigned: 11)

    assert_not result.ok?
    assert_equal :over_required, result.error
  end

  test "rejects over-capacity (sum assigned > workers_population)" do
    user = create_user!
    city = create_city!(user: user, total_population: 20, workers_population: 10, free_population: 10)

    b1 = create_building!(rules: { "1" => { "workers_required" => 10 } })
    b2 = create_building!(rules: { "1" => { "workers_required" => 10 } })
    cb1 = create_city_building!(city: city, building: b1, workers_assigned: 0)
    cb2 = create_city_building!(city: city, building: b2, workers_assigned: 0)

    ok = City::AssignWorkers.call(user: user, city: city, city_building_id: cb1.id, workers_assigned: 10)
    assert ok.ok?

    result = City::AssignWorkers.call(user: user, city: city, city_building_id: cb2.id, workers_assigned: 1)
    assert_not result.ok?
    assert_equal :over_capacity, result.error
  end

  test "forbids assigning workers to a city not owned by user (anti-IDOR)" do
    owner = create_user!(email: "owner@example.com")
    attacker = create_user!(email: "attacker@example.com")

    victim_city = create_city!(user: owner)
    b = create_building!(rules: { "1" => { "workers_required" => 10 } })
    cb = create_city_building!(city: victim_city, building: b)

    result = City::AssignWorkers.call(user: attacker, city: victim_city, city_building_id: cb.id, workers_assigned: 1)

    assert_not result.ok?
    assert_equal :forbidden, result.error
  end

  test "race safety: two concurrent assignments cannot exceed capacity" do
    user = create_user!
    city = create_city!(user: user, total_population: 20, workers_population: 10, free_population: 10)

    b1 = create_building!(rules: { "1" => { "workers_required" => 10 } })
    b2 = create_building!(rules: { "1" => { "workers_required" => 10 } })
    cb1 = create_city_building!(city: city, building: b1)
    cb2 = create_city_building!(city: city, building: b2)

    results = []
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << City::AssignWorkers.call(user: user, city: city, city_building_id: cb1.id, workers_assigned: 10)
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          results << City::AssignWorkers.call(user: user, city: city, city_building_id: cb2.id, workers_assigned: 10)
        end
      end
    ]
    threads.each(&:join)

    city.reload
    total = city.city_buildings.sum(:workers_assigned)

    assert total <= city.workers_population
    assert results.any?(&:ok?), "at least one should succeed"
    assert results.any? { |r| !r.ok? }, "at least one should fail (capacity)"
  end
end
