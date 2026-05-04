class AddPolicyConsistencyCheckToDiplomaticRelations < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :diplomatic_relations,
                         "trade_policy = 0 OR relation_state IN (3, 4, 5)",
                         name: "check_diplomatic_relations_embargo_requires_negative_state"
  end
end
