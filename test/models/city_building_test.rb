require "test_helper"

class CityBuildingTest < ActiveSupport::TestCase
  include WawFactories

  test "workers_assigned cannot exceed workers_required for its level" do
    user = create_user!
    city = create_city!(user: user)

    building = create_building!(rules: { "1" => { "workers_required" => 5 } })
    cb = create_city_building!(city: city, building: building, level: 1, workers_assigned: 5)

    cb.workers_assigned = 6
    assert_not cb.valid?
    assert cb.errors[:workers_assigned].any?
  end
end
