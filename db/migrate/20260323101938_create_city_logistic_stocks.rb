class CreateCityLogisticStocks < ActiveRecord::Migration[7.2]
  def change
    create_table :city_logistic_stocks, id: :uuid do |t|
      t.references :city, null: false, foreign_key: true, type: :uuid
      t.string :good_key
      t.integer :amount

      t.timestamps
    end
  end
end
