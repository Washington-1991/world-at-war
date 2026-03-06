class CreateLedgerEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :ledger_events, id: :uuid do |t|
      t.uuid :city_id, null: false
      t.uuid :actor_user_id, null: true

      t.string :action_type, null: false

      t.jsonb :delta, null: false, default: {}
      t.jsonb :meta, null: false, default: {}

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_foreign_key :ledger_events, :cities, column: :city_id
    add_foreign_key :ledger_events, :users, column: :actor_user_id

    add_index :ledger_events, :city_id
    add_index :ledger_events, :actor_user_id
    add_index :ledger_events, :action_type
    add_index :ledger_events, :created_at
    add_index :ledger_events, [ :city_id, :created_at ]
    add_index :ledger_events, [ :city_id, :action_type, :created_at ], name: "index_ledger_events_on_city_action_created_at"
  end
end
