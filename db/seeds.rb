# db/seeds.rb

admin_email = ENV.fetch("WAW_ADMIN_EMAIL", nil)
admin_name  = ENV.fetch("WAW_ADMIN_NAME", "Admin")
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
  # Producción primaria
  {
    key: "farm",
    name: "Farm",
    infrastructure_cost: 8,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 120,
          workers_required: 100,
          build_cost: { wood: 50, stone: 30, money: 20 },
          outputs: { food: 100 }
        }
      }
    }
  },
  {
    key: "coal_mine",
    name: "Coal Mine",
    infrastructure_cost: 9,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 100,
          build_cost: { wood: 40, stone: 60, money: 30 },
          outputs: { coal: 100 },
          maintenance: { money: 20 }
        }
      }
    }
  },
  {
    key: "iron_mine",
    name: "Iron Mine",
    infrastructure_cost: 9,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 100,
          build_cost: { wood: 40, stone: 60, money: 30 },
          outputs: { iron_ore: 100 },
          maintenance: { money: 20 }
        }
      }
    }
  },
  {
    key: "quarry",
    name: "Quarry",
    infrastructure_cost: 9,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 100,
          build_cost: { wood: 35, stone: 55, money: 30 },
          outputs: { stone: 100 },
          maintenance: { money: 20 }
        }
      }
    }
  },
  {
    key: "sawmill",
    name: "Sawmill",
    infrastructure_cost: 7,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 120,
          workers_required: 100,
          build_cost: { wood: 30, stone: 25, money: 20 },
          outputs: { wood: 100 }
        }
      }
    }
  },
  {
    key: "oil_well",
    name: "Oil Well",
    infrastructure_cost: 8,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 100,
          build_cost: { wood: 45, stone: 50, money: 40 },
          outputs: { crude_oil: 100 }
        }
      }
    }
  },

  # Energía / refinado
  {
    key: "coal_power_plant",
    name: "Coal Power Plant",
    infrastructure_cost: 7,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 200,
          workers_required: 100,
          build_cost: { wood: 60, stone: 80, money: 50 },
          inputs: { coal: 50 },
          outputs: { energy: 500 }
        }
      }
    }
  },
  {
    key: "refinery",
    name: "Refinery",
    infrastructure_cost: 7,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 180,
          workers_required: 100,
          build_cost: { wood: 55, stone: 70, money: 50 },
          inputs: { crude_oil: 25 },
          outputs: { fuel: 125 }
        }
      }
    }
  },

  # Conocimiento
  {
    key: "university",
    name: "University",
    infrastructure_cost: 8,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 10,
          build_cost: { wood: 70, stone: 60, money: 60 },
          outputs: { knowledge: 1 }
        }
      }
    }
  },
  {
    key: "laboratory",
    name: "Laboratory",
    infrastructure_cost: 7,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 10,
          build_cost: { wood: 65, stone: 55, money: 70 },
          inputs: { knowledge: 2 }
        }
      }
    }
  },
  {
    key: "library",
    name: "Library",
    infrastructure_cost: 5,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 100,
          workers_required: 10,
          build_cost: { wood: 40, stone: 25, money: 30 }
        }
      }
    }
  },

  # Soporte / almacenamiento / militar
  {
    key: "resource_depot",
    name: "Resource Depot",
    infrastructure_cost: 5,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 120,
          workers_required: 10,
          build_cost: { wood: 45, stone: 35, money: 25 }
        }
      }
    }
  },
  {
    key: "fluid_depot",
    name: "Fluid Depot",
    infrastructure_cost: 5,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 120,
          workers_required: 10,
          build_cost: { wood: 40, stone: 40, money: 30 }
        }
      }
    }
  },
  {
    key: "logistic_station",
    name: "Logistic Station",
    infrastructure_cost: 6,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 140,
          workers_required: 20,
          build_cost: { wood: 50, stone: 45, money: 40 },
          trucks_capacity: 100
        }
      }
    }
  },
  {
    key: "vehicle_hangar",
    name: "Vehicle Hangar",
    infrastructure_cost: 10,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 200,
          workers_required: 10,
          build_cost: { wood: 70, stone: 80, money: 60 }
        }
      }
    }
  },
  {
    key: "artillery_hangar",
    name: "Artillery Hangar",
    infrastructure_cost: 10,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 180,
          workers_required: 10,
          build_cost: { wood: 65, stone: 85, money: 60 }
        }
      }
    }
  },
  {
    key: "air_hangar",
    name: "Air Hangar",
    infrastructure_cost: 10,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 220,
          workers_required: 10,
          build_cost: { wood: 80, stone: 90, money: 80 }
        }
      }
    }
  },
  {
    key: "infantry_barracks",
    name: "Infantry Barracks",
    infrastructure_cost: 7,
    has_hp: true,
    rules: {
      levels: {
        "1" => {
          hp_base: 150,
          workers_required: 10,
          build_cost: { wood: 50, stone: 45, money: 35 }
        }
      }
    }
  },

  # Ayuntamiento
  {
    key: "town_hall",
    name: "Town Hall",
    infrastructure_cost: 0,
    has_hp: false,
    rules: {
      levels: {
        "1" => {
          build_cost: {}
        }
      }
    }
  }
]

buildings.each do |attrs|
  building = Building.find_or_initialize_by(key: attrs[:key])

  building.name = attrs[:name]
  building.description = ""
  building.image = ""
  building.infrastructure_cost = attrs[:infrastructure_cost]
  building.has_hp = attrs[:has_hp]
  building.rules = attrs[:rules]

  building.save!
end

puts "✅ Buildings ensured: #{Building.count}"
