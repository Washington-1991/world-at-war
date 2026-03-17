class AddCompletedAtAndStatusConstraintToLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    add_column :logistic_operations, :completed_at, :datetime

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE logistic_operations
          SET completed_at = updated_at
          WHERE status = 'completed' AND completed_at IS NULL
        SQL
      end
    end

    add_check_constraint :logistic_operations,
                         "(status = 'completed' AND completed_at IS NOT NULL) OR (status <> 'completed' AND completed_at IS NULL)",
                         name: "logistic_operations_completed_at_matches_status"
  end
end
