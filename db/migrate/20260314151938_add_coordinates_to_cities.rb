class AddCoordinatesToCities < ActiveRecord::Migration[7.2]
  def change
    add_column :cities, :x, :integer
    add_column :cities, :y, :integer
  end
end
