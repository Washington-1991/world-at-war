class ForceRemoveUniqueIndexFromCityBuildings < ActiveRecord::Migration[7.2]
  def up
    if index_exists?(:city_buildings, [ :city_id, :building_id ], name: "index_city_buildings_on_city_id_and_building_id", unique: true)
      remove_index :city_buildings, name: "index_city_buildings_on_city_id_and_building_id"
    elsif index_exists?(:city_buildings, [ :city_id, :building_id ])
      remove_index :city_buildings, column: [ :city_id, :building_id ]
    end
  end

  def down
    add_index :city_buildings, [ :city_id, :building_id ],
              unique: true,
              name: "index_city_buildings_on_city_id_and_building_id"
  end
end
