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

ActiveRecord::Schema[7.2].define(version: 2026_03_14_212522) do
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
    t.index ["arrival_at"], name: "index_logistic_operations_on_arrival_at"
    t.index ["destination_city_id"], name: "index_logistic_operations_on_destination_city_id"
    t.index ["origin_city_id"], name: "index_logistic_operations_on_origin_city_id"
    t.index ["status", "arrival_at"], name: "index_logistic_operations_on_status_and_arrival_at"
    t.index ["status"], name: "index_logistic_operations_on_status"
    t.check_constraint "amount > 0", name: "logistic_operations_amount_positive"
    t.check_constraint "arrival_at > started_at", name: "logistic_operations_arrival_after_start"
    t.check_constraint "char_length(resource::text) > 0", name: "logistic_operations_resource_not_blank"
    t.check_constraint "distance_km >= 0::numeric", name: "logistic_operations_distance_km_non_negative"
    t.check_constraint "fuel_cost >= 0", name: "logistic_operations_fuel_cost_non_negative"
    t.check_constraint "origin_city_id <> destination_city_id", name: "logistic_operations_different_cities"
    t.check_constraint "status::text = ANY (ARRAY['loading'::character varying, 'in_transit'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "logistic_operations_valid_status"
    t.check_constraint "trucks_assigned > 0", name: "logistic_operations_trucks_assigned_positive"
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
  add_foreign_key "ledger_events", "cities"
  add_foreign_key "ledger_events", "users", column: "actor_user_id"
  add_foreign_key "logistic_operations", "cities", column: "destination_city_id", name: "fk_logistic_operations_destination_city"
  add_foreign_key "logistic_operations", "cities", column: "origin_city_id", name: "fk_logistic_operations_origin_city"
end
