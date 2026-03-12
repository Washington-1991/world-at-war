class RemoveUniqueIndexFromCityBuildingsOnCityIdAndBuildingId < ActiveRecord::Migration[7.2]
  def change
    remove_index :city_buildings, name: "index_city_buildings_on_city_id_and_building_id"
  end
end
