# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_05_04_130144) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "buildings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.text "description", default: "", null: false
    t.string "image", default: "", null: false
    t.integer "infrastructure_cost", default: 0, null: false
    t.boolean "has_hp", default: true, null: false
    t.jsonb "rules", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_buildings_on_key", unique: true
  end

  create_table "cities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "total_population", default: 0, null: false
    t.integer "free_population", default: 0, null: false
    t.integer "workers_population", default: 0, null: false
    t.integer "military_population", default: 0, null: false
    t.integer "university_population", default: 0, null: false
    t.integer "laboratory_population", default: 0, null: false
    t.integer "food", default: 0, null: false
    t.integer "coal", default: 0, null: false
    t.integer "iron_ore", default: 0, null: false
    t.integer "stone", default: 0, null: false
    t.integer "wood", default: 0, null: false
    t.integer "crude_oil", default: 0, null: false
    t.integer "fuel", default: 0, null: false
    t.integer "energy", default: 0, null: false
    t.integer "knowledge", default: 0, null: false
    t.integer "money", default: 0, null: false
    t.datetime "last_tick_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "infrastructure_level", default: 0, null: false
    t.integer "x", default: 0, null: false
    t.integer "y", default: 0, null: false
    t.index ["user_id"], name: "index_cities_on_user_id"
  end

  create_table "city_buildings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "city_id", null: false
    t.uuid "building_id", null: false
    t.integer "level", default: 1, null: false
    t.integer "workers_assigned", default: 0, null: false
    t.boolean "enabled", default: true, null: false
    t.integer "hp"
    t.integer "max_hp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assigned_resource"
    t.index ["building_id"], name: "index_city_buildings_on_building_id"
    t.index ["city_id"], name: "index_city_buildings_on_city_id"
  end

  create_table "city_logistic_stocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "city_id", null: false
    t.string "good_key"
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_city_logistic_stocks_on_city_id"
  end

  create_table "city_stored_goods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "city_id", null: false
    t.string "good_key", null: false
    t.integer "amount", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "good_key"], name: "index_city_stored_goods_on_city_id_and_good_key", unique: true
    t.index ["city_id"], name: "index_city_stored_goods_on_city_id"
  end

  create_table "diplomatic_relation_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "diplomatic_relation_id", null: false
    t.uuid "actor_user_id", null: false
    t.uuid "source_user_id", null: false
    t.uuid "target_user_id", null: false
    t.string "action_type", null: false
    t.string "previous_relation_state"
    t.string "new_relation_state", null: false
    t.string "previous_trade_policy"
    t.string "new_trade_policy", null: false
    t.string "previous_effective_trade_policy"
    t.string "new_effective_trade_policy", null: false
    t.integer "previous_tariff_rate_basis_points"
    t.integer "new_tariff_rate_basis_points"
    t.jsonb "meta", default: {}, null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_diplomatic_relation_events_on_action_type"
    t.index ["actor_user_id"], name: "index_diplomatic_relation_events_on_actor_user_id"
    t.index ["diplomatic_relation_id"], name: "index_diplomatic_relation_events_on_diplomatic_relation_id"
    t.index ["source_user_id", "target_user_id"], name: "index_diplomatic_relation_events_on_source_and_target"
    t.index ["source_user_id"], name: "index_diplomatic_relation_events_on_source_user_id"
    t.index ["target_user_id", "read_at"], name: "index_diplomatic_relation_events_on_target_and_read_at"
    t.index ["target_user_id"], name: "index_diplomatic_relation_events_on_target_user_id"
    t.check_constraint "action_type::text = ANY (ARRAY['created'::character varying, 'updated'::character varying]::text[])", name: "check_diplomatic_relation_events_action_type"
    t.check_constraint "actor_user_id = source_user_id", name: "check_diplomatic_relation_events_actor_is_source"
    t.check_constraint "source_user_id <> target_user_id", name: "check_diplomatic_relation_events_no_self_relation"
  end

  create_table "diplomatic_relations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "source_user_id", null: false
    t.uuid "target_user_id", null: false
    t.integer "relation_state", default: 0, null: false
    t.integer "trade_policy", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_user_id", "target_user_id"], name: "index_diplomatic_relations_on_source_and_target", unique: true
    t.index ["source_user_id"], name: "index_diplomatic_relations_on_source_user_id"
    t.index ["target_user_id"], name: "index_diplomatic_relations_on_target_user_id"
    t.check_constraint "relation_state = ANY (ARRAY[0, 1, 2, 3, 4, 5])", name: "check_diplomatic_relations_relation_state"
    t.check_constraint "source_user_id <> target_user_id", name: "check_diplomatic_relations_no_self_relation"
    t.check_constraint "trade_policy = 0 OR (relation_state = ANY (ARRAY[3, 4, 5]))", name: "check_diplomatic_relations_embargo_requires_negative_state"
    t.check_constraint "trade_policy = ANY (ARRAY[0, 1])", name: "check_diplomatic_relations_trade_policy"
  end

  create_table "ledger_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "city_id", null: false
    t.uuid "actor_user_id"
    t.string "action_type", null: false
    t.jsonb "delta", default: {}, null: false
    t.jsonb "meta", default: {}, null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["action_type"], name: "index_ledger_events_on_action_type"
    t.index ["actor_user_id"], name: "index_ledger_events_on_actor_user_id"
    t.index ["city_id", "action_type", "created_at"], name: "index_ledger_events_on_city_action_created_at"
    t.index ["city_id", "created_at"], name: "index_ledger_events_on_city_id_and_created_at"
    t.index ["city_id"], name: "index_ledger_events_on_city_id"
    t.index ["created_at"], name: "index_ledger_events_on_created_at"
  end

  create_table "logistic_operations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "origin_city_id", null: false
    t.uuid "destination_city_id", null: false
    t.string "resource", null: false
    t.integer "amount", null: false
    t.integer "trucks_assigned", null: false
    t.decimal "distance_km", precision: 10, scale: 2, null: false
    t.integer "fuel_cost", null: false
    t.datetime "started_at", precision: nil, null: false
    t.datetime "arrival_at", precision: nil, null: false
    t.string "status", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "completed_at"
    t.uuid "market_listing_id"
    t.integer "market_total_price"
    t.index ["arrival_at"], name: "index_logistic_operations_on_arrival_at"
    t.index ["destination_city_id"], name: "index_logistic_operations_on_destination_city_id"
    t.index ["market_listing_id"], name: "index_logistic_operations_on_market_listing_id"
    t.index ["origin_city_id"], name: "index_logistic_operations_on_origin_city_id"
    t.index ["status", "arrival_at"], name: "index_logistic_operations_on_status_and_arrival_at"
    t.index ["status"], name: "index_logistic_operations_on_status"
    t.check_constraint "amount > 0", name: "logistic_operations_amount_positive"
    t.check_constraint "arrival_at > started_at", name: "logistic_operations_arrival_after_start"
    t.check_constraint "char_length(resource::text) > 0", name: "logistic_operations_resource_not_blank"
    t.check_constraint "distance_km >= 0::numeric", name: "logistic_operations_distance_km_non_negative"
    t.check_constraint "fuel_cost >= 0", name: "logistic_operations_fuel_cost_non_negative"
    t.check_constraint "origin_city_id <> destination_city_id", name: "logistic_operations_different_cities"
    t.check_constraint "status::text = 'completed'::text AND completed_at IS NOT NULL OR status::text <> 'completed'::text AND completed_at IS NULL", name: "logistic_operations_completed_at_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['loading'::character varying, 'in_transit'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "logistic_operations_valid_status"
    t.check_constraint "trucks_assigned > 0", name: "logistic_operations_trucks_assigned_positive"
  end

  create_table "market_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "seller_user_id", null: false
    t.uuid "seller_city_id", null: false
    t.string "good_key", null: false
    t.integer "amount_total", null: false
    t.integer "amount_available", null: false
    t.integer "amount_return_pending", default: 0, null: false
    t.integer "price_per_unit", null: false
    t.string "currency_key", default: "money", null: false
    t.string "status", default: "active", null: false
    t.datetime "sold_out_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["good_key"], name: "index_market_listings_on_good_key"
    t.index ["seller_city_id", "status"], name: "index_market_listings_on_seller_city_id_and_status"
    t.index ["seller_city_id"], name: "index_market_listings_on_seller_city_id"
    t.index ["seller_user_id"], name: "index_market_listings_on_seller_user_id"
    t.index ["status", "good_key"], name: "index_market_listings_on_status_and_good_key"
    t.index ["status"], name: "index_market_listings_on_status"
    t.check_constraint "(amount_available + amount_return_pending) <= amount_total", name: "market_listings_available_plus_return_pending_lte_total"
    t.check_constraint "amount_available <= amount_total", name: "market_listings_amount_available_lte_total"
    t.check_constraint "amount_available >= 0", name: "market_listings_amount_available_non_negative"
    t.check_constraint "amount_return_pending >= 0", name: "market_listings_amount_return_pending_non_negative"
    t.check_constraint "amount_total > 0", name: "market_listings_amount_total_positive"
    t.check_constraint "currency_key::text = 'money'::text", name: "market_listings_currency_key_money_only"
    t.check_constraint "price_per_unit > 0", name: "market_listings_price_per_unit_positive"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'partially_filled'::character varying, 'sold_out'::character varying, 'cancelled'::character varying]::text[])", name: "market_listings_status_valid"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.date "birth_date", null: false
    t.string "birth_country", null: false
    t.citext "email", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "role = ANY (ARRAY[0, 1])", name: "users_role_check"
  end

  add_foreign_key "cities", "users"
  add_foreign_key "city_buildings", "buildings"
  add_foreign_key "city_buildings", "cities"
  add_foreign_key "city_logistic_stocks", "cities"
  add_foreign_key "city_stored_goods", "cities"
  add_foreign_key "diplomatic_relation_events", "diplomatic_relations"
  add_foreign_key "diplomatic_relation_events", "users", column: "actor_user_id"
  add_foreign_key "diplomatic_relation_events", "users", column: "source_user_id"
  add_foreign_key "diplomatic_relation_events", "users", column: "target_user_id"
  add_foreign_key "diplomatic_relations", "users", column: "source_user_id"
  add_foreign_key "diplomatic_relations", "users", column: "target_user_id"
  add_foreign_key "ledger_events", "cities"
  add_foreign_key "ledger_events", "users", column: "actor_user_id"
  add_foreign_key "logistic_operations", "cities", column: "destination_city_id", name: "fk_logistic_operations_destination_city"
  add_foreign_key "logistic_operations", "cities", column: "origin_city_id", name: "fk_logistic_operations_origin_city"
  add_foreign_key "logistic_operations", "market_listings"
  add_foreign_key "market_listings", "cities", column: "seller_city_id"
  add_foreign_key "market_listings", "users", column: "seller_user_id"
end
