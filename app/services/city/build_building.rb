class City::BuildBuilding
  class Error < StandardError; end
  class BuildingNotFoundError < Error; end
  class NotEnoughInfrastructureError < Error; end
  class BuildingAlreadyExistsError < Error; end
  class NotEnoughResourcesError < Error; end
  class InvalidBuildCostError < Error; end

  def initialize(city:, building_key:, actor_user: nil)
    @city = city
    @building_key = building_key
    @actor_user = actor_user
  end

  def call
    city.with_lock do
      building = Building.find_by(key: building_key)
      raise BuildingNotFoundError, "Building not found: #{building_key}" if building.nil?

      unless city.enough_infrastructure_for?(building)
        raise NotEnoughInfrastructureError, "Not enough infrastructure for #{building.key}"
      end

      if city.city_buildings.exists?(building_id: building.id)
        raise BuildingAlreadyExistsError, "Building already exists in city: #{building.key}"
      end

      build_cost = normalized_build_cost_for(building, 1)
      ensure_enough_resources!(build_cost)
      apply_build_cost!(build_cost)

      max_hp = building.hp_base_for(1)
      hp = max_hp

      city_building = CityBuilding.create!(
        city: city,
        building: building,
        level: 1,
        workers_assigned: 0,
        enabled: true,
        hp: hp,
        max_hp: max_hp
      )

      LedgerEvent.create!(
        city: city,
        actor_user_id: actor_user&.id,
        action_type: "build",
        delta: ledger_delta_for(build_cost),
        meta: {
          building_key: building.key,
          level: 1,
          city_building_id: city_building.id
        }
      )

      city_building
    end
  end

  private

  attr_reader :city, :building_key, :actor_user

  def normalized_build_cost_for(building, level)
    raw_cost = building.build_cost_for(level)

    unless raw_cost.is_a?(Hash)
      raise InvalidBuildCostError, "Invalid build cost for #{building.key}"
    end

    raw_cost.each_with_object({}) do |(resource, amount), normalized|
      resource_name = resource.to_s
      amount_value = amount.to_i

      unless allowed_resource?(resource_name)
        raise InvalidBuildCostError, "Invalid resource in build cost: #{resource_name}"
      end

      if amount_value.negative?
        raise InvalidBuildCostError, "Negative build cost for #{resource_name}"
      end

      normalized[resource_name] = amount_value
    end
  end

  def ensure_enough_resources!(build_cost)
    build_cost.each do |resource, amount|
      next if amount.zero?

      current_amount = city.public_send(resource)
      next if current_amount >= amount

      raise NotEnoughResourcesError, "Not enough #{resource}"
    end
  end

  def apply_build_cost!(build_cost)
    build_cost.each do |resource, amount|
      next if amount.zero?

      current_amount = city.public_send(resource)
      city.public_send("#{resource}=", current_amount - amount)
    end

    city.save! if build_cost.any?
  end

  def ledger_delta_for(build_cost)
    build_cost.each_with_object({}) do |(resource, amount), delta|
      delta[resource] = -amount
    end
  end

  def allowed_resource?(resource_name)
    %w[
      food coal iron_ore stone wood crude_oil fuel
      energy knowledge money
    ].include?(resource_name)
  end
end
