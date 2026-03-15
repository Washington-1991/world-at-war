class FixLogisticsSchema < ActiveRecord::Migration[7.2]
  def up
    change_column_default :cities, :x, from: nil, to: 0
    change_column_default :cities, :y, from: nil, to: 0

    execute "UPDATE cities SET x = 0 WHERE x IS NULL"
    execute "UPDATE cities SET y = 0 WHERE y IS NULL"

    change_column_null :cities, :x, false
    change_column_null :cities, :y, false

    drop_table :logistic_operations, if_exists: true

    create_table :logistic_operations, id: :uuid do |t|
      t.references :origin_city,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :cities },
                   index: true

      t.references :destination_city,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :cities },
                   index: true

      t.string :resource, null: false
      t.integer :amount, null: false
      t.integer :trucks_assigned, null: false
      t.decimal :distance_km, precision: 10, scale: 2, null: false
      t.integer :fuel_cost, null: false
      t.datetime :started_at, null: false
      t.datetime :arrival_at, null: false
      t.string :status, null: false

      t.timestamps
    end

    add_index :logistic_operations, :status
    add_index :logistic_operations, :arrival_at
    add_index :logistic_operations, [ :status, :arrival_at ]

    add_check_constraint :logistic_operations,
                         "amount > 0",
                         name: "logistic_operations_amount_positive"

    add_check_constraint :logistic_operations,
                         "trucks_assigned > 0",
                         name: "logistic_operations_trucks_assigned_positive"

    add_check_constraint :logistic_operations,
                         "fuel_cost >= 0",
                         name: "logistic_operations_fuel_cost_non_negative"

    add_check_constraint :logistic_operations,
                         "distance_km >= 0",
                         name: "logistic_operations_distance_km_non_negative"

    add_check_constraint :logistic_operations,
                         "arrival_at > started_at",
                         name: "logistic_operations_arrival_after_start"

    add_check_constraint :logistic_operations,
                         "origin_city_id <> destination_city_id",
                         name: "logistic_operations_different_cities"

    add_check_constraint :logistic_operations,
                         "char_length(resource) > 0",
                         name: "logistic_operations_resource_not_blank"

    add_check_constraint :logistic_operations,
                         "status IN ('loading', 'in_transit', 'completed', 'cancelled')",
                         name: "logistic_operations_valid_status"
  end

  def down
    drop_table :logistic_operations, if_exists: true

    create_table :logistic_operations, id: :uuid do |t|
      t.timestamps
    end

    change_column_null :cities, :x, true
    change_column_null :cities, :y, true
    change_column_default :cities, :x, from: 0, to: nil
    change_column_default :cities, :y, from: 0, to: nil
  end
end
