class AddAssignedResourceToCityBuildings < ActiveRecord::Migration[7.2]
  def change
    add_column :city_buildings, :assigned_resource, :string
    add_index :city_buildings, :assigned_resource
  end
end
