class CreateCityBuildings < ActiveRecord::Migration[7.2]
  def change
    create_table :city_buildings, id: :uuid do |t|
      t.references :city,     null: false, type: :uuid, foreign_key: true
      t.references :building, null: false, type: :uuid, foreign_key: true

      t.integer :level,            null: false, default: 1
      t.integer :workers_assigned, null: false, default: 0
      t.boolean :enabled,          null: false, default: true

      # HP (nil permitido para hall). Definimos valores luego.
      t.integer :hp
      t.integer :max_hp

      t.timestamps
    end

    add_index :city_buildings, [ :city_id, :building_id ], unique: true
  end
end
