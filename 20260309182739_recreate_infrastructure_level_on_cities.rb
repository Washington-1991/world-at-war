class RecreateInfrastructureLevelOnCities < ActiveRecord::Migration[7.2]
  def up
    remove_column :cities, :infrastructure_level, :integer
    add_column :cities, :infrastructure_level, :integer, null: false, default: 0
  end

  def down
    remove_column :cities, :infrastructure_level, :integer
    add_column :cities, :infrastructure_level, :integer
  end
end
