class MakeMarketListingNullableInLogisticOperations < ActiveRecord::Migration[7.2]
  def change
    change_column_null :logistic_operations, :market_listing_id, true
  end
end
