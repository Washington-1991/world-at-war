class CreateMarketListings < ActiveRecord::Migration[7.2]
  def change
    create_table :market_listings, id: :uuid do |t|
      t.references :seller_user, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :seller_city, null: false, foreign_key: { to_table: :cities }, type: :uuid

      t.string  :good_key, null: false
      t.integer :amount_total, null: false
      t.integer :amount_available, null: false
      t.integer :amount_return_pending, null: false, default: 0
      t.integer :price_per_unit, null: false

      t.string :currency_key, null: false, default: "money"
      t.string :status, null: false, default: "active"

      t.datetime :sold_out_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :market_listings, :status
    add_index :market_listings, :good_key
    add_index :market_listings, [ :status, :good_key ]
    add_index :market_listings, [ :seller_city_id, :status ]

    add_check_constraint :market_listings,
                         "amount_total > 0",
                         name: "market_listings_amount_total_positive"

    add_check_constraint :market_listings,
                         "amount_available >= 0",
                         name: "market_listings_amount_available_non_negative"

    add_check_constraint :market_listings,
                         "amount_return_pending >= 0",
                         name: "market_listings_amount_return_pending_non_negative"

    add_check_constraint :market_listings,
                         "price_per_unit > 0",
                         name: "market_listings_price_per_unit_positive"

    add_check_constraint :market_listings,
                         "amount_available <= amount_total",
                         name: "market_listings_amount_available_lte_total"

    add_check_constraint :market_listings,
                         "amount_available + amount_return_pending <= amount_total",
                         name: "market_listings_available_plus_return_pending_lte_total"

    add_check_constraint :market_listings,
                         "currency_key = 'money'",
                         name: "market_listings_currency_key_money_only"

    add_check_constraint :market_listings,
                         "status IN ('active', 'partially_filled', 'sold_out', 'cancelled')",
                         name: "market_listings_status_valid"
  end
end
