class CreateDiplomaticRelationEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :diplomatic_relation_events, id: :uuid do |t|
      t.references :diplomatic_relation,
                   null: false,
                   type: :uuid,
                   foreign_key: true

      t.references :actor_user,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :source_user,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :target_user,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.string :action_type, null: false

      t.string :previous_relation_state
      t.string :new_relation_state, null: false

      t.string :previous_trade_policy
      t.string :new_trade_policy, null: false

      t.string :previous_effective_trade_policy
      t.string :new_effective_trade_policy, null: false

      t.integer :previous_tariff_rate_basis_points
      t.integer :new_tariff_rate_basis_points

      t.jsonb :meta, null: false, default: {}
      t.datetime :read_at

      t.timestamps
    end

    add_index :diplomatic_relation_events,
              [ :target_user_id, :read_at ],
              name: "index_diplomatic_relation_events_on_target_and_read_at"

    add_index :diplomatic_relation_events,
              [ :source_user_id, :target_user_id ],
              name: "index_diplomatic_relation_events_on_source_and_target"

    add_index :diplomatic_relation_events,
              :action_type

    add_check_constraint :diplomatic_relation_events,
                         "actor_user_id = source_user_id",
                         name: "check_diplomatic_relation_events_actor_is_source"

    add_check_constraint :diplomatic_relation_events,
                         "source_user_id <> target_user_id",
                         name: "check_diplomatic_relation_events_no_self_relation"

    add_check_constraint :diplomatic_relation_events,
                         "action_type IN ('created', 'updated')",
                         name: "check_diplomatic_relation_events_action_type"
  end
end
