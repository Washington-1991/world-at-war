class DropCityBuildingsUniqueIndexDirectly < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DROP INDEX IF EXISTS index_city_buildings_on_city_id_and_building_id;
    SQL
  end

  def down
    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_city_buildings_on_city_id_and_building_id
      ON city_buildings (city_id, building_id);
    SQL
  end
end
