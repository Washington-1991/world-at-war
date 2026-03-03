class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: :uuid do |t|
      t.string :name, null: false
      t.date :birth_date, null: false
      t.string :birth_country, null: false

      t.citext :email, null: false
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email, unique: true

    # Seguridad dura: evita estados inválidos incluso si hay un bug en Rails
    add_check_constraint :users, "role IN (0, 1)", name: "users_role_check"
  end
end
