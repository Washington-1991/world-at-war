class AddInfrastructureLevelToCities < ActiveRecord::Migration[7.2]
  def change
    add_column :cities, :infrastructure_level, :integer, null: false, default: 0
  end
end
