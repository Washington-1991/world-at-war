require "test_helper"

class CitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index (unauthorized when not logged in)" do
    get cities_url
    assert_response :unauthorized
  end

  test "should get show (unauthorized when not logged in)" do
    city = cities(:one)
    get city_url(city)
    assert_response :unauthorized
  end
end
