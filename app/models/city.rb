class City < ApplicationRecord
  belongs_to :user
  has_many :city_buildings, dependent: :destroy
  has_many :ledger_events, dependent: :destroy
  has_many :city_logistic_stocks, dependent: :destroy
  has_many :city_stored_goods, dependent: :destroy

  has_many :outgoing_logistic_operations,
           class_name: "LogisticOperation",
           foreign_key: :origin_city_id,
           inverse_of: :origin_city,
           dependent: :destroy

  has_many :incoming_logistic_operations,
           class_name: "LogisticOperation",
           foreign_key: :destination_city_id,
           inverse_of: :destination_city,
           dependent: :destroy

  INITIAL_POPULATION = 10_000
  STARTER_PACK       = 10_000

  WORKFORCE_RATE_NUM = 60
  WORKFORCE_RATE_DEN = 100

  BASE_INFRASTRUCTURE_CAPACITY = 500
  INFRASTRUCTURE_CAPACITY_PER_LEVEL = 500
  MAX_INFRASTRUCTURE_LEVEL = 10

  LOGISTIC_STATION_BUILDING_KEYS = %w[logistic_station].freeze
  LOGISTIC_CAPACITY_PER_LEVEL = 10_000

  DEPOSIT_BUILDING_KEYS = %w[resource_depot deposit].freeze
  FLUID_DEPOSIT_BUILDING_KEYS = %w[fluid_depot fluid_deposit].freeze

  VEHICLE_HANGAR_BUILDING_KEYS = %w[vehicle_hangar].freeze
  ARTILLERY_HANGAR_BUILDING_KEYS = %w[artillery_hangar].freeze
  AIR_HANGAR_BUILDING_KEYS = %w[air_hangar].freeze

  STORAGE_CAPACITY_PER_LEVEL = 10_000
  SPECIALIZED_STORAGE_CAPACITY_PER_LEVEL = 100

  HALL_BUILDING_KEYS = %w[hall town_hall].freeze

  HALL_BASE_STORAGE = {
    "food"     => 10_000,
    "wood"     => 10_000,
    "stone"    => 10_000,
    "iron_ore" => 10_000
  }.freeze

  before_validation :set_initial_state, on: :create

  NON_NEGATIVE_INTEGERS = %i[
    total_population free_population workers_population military_population
    university_population laboratory_population
    food coal iron_ore stone wood crude_oil fuel
    energy knowledge money
  ].freeze

  NON_NEGATIVE_INTEGERS.each do |field|
    validates field, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end

  validates :infrastructure_level,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: MAX_INFRASTRUCTURE_LEVEL
            }

  validate :population_must_balance

  def tick!(now: Time.current)
    City::Tick.new(self, now: now).call
  end

  def infrastructure_capacity
    BASE_INFRASTRUCTURE_CAPACITY + (infrastructure_level * INFRASTRUCTURE_CAPACITY_PER_LEVEL)
  end

  def infrastructure_used
    city_buildings.includes(:building).sum do |city_building|
      city_building.building.infrastructure_cost_value
    end
  end

  def infrastructure_free
    infrastructure_capacity - infrastructure_used
  end

  def enough_infrastructure_for?(building)
    infrastructure_free >= building.infrastructure_cost_value
  end

  def total_trucks_capacity
    city_buildings.includes(:building).sum(&:trucks_capacity)
  end

  def occupied_trucks_capacity
    outgoing_logistic_operations.active.sum(:trucks_assigned).to_i
  end

  def available_trucks_capacity
    free = total_trucks_capacity - occupied_trucks_capacity
    free.positive? ? free : 0
  end

  def enough_trucks_for?(requested_trucks)
    available_trucks_capacity >= requested_trucks.to_i
  end

  def logistic_station_level
    city_buildings
      .joins(:building)
      .where(buildings: { key: LOGISTIC_STATION_BUILDING_KEYS })
      .sum(:level)
      .to_i
  end

  def logistic_capacity_for(good_key)
    normalize_good_key!(good_key)
    logistic_station_level * LOGISTIC_CAPACITY_PER_LEVEL
  end

  def logistic_stock_for(good_key)
    normalized = normalize_good_key!(good_key)
    city_logistic_stocks.find_by(good_key: normalized)&.amount.to_i
  end

  def logistic_free_for(good_key)
    free = logistic_capacity_for(good_key) - logistic_stock_for(good_key)
    free.positive? ? free : 0
  end

  def enough_logistic_capacity_for?(good_key, amount)
    logistic_free_for(good_key) >= amount.to_i
  end

  # Stock utilizable/operativo. No incluye buffer en logistic_station.
  def available_good_amount(good_key)
    stored_amount_for(good_key)
  end

  def max_storage_for(resource)
    normalized = resource.to_s.strip.downcase

    if normalized == "knowledge"
      library_levels = city_buildings
                         .joins(:building)
                         .where(buildings: { key: "library" })
                         .sum(:level)
                         .to_i

      return library_levels * 5_000
    end

    normalize_good_key!(normalized)

    target = GoodCatalog.final_storage_target_for(normalized)
    building_keys = storage_building_keys_for!(normalized)

    if shared_storage_target?(target)
      total_levels = city_buildings
                       .joins(:building)
                       .where(buildings: { key: building_keys })
                       .sum(:level)
                       .to_i

      return total_levels * SPECIALIZED_STORAGE_CAPACITY_PER_LEVEL
    end

    hall_base = hall_base_storage_for(normalized)

    total_levels = city_buildings
                     .joins(:building)
                     .where(buildings: { key: building_keys }, assigned_resource: normalized)
                     .sum(:level)
                     .to_i

    hall_base + (total_levels * STORAGE_CAPACITY_PER_LEVEL)
  end

  def storage_free_for(resource)
    free = max_storage_for(resource) - storage_used_for(resource)
    free.positive? ? free : 0
  end

  def remove_available_good!(good_key, amount)
    normalized = normalize_good_key!(good_key)
    requested = amount.to_i

    raise ArgumentError, "amount must be greater than 0" unless requested.positive?

    current = stored_amount_for(normalized)
    raise ArgumentError, "insufficient available good: #{normalized}" if current < requested

    decrease_final_stored_good!(normalized, requested)
  end

  def add_available_good!(good_key, amount)
    normalized = normalize_good_key!(good_key)
    received = amount.to_i

    raise ArgumentError, "amount must be greater than 0" unless received.positive?

    increase_final_stored_good!(normalized, received)
  end

  def receive_good_into_logistics!(good_key, amount)
    normalized = normalize_good_key!(good_key)
    received = amount.to_i

    raise ArgumentError, "amount must be greater than 0" unless received.positive?
    raise ArgumentError, "insufficient free logistic capacity for #{normalized}" unless enough_logistic_capacity_for?(normalized, received)

    stock = find_or_initialize_logistic_stock_record(normalized)
    stock.amount = stock.amount.to_i + received
    stock.save!

    unloaded_amount = transfer_logistic_good_to_storage!(normalized)

    {
      received_amount: received,
      unloaded_amount: unloaded_amount,
      remaining_in_logistics: logistic_stock_for(normalized)
    }
  end

  def flush_logistic_goods_to_storage!
    city_logistic_stocks.each_with_object({}) do |stock, moved|
      amount = transfer_logistic_good_to_storage!(stock.good_key)
      moved[stock.good_key] = amount if amount.positive?
    end
  end

  def transfer_logistic_good_to_storage!(good_key)
    normalized = normalize_good_key!(good_key)

    stock = find_or_initialize_logistic_stock_record(normalized)
    pending = stock.amount.to_i
    return 0 if pending <= 0

    free_storage = storage_free_for(normalized)
    move_amount = [ pending, free_storage ].min
    return 0 if move_amount <= 0

    increase_final_stored_good!(normalized, move_amount)

    stock.amount = pending - move_amount
    stock.save!

    move_amount
  end

  def population_breakdown_sum
    free_population + workers_population + military_population +
      university_population + laboratory_population
  end

  def compute_workers_population(total_pop = total_population)
    total = total_pop.to_i

    non_civil = military_population.to_i + university_population.to_i + laboratory_population.to_i
    base = total - non_civil
    base = 0 if base.negative?

    (base * WORKFORCE_RATE_NUM) / WORKFORCE_RATE_DEN
  end

  def sync_workforce!(already_locked: false)
    if already_locked
      run_sync_workforce!
    else
      with_lock { run_sync_workforce! }
    end
  end

  private

  def set_initial_state
    if total_population.zero? &&
       free_population.zero? &&
       workers_population.zero? &&
       military_population.zero? &&
       university_population.zero? &&
       laboratory_population.zero?

      self.total_population = INITIAL_POPULATION

      target_workers = compute_workers_population(INITIAL_POPULATION)

      self.workers_population = target_workers
      self.free_population    = INITIAL_POPULATION - target_workers
    end

    self.food  = STARTER_PACK if food.zero?
    self.wood  = STARTER_PACK if wood.zero?
    self.stone = STARTER_PACK if stone.zero?
    self.money = STARTER_PACK if money.zero?

    self.infrastructure_level = 0 if infrastructure_level.nil?
  end

  def population_must_balance
    return if total_population == population_breakdown_sum

    errors.add(:total_population, "must equal sum of all population groups")
  end

  def hall_base_storage_for(good_key)
    return 0 unless HALL_BASE_STORAGE.key?(good_key)

    hall_exists = city_buildings
                    .joins(:building)
                    .where(buildings: { key: HALL_BUILDING_KEYS })
                    .exists?

    hall_exists ? HALL_BASE_STORAGE[good_key] : 0
  end

  def storage_building_keys_for!(good_key)
    target = GoodCatalog.final_storage_target_for(good_key)

    case target
    when "deposit"
      DEPOSIT_BUILDING_KEYS
    when "fluid_deposit"
      FLUID_DEPOSIT_BUILDING_KEYS
    when "vehicle_hangar"
      VEHICLE_HANGAR_BUILDING_KEYS
    when "artillery_hangar"
      ARTILLERY_HANGAR_BUILDING_KEYS
    when "air_hangar"
      AIR_HANGAR_BUILDING_KEYS
    else
      raise ArgumentError, "Unsupported final storage target for #{good_key}: #{target}"
    end
  end

  def shared_storage_target?(target)
    %w[
      vehicle_hangar
      artillery_hangar
      air_hangar
    ].include?(target)
  end

  def storage_used_for(resource)
    normalized = resource.to_s.strip.downcase

    return knowledge.to_i if normalized == "knowledge"

    normalize_good_key!(normalized)

    target = GoodCatalog.final_storage_target_for(normalized)

    return stored_amount_for(normalized) unless shared_storage_target?(target)

    GoodCatalog.stored_good_keys.sum do |good_key|
      next 0 unless GoodCatalog.final_storage_target_for(good_key) == target

      stored_amount_for(good_key)
    end
  end

  def stored_amount_for(key)
    normalized = key.to_s.strip.downcase

    return knowledge.to_i if normalized == "knowledge"

    normalize_good_key!(normalized)

    if GoodCatalog.uses_legacy_city_attribute?(normalized)
      attribute = GoodCatalog.city_attribute_for(normalized)
      public_send(attribute).to_i
    else
      city_stored_goods.find_by(good_key: normalized)&.amount.to_i
    end
  end

  def increase_final_stored_good!(good_key, amount)
    normalized = normalize_good_key!(good_key)
    delta = amount.to_i

    raise ArgumentError, "amount must be greater than 0" unless delta.positive?

    if GoodCatalog.uses_legacy_city_attribute?(normalized)
      attribute = GoodCatalog.city_attribute_for(normalized)
      self.public_send("#{attribute}=", public_send(attribute).to_i + delta)
      save!
    else
      stock = find_or_initialize_stored_good_record(normalized)
      stock.amount = stock.amount.to_i + delta
      stock.save!
    end
  end

  def decrease_final_stored_good!(good_key, amount)
    normalized = normalize_good_key!(good_key)
    delta = amount.to_i

    raise ArgumentError, "amount must be greater than 0" unless delta.positive?

    current = stored_amount_for(normalized)
    raise ArgumentError, "insufficient available good: #{normalized}" if current < delta

    if GoodCatalog.uses_legacy_city_attribute?(normalized)
      attribute = GoodCatalog.city_attribute_for(normalized)
      self.public_send("#{attribute}=", current - delta)
      save!
    else
      stock = find_or_initialize_stored_good_record(normalized)
      stock.amount = current - delta
      stock.save!
    end
  end

  def normalize_good_key!(good_key)
    normalized = GoodCatalog.normalize(good_key)
    GoodCatalog.fetch!(normalized)
    normalized
  end

  def find_or_initialize_logistic_stock_record(good_key)
    normalized = normalize_good_key!(good_key)

    city_logistic_stocks.find_or_initialize_by(good_key: normalized) do |stock|
      stock.amount = 0
    end
  end

  def find_or_initialize_stored_good_record(good_key)
    normalized = normalize_good_key!(good_key)

    city_stored_goods.find_or_initialize_by(good_key: normalized) do |stock|
      stock.amount = 0
    end
  end

  def run_sync_workforce!
    target_workers = compute_workers_population(total_population)

    non_free = military_population.to_i + university_population.to_i + laboratory_population.to_i + target_workers
    new_free = total_population.to_i - non_free

    if new_free.negative?
      raise ActiveRecord::RecordInvalid.new(self), "Invalid population breakdown: free would be negative"
    end

    update!(workers_population: target_workers, free_population: new_free)

    city_buildings.where(enabled: false).where.not(workers_assigned: 0)
                  .update_all(workers_assigned: 0, updated_at: Time.current)

    total_assigned = city_buildings.sum(:workers_assigned).to_i
    overflow = total_assigned - workers_population.to_i
    return if overflow <= 0

    city_buildings.order(id: :desc).find_each do |cb|
      break if overflow <= 0

      wa = cb.workers_assigned.to_i
      next if wa <= 0

      reduce_by = [ wa, overflow ].min
      cb.update!(workers_assigned: wa - reduce_by)
      overflow -= reduce_by
    end
  end
end
