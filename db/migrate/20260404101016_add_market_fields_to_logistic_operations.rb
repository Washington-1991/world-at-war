class AddMarketFieldsToLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    add_reference :logistic_operations, :market_listing, null: false, foreign_key: true, type: :uuid
    add_column :logistic_operations, :market_total_price, :integer
  end
end
