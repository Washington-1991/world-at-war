class CreateDiplomaticRelations < ActiveRecord::Migration[7.2]
  def change
    create_table :diplomatic_relations, id: :uuid do |t|
      t.references :source_user,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.references :target_user,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :users }

      t.integer :relation_state, null: false, default: 0
      t.integer :trade_policy, null: false, default: 0

      t.timestamps
    end

    add_index :diplomatic_relations,
              [ :source_user_id, :target_user_id ],
              unique: true,
              name: "index_diplomatic_relations_on_source_and_target"

    add_check_constraint :diplomatic_relations,
                         "source_user_id <> target_user_id",
                         name: "check_diplomatic_relations_no_self_relation"

    add_check_constraint :diplomatic_relations,
                         "relation_state IN (0, 1, 2, 3, 4, 5)",
                         name: "check_diplomatic_relations_relation_state"

    add_check_constraint :diplomatic_relations,
                         "trade_policy IN (0, 1)",
                         name: "check_diplomatic_relations_trade_policy"
  end
end
