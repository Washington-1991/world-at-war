require "test_helper"

class City::AssignWorkersTest < ActiveSupport::TestCase
  include WawFactories

  test "rejects negative workers" do
    user = create_user!
    city = create_city!(user: user)

    b = create_building!(
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    cb = create_city_building!(city: city, building: b, workers_assigned: 0)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignWorkers.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        workers_assigned: -1
      )

      assert_not result.ok?
      assert_equal :invalid_input, result.error
    end
  end

  test "rejects workers above workers_required" do
    user = create_user!
    city = create_city!(user: user)

    b = create_building!(
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    cb = create_city_building!(city: city, building: b, workers_assigned: 0)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignWorkers.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        workers_assigned: 11
      )

      assert_not result.ok?
      assert_equal :over_required, result.error
    end
  end

  test "rejects over-capacity (sum assigned > workers_population)" do
    user = create_user!
    city = create_city!(user: user, total_population: 20, workers_population: 10, free_population: 10)

    b1 = create_building!(
      key: "building_a",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    b2 = create_building!(
      key: "building_b",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )

    cb1 = create_city_building!(city: city, building: b1, workers_assigned: 0)
    cb2 = create_city_building!(city: city, building: b2, workers_assigned: 0)

    assert_difference "LedgerEvent.count", 1 do
      ok = City::AssignWorkers.call(
        user: user,
        city: city,
        city_building_id: cb1.id,
        workers_assigned: 10
      )

      assert ok.ok?
    end

    last_event = LedgerEvent.order(created_at: :desc).first
    assert_equal "assign_workers", last_event.action_type
    assert_equal user.id, last_event.actor_user_id
    assert_equal city.id, last_event.city_id
    assert_equal({}, last_event.delta)
    assert_equal cb1.id, last_event.meta["city_building_id"]
    assert_equal 0, last_event.meta["workers_before"]
    assert_equal 10, last_event.meta["workers_after"]

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignWorkers.call(
        user: user,
        city: city,
        city_building_id: cb2.id,
        workers_assigned: 1
      )

      assert_not result.ok?
      assert_equal :over_capacity, result.error
    end
  end

  test "forbids assigning workers to a city not owned by user (anti-IDOR)" do
    owner = create_user!(email: "owner@example.com")
    attacker = create_user!(email: "attacker@example.com")

    victim_city = create_city!(user: owner)
    b = create_building!(
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    cb = create_city_building!(city: victim_city, building: b)

    assert_no_difference "LedgerEvent.count" do
      result = City::AssignWorkers.call(
        user: attacker,
        city: victim_city,
        city_building_id: cb.id,
        workers_assigned: 1
      )

      assert_not result.ok?
      assert_equal :forbidden, result.error
    end
  end

  test "creates ledger event for valid assignment" do
    user = create_user!
    city = create_city!(user: user, total_population: 20, workers_population: 10, free_population: 10)

    b = create_building!(
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    cb = create_city_building!(city: city, building: b, workers_assigned: 0)

    assert_difference "LedgerEvent.count", 1 do
      result = City::AssignWorkers.call(
        user: user,
        city: city,
        city_building_id: cb.id,
        workers_assigned: 5
      )

      assert result.ok?
    end

    cb.reload
    assert_equal 5, cb.workers_assigned

    event = LedgerEvent.order(created_at: :desc).first
    assert_equal "assign_workers", event.action_type
    assert_equal city.id, event.city_id
    assert_equal user.id, event.actor_user_id
    assert_equal({}, event.delta)
    assert_equal cb.id, event.meta["city_building_id"]
    assert_equal 0, event.meta["workers_before"]
    assert_equal 5, event.meta["workers_after"]
  end

  test "race safety: two concurrent assignments cannot exceed capacity" do
    user = create_user!
    city = create_city!(user: user, total_population: 20, workers_population: 10, free_population: 10)

    b1 = create_building!(
      key: "race_building_a",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )
    b2 = create_building!(
      key: "race_building_b",
      rules: {
        "levels" => {
          "1" => { "workers_required" => 10 }
        }
      }
    )

    cb1 = create_city_building!(city: city, building: b1)
    cb2 = create_city_building!(city: city, building: b2)

    results = []
    mutex = Mutex.new

    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = City::AssignWorkers.call(
            user: user,
            city: city,
            city_building_id: cb1.id,
            workers_assigned: 10
          )
          mutex.synchronize { results << result }
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = City::AssignWorkers.call(
            user: user,
            city: city,
            city_building_id: cb2.id,
            workers_assigned: 10
          )
          mutex.synchronize { results << result }
        end
      end
    ]
    threads.each(&:join)

    city.reload
    total = city.city_buildings.sum(:workers_assigned)

    assert total <= city.workers_population
    assert results.any?(&:ok?), "at least one should succeed"
    assert results.any? { |r| !r.ok? }, "at least one should fail (capacity)"

    ledger_events = LedgerEvent.where(action_type: "assign_workers", city_id: city.id)
    assert_equal 1, ledger_events.count, "only the successful assignment should create one ledger event"
  end
end
