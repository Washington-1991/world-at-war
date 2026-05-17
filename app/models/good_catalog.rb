module GoodCatalog
  GOODS = {
    "food"             => { kind: "resource", final_storage_target: "deposit",          city_attribute: "food" },
    "coal"             => { kind: "resource", final_storage_target: "deposit",          city_attribute: "coal" },
    "iron_ore"         => { kind: "resource", final_storage_target: "deposit",          city_attribute: "iron_ore" },
    "stone"            => { kind: "resource", final_storage_target: "deposit",          city_attribute: "stone" },
    "wood"             => { kind: "resource", final_storage_target: "deposit",          city_attribute: "wood" },
    "crude_oil"        => { kind: "fluid",    final_storage_target: "fluid_deposit",    city_attribute: "crude_oil" },
    "fuel"             => { kind: "fluid",    final_storage_target: "fluid_deposit",    city_attribute: "fuel" },

    "steel"            => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },
    "components"       => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },
    "engines"          => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },
    "light_ammunition" => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },
    "heavy_ammunition" => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },
    "weapons_level_1"  => { kind: "product",  final_storage_target: "deposit",          city_attribute: nil },

    "trucks"           => { kind: "vehicle",  final_storage_target: "vehicle_hangar",   city_attribute: nil },
    "tanks"            => { kind: "vehicle",  final_storage_target: "vehicle_hangar",   city_attribute: nil },
    "artillery_pieces" => { kind: "weapon",   final_storage_target: "artillery_hangar", city_attribute: nil },
    "aircraft"         => { kind: "aircraft", final_storage_target: "air_hangar",       city_attribute: nil }
  }.freeze

  class << self
    def normalize(key)
      key.to_s.strip.downcase.presence
    end

    def keys
      GOODS.keys
    end

    def include?(key)
      GOODS.key?(normalize(key))
    end

    def fetch!(key)
      normalized = normalize(key)
      config = GOODS[normalized]
      raise ArgumentError, "Unsupported good: #{key}" if config.nil?

      config
    end

    def kind_for(key)
      fetch!(key)[:kind]
    end

    def final_storage_target_for(key)
      fetch!(key)[:final_storage_target]
    end

    def city_attribute_for(key)
      fetch!(key)[:city_attribute]
    end

    def uses_legacy_city_attribute?(key)
      city_attribute_for(key).present?
    end

    # Todos los bienes que se almacenan en city_stored_goods.
    #
    # Incluye:
    # - productos comunes: steel, components, engines...
    # - bienes especializados: trucks, tanks, artillery_pieces, aircraft
    def stored_good_keys
      GOODS.select { |_key, config| config[:city_attribute].nil? }.keys
    end

    # Bienes almacenables en depósito común.
    #
    # Importante:
    # No incluye trucks, tanks, artillery_pieces ni aircraft,
    # porque esos bienes usan hangares especializados.
    def generic_stored_good_keys
      GOODS.select do |_key, config|
        config[:city_attribute].nil? &&
          config[:final_storage_target] == "deposit"
      end.keys
    end

    def transportable_keys
      keys
    end
  end
end
