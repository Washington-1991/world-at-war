class CreateCities < ActiveRecord::Migration[7.2]
  def change
    create_table :cities, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid

      # Población
      t.integer :total_population,      null: false, default: 0
      t.integer :free_population,       null: false, default: 0
      t.integer :workers_population,    null: false, default: 0
      t.integer :military_population,   null: false, default: 0
      t.integer :university_population, null: false, default: 0
      t.integer :laboratory_population, null: false, default: 0

      # Recursos
      t.integer :food,      null: false, default: 0
      t.integer :coal,      null: false, default: 0
      t.integer :iron_ore,  null: false, default: 0
      t.integer :stone,     null: false, default: 0
      t.integer :wood,      null: false, default: 0
      t.integer :crude_oil, null: false, default: 0
      t.integer :fuel,      null: false, default: 0

      # Energía / Conocimiento / Dinero
      t.integer :energy,    null: false, default: 0
      t.integer :knowledge, null: false, default: 0
      t.integer :money,     null: false, default: 0

      # Tick
      t.datetime :last_tick_at

      t.timestamps
    end
  end
end
