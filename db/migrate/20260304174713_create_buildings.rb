class CreateBuildings < ActiveRecord::Migration[7.2]
  def change
    create_table :buildings, id: :uuid do |t|
      t.string  :key,  null: false
      t.string  :name, null: false

      t.text    :description, null: false, default: ""
      t.string  :image,       null: false, default: ""

      t.integer :infrastructure_cost, null: false, default: 0

      # Excepción: Hall/Ayuntamiento => has_hp: false
      t.boolean :has_hp, null: false, default: true

      # Placeholder para reglas por nivel (mantenimiento/producción/efectos). Lo detallamos luego.
      t.jsonb :rules, null: false, default: {}

      t.timestamps
    end

    add_index :buildings, :key, unique: true
  end
end
