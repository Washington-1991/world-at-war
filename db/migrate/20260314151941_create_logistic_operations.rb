class CreateLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    create_table :logistic_operations, id: :uuid do |t|
      t.timestamps
    end
  end
end
