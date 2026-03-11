class FixInfrastructureLevelOnCities < ActiveRecord::Migration[7.2]
  def up
    change_column_default :cities, :infrastructure_level, 0

    execute <<~SQL
      UPDATE cities
      SET infrastructure_level = 0
      WHERE infrastructure_level IS NULL
    SQL

    change_column_null :cities, :infrastructure_level, false
  end

  def down
    change_column_null :cities, :infrastructure_level, true
    change_column_default :cities, :infrastructure_level, nil
  end
end
