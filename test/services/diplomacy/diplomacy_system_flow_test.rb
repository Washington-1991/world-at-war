require "test_helper"

module Diplomacy
  class DiplomacySystemFlowTest < ActiveSupport::TestCase
    include WawFactories

    setup do
      @seller_user = create_user!
      @buyer_user = create_user!

      @seller_city = create_city!(
        user: @seller_user,
        food: 10_000,
        wood: 10_000
      )

      @buyer_city = create_city!(
        user: @buyer_user,
        money: 20_000,
        food: 0,
        wood: 0
      )

      ensure_hall_for!(@seller_city)
      ensure_hall_for!(@buyer_city)
      ensure_logistic_station_for!(@seller_city)
      ensure_logistic_station_for!(@buyer_city)

      @seller_city.reload
      @buyer_city.reload
    end

    test "friendly relation created by buyer reduces market tariff and notifies seller" do
      assert_difference("DiplomaticRelationEvent.count", 1) do
        Diplomacy::UpsertRelation.call(
          actor_user: @buyer_user,
          target_user: @seller_user,
          relation_state: :friendly
        )
      end

      assert_equal 1, @seller_user.received_diplomatic_relation_events.count
      assert_equal 0, @buyer_user.received_diplomatic_relation_events.count

      listing = create_food_listing(amount: 500, price_per_unit: 10)

      operation = Market::BuyListing.new(
        listing: listing,
        buyer_city: @buyer_city,
        actor_user: @buyer_user,
        amount: 100,
        trucks_assigned: 1,
        eta_hours: 1
      ).call

      @buyer_city.reload

      event = latest_purchase_event

      assert operation.persisted?
      assert_equal 1_000, operation.market_total_price
      assert_equal 18_950, @buyer_city.money

      assert_equal({ "money" => -1_050 }, event.delta)
      assert_equal 1_000, event.meta["base_price"]
      assert_equal 500, event.meta["tariff_rate_basis_points"]
      assert_equal 50, event.meta["tariff_amount"]
      assert_equal 1_050, event.meta["total_buyer_cost"]
      assert_equal "money_sink", event.meta["tariff_destination"]

      diplomacy = event.meta["diplomacy"]

      assert_equal "friendly", diplomacy["importer_relation_state"]
      assert_equal "neutral", diplomacy["exporter_relation_state"]
      assert_equal 500, diplomacy["tariff_rate_basis_points"]
    end

    test "hostile manual embargo blocks market purchase and direct logistics" do
      Diplomacy::UpsertRelation.call(
        actor_user: @buyer_user,
        target_user: @seller_user,
        relation_state: :hostile
      )

      Diplomacy::UpsertRelation.call(
        actor_user: @buyer_user,
        target_user: @seller_user,
        trade_policy: :embargoed
      )

      listing = create_food_listing(amount: 500, price_per_unit: 10)

      assert_no_difference("LogisticOperation.count") do
        error = assert_raises(Market::BuyListing::Error) do
          Market::BuyListing.new(
            listing: listing,
            buyer_city: @buyer_city,
            actor_user: @buyer_user,
            amount: 100,
            trucks_assigned: 1,
            eta_hours: 1
          ).call
        end

        assert_equal "trade blocked by diplomacy: importer_embargo", error.message
      end

      listing.reload
      @buyer_city.reload

      assert_equal 500, listing.amount_available
      assert_equal 20_000, @buyer_city.money

      seller_wood_before = @seller_city.reload.wood

      assert_no_difference("LogisticOperation.count") do
        error = assert_raises(City::TransportResource::Error) do
          City::TransportResource.new(
            origin_city: @seller_city,
            destination_city: @buyer_city,
            actor_user: @seller_user,
            resource_key: "wood",
            amount: 100,
            trucks_assigned: 1,
            eta_hours: 1
          ).call
        end

        assert_equal "logistics blocked by diplomacy: importer_embargo", error.message
      end

      assert_equal seller_wood_before, @seller_city.reload.wood
    end

    test "enemy relation automatically blocks market purchase and direct logistics" do
      Diplomacy::UpsertRelation.call(
        actor_user: @seller_user,
        target_user: @buyer_user,
        relation_state: :enemy
      )

      relation = DiplomaticRelation.find_by!(
        source_user: @seller_user,
        target_user: @buyer_user
      )

      assert_equal "enemy", relation.relation_state
      assert_equal "open", relation.trade_policy
      assert_equal "embargoed", relation.effective_trade_policy

      listing = create_food_listing(amount: 500, price_per_unit: 10)

      assert_no_difference("LogisticOperation.count") do
        error = assert_raises(Market::BuyListing::Error) do
          Market::BuyListing.new(
            listing: listing,
            buyer_city: @buyer_city,
            actor_user: @buyer_user,
            amount: 100,
            trucks_assigned: 1,
            eta_hours: 1
          ).call
        end

        assert_equal "trade blocked by diplomacy: exporter_embargo", error.message
      end

      seller_wood_before = @seller_city.reload.wood

      assert_no_difference("LogisticOperation.count") do
        error = assert_raises(City::TransportResource::Error) do
          City::TransportResource.new(
            origin_city: @seller_city,
            destination_city: @buyer_city,
            actor_user: @seller_user,
            resource_key: "wood",
            amount: 100,
            trucks_assigned: 1,
            eta_hours: 1
          ).call
        end

        assert_equal "logistics blocked by diplomacy: exporter_embargo", error.message
      end

      assert_equal seller_wood_before, @seller_city.reload.wood
    end

    private

    def create_food_listing(amount:, price_per_unit:)
      Market::CreateListing.new(
        seller_city: @seller_city,
        actor_user: @seller_user,
        good_key: "food",
        amount: amount,
        price_per_unit: price_per_unit
      ).call
    end

    def latest_purchase_event
      LedgerEvent.where(
        city: @buyer_city,
        action_type: "market_purchase_started"
      ).order(:created_at).last
    end

    def ensure_hall_for!(city)
      hall_building = Building.find_or_create_by!(key: "hall") do |building|
        building.name = "Hall"
        building.infrastructure_cost = 0
        building.rules = {
          "levels" => {
            "1" => {
              "workers_required" => 0
            }
          }
        }
      end

      CityBuilding.find_or_create_by!(city: city, building: hall_building) do |city_building|
        city_building.level = 1
        city_building.workers_assigned = 0
        city_building.enabled = true
      end
    end

    def ensure_logistic_station_for!(city)
      station_building = Building.find_or_initialize_by(key: "logistic_station")
      station_building.name = "Logistic Station"
      station_building.infrastructure_cost = 0
      station_building.rules = {
        "levels" => {
          "1" => {
            "workers_required" => 0,
            "trucks_capacity" => 100
          }
        }
      }
      station_building.save!

      CityBuilding.find_or_create_by!(city: city, building: station_building) do |city_building|
        city_building.level = 1
        city_building.workers_assigned = 0
        city_building.enabled = true
      end
    end
  end
end
