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

ActiveRecord::Schema[7.2].define(version: 2026_03_09_182739) do
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
    t.index ["building_id"], name: "index_city_buildings_on_building_id"
    t.index ["city_id", "building_id"], name: "index_city_buildings_on_city_id_and_building_id", unique: true
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
end
