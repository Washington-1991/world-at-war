class AddMarketFieldsToLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    add_reference :logistic_operations,
                  :market_listing,
                  type: :uuid,
                  foreign_key: true,
                  null: true

    add_column :logistic_operations, :market_total_price, :integer

    add_check_constraint :logistic_operations,
                         "market_total_price IS NULL OR market_total_price >= 0",
                         name: "logistic_operations_market_total_price_non_negative"
  end
end
