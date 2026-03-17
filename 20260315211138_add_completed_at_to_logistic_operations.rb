class AddCompletedAtToLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    add_column :logistic_operations, :completed_at, :datetime

    add_check_constraint :logistic_operations,
                         "(status = 'completed' AND completed_at IS NOT NULL) OR (status <> 'completed' AND completed_at IS NULL)",
                         name: "logistic_operations_completed_at_matches_status"
  end
end
