class City::TransportResource
  class Error < StandardError; end

  DEFAULT_ETA_HOURS = 1

  def initialize(origin_city:, destination_city:, actor_user:, resource_key:, amount:, trucks_assigned:, eta_hours: DEFAULT_ETA_HOURS, now: Time.current)
    @origin_city = origin_city
    @destination_city = destination_city
    @actor_user = actor_user
    @good_key = GoodCatalog.normalize(resource_key)
    @amount = amount.to_i
    @trucks_assigned = trucks_assigned.to_i
    @eta_hours = eta_hours.to_i
    @now = now
  end

  def call
    validate_basic_rules!
    authorize!

    with_locked_cities do |locked_origin, locked_destination|
      locked_origin.reload
      locked_destination.reload

      ensure_enough_origin_stock!(locked_origin)
      ensure_enough_destination_logistic_capacity!(locked_destination)
      ensure_enough_trucks!(locked_origin)

      locked_origin.remove_available_good!(@good_key, @amount)

      LogisticOperation.create!(
        origin_city: locked_origin,
        destination_city: locked_destination,
        resource: @good_key,
        amount: @amount,
        trucks_assigned: @trucks_assigned,
        fuel_cost: 0,
        distance_km: 0,
        status: "in_transit",
        started_at: @now,
        arrival_at: @now + @eta_hours.hours
      )
    end
  end

  private

  def validate_basic_rules!
    raise Error, "origin_city is required" if @origin_city.nil?
    raise Error, "destination_city is required" if @destination_city.nil?
    raise Error, "actor_user is required" if @actor_user.nil?
    raise Error, "good is not transportable" unless GoodCatalog.include?(@good_key)

    raise Error, "amount must be greater than 0" unless @amount.positive?
    raise Error, "trucks_assigned must be greater than 0" unless @trucks_assigned.positive?
    raise Error, "eta_hours must be greater than 0" unless @eta_hours.positive?

    if @origin_city.id == @destination_city.id
      raise Error, "origin and destination must be different cities"
    end
  end

  def authorize!
    raise Error, "forbidden for origin city" unless @origin_city.user_id == @actor_user.id
    raise Error, "forbidden for destination city" unless @destination_city.user_id == @actor_user.id
  end

  def ensure_enough_origin_stock!(city)
    return if city.available_good_amount(@good_key) >= @amount

    raise Error, "insufficient stock in origin city"
  end

  def ensure_enough_destination_logistic_capacity!(city)
    return if city.enough_logistic_capacity_for?(@good_key, @amount)

    raise Error, "insufficient free logistic capacity in destination city"
  end

  def ensure_enough_trucks!(city)
    if city.respond_to?(:enough_trucks_for?)
      return if city.enough_trucks_for?(@trucks_assigned)

      raise Error, "insufficient available trucks"
    end

    raise Error, "city truck availability logic is not implemented"
  end

  def with_locked_cities
    first_city, second_city = [ @origin_city, @destination_city ].sort_by(&:id)

    first_city.with_lock do
      second_city.with_lock do
        origin = first_city.id == @origin_city.id ? first_city : second_city
        destination = first_city.id == @destination_city.id ? first_city : second_city

        yield(origin, destination)
      end
    end
  end
end
