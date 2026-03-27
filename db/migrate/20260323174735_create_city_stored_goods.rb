class CreateCityStoredGoods < ActiveRecord::Migration[7.2]
  def change
    create_table :city_stored_goods, id: :uuid do |t|
      t.references :city, null: false, foreign_key: true, type: :uuid
      t.string :good_key, null: false
      t.integer :amount, null: false, default: 0

      t.timestamps
    end

    add_index :city_stored_goods, [ :city_id, :good_key ], unique: true
  end
end
