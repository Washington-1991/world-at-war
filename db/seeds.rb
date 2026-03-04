# db/seeds.rb

admin_email = ENV.fetch("WAW_ADMIN_EMAIL", nil)
admin_name  = ENV.fetch("WAW_ADMIN_NAME",  "Admin")
admin_birth_date = ENV.fetch("WAW_ADMIN_BIRTH_DATE", "1980-01-01")
admin_birth_country = ENV.fetch("WAW_ADMIN_BIRTH_COUNTRY", "FR")

if admin_email.present?
  admin = User.find_or_initialize_by(email: admin_email)

  admin.name = admin_name
  admin.birth_date = Date.parse(admin_birth_date)
  admin.birth_country = admin_birth_country
  admin.role = :admin

  if admin.save
    puts "✅ Admin ensured: #{admin.email}"
  else
    puts "❌ Admin seed failed: #{admin.errors.full_messages.join(", ")}"
  end
else
  puts "ℹ️  Admin seed skipped (set WAW_ADMIN_EMAIL to enable)"
end

# -----------------------------
# Buildings catalog (v1.0)
# -----------------------------
buildings = [
  # Producción primaria lvl 1 (100 workers)
  {
    key: "farm",
    name: "Farm",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { food: 100 } } } }
  },
  {
    key: "coal_mine",
    name: "Coal Mine",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { coal: 100 }, maintenance: { money: 20 } } } }
  },
  {
    key: "iron_mine",
    name: "Iron Mine",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { iron_ore: 100 }, maintenance: { money: 20 } } } }
  },
  {
    key: "quarry",
    name: "Quarry",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { stone: 100 }, maintenance: { money: 20 } } } }
  },
  {
    key: "sawmill",
    name: "Sawmill",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { wood: 100 } } } }
  },
  {
    key: "oil_well",
    name: "Oil Well",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, outputs: { crude_oil: 100 } } } }
  },

  # Energía / refinado (100 workers)
  {
    key: "coal_power_plant",
    name: "Coal Power Plant",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, inputs: { coal: 50 }, outputs: { energy: 500 } } } }
  },
  {
    key: "refinery",
    name: "Refinery",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 100, inputs: { crude_oil: 25 }, outputs: { fuel: 125 } } } }
  },

  # Conocimiento (placeholder v1)
  {
    key: "university",
    name: "University",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 10, outputs: { knowledge: 1 } } } }
  },
  {
    key: "laboratory",
    name: "Laboratory",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 10, inputs: { knowledge: 2 } } } }
  },
  {
    key: "library",
    name: "Library",
    has_hp: true,
    rules: { levels: { "1" => { workers_required: 10 } } }
  },

  # Soporte (10 workers, placeholder v1)
  { key: "resource_depot",    name: "Resource Depot",    has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },
  { key: "fluid_depot",       name: "Fluid Depot",       has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },
  { key: "vehicle_hangar",    name: "Vehicle Hangar",    has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },
  { key: "artillery_hangar",  name: "Artillery Hangar",  has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },
  { key: "air_hangar",        name: "Air Hangar",        has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },
  { key: "infantry_barracks", name: "Infantry Barracks", has_hp: true,  rules: { levels: { "1" => { workers_required: 10 } } } },

  # Ayuntamiento (excepción: sin HP)
  { key: "town_hall", name: "Town Hall", has_hp: false, rules: { levels: { "1" => {} } } }
]

buildings.each do |attrs|
  Building.find_or_create_by!(key: attrs[:key]) do |b|
    b.name = attrs[:name]
    b.description = ""
    b.image = ""
    b.infrastructure_cost = 0
    b.has_hp = attrs[:has_hp]
    b.rules = attrs[:rules]
  end
end

puts "✅ Buildings ensured: #{Building.count}"
