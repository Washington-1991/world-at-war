class ForceHardenInfrastructureLevelOnCities < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      ALTER TABLE cities
      ALTER COLUMN infrastructure_level SET DEFAULT 0
    SQL

    execute <<~SQL
      UPDATE cities
      SET infrastructure_level = 0
      WHERE infrastructure_level IS NULL
    SQL

    execute <<~SQL
      ALTER TABLE cities
      ALTER COLUMN infrastructure_level SET NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE cities
      ALTER COLUMN infrastructure_level DROP NOT NULL
    SQL

    execute <<~SQL
      ALTER TABLE cities
      ALTER COLUMN infrastructure_level DROP DEFAULT
    SQL
  end
end
