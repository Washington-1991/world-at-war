class AddCoordinatesToCities < ActiveRecord::Migration[8.0]
  def change
    add_column :cities, :x, :integer, null: false, default: 0
    add_column :cities, :y, :integer, null: false, default: 0
  end
end
