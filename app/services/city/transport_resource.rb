class City::TransportResource
  class Error < StandardError; end

  DEFAULT_ETA_HOURS = 1

  def initialize(origin_city:, destination_city:, actor_user:, resource_key:, amount:, trucks_assigned:, eta_hours: DEFAULT_ETA_HOURS, now: Time.current)
    @origin_city = origin_city
    @destination_city = destination_city
    @actor_user = actor_user
    @resource_key = resource_key.to_s.strip.downcase
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

      ensure_resource_exists_on_origin!(locked_origin)
      ensure_enough_resource!(locked_origin)
      ensure_enough_trucks!(locked_origin)

      locked_origin.update!(
        @resource_key => locked_origin.public_send(@resource_key).to_i - @amount
      )

      LogisticOperation.create!(
        origin_city: locked_origin,
        destination_city: locked_destination,
        resource: @resource_key,
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

    unless LogisticOperation::TRANSPORTABLE_RESOURCES.include?(@resource_key)
      raise Error, "resource is not transportable"
    end

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

  def ensure_resource_exists_on_origin!(city)
    unless city.respond_to?(@resource_key)
      raise Error, "origin city does not support this resource"
    end
  end

  def ensure_enough_resource!(city)
    current_amount = city.public_send(@resource_key).to_i
    return if current_amount >= @amount

    raise Error, "insufficient resource in origin city"
  end

  def ensure_enough_trucks!(city)
    if city.respond_to?(:enough_trucks_for?)
      return if city.enough_trucks_for?(@trucks_assigned)
      raise Error, "insufficient available trucks"
    end

    raise Error, "city truck availability logic is not implemented"
  end

  # Orden estable para reducir riesgo de deadlocks.
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
