# frozen_string_literal: true

class City
  class AssignWorkers
    Result = Struct.new(:ok?, :city_building, :error, :details, keyword_init: true)

    ERROR_NOT_FOUND      = :not_found
    ERROR_INVALID_INPUT  = :invalid_input
    ERROR_OVER_CAPACITY  = :over_capacity
    ERROR_OVER_REQUIRED  = :over_required
    ERROR_DISABLED       = :building_disabled
    ERROR_FORBIDDEN      = :forbidden

    MAX_PARAM_WORKERS = 10_000_000

    def self.call(user:, city: nil, city_id: nil, city_building_id:, workers_assigned:)
      new(
        user: user,
        city: city,
        city_id: city_id,
        city_building_id: city_building_id,
        workers_assigned: workers_assigned
      ).call
    end

    def initialize(user:, city:, city_id:, city_building_id:, workers_assigned:)
      @user = user
      @city = city
      @city_id = city_id
      @city_building_id = city_building_id
      @workers_assigned_raw = workers_assigned
    end

    def call
      city = resolve_city
      return city if city.is_a?(Result)

      city.with_lock do
        cb = city.city_buildings.find_by(id: @city_building_id)
        return Result.new(ok?: false, error: ERROR_NOT_FOUND, details: { city_building_id: @city_building_id }) unless cb

        if cb.respond_to?(:enabled?) && !cb.enabled?
          return Result.new(ok?: false, error: ERROR_DISABLED, details: { city_building_id: cb.id })
        end

        desired = parse_workers(@workers_assigned_raw)
        return desired if desired.is_a?(Result)

        required = cb.workers_required.to_i
        if desired > required
          return Result.new(ok?: false, error: ERROR_OVER_REQUIRED, details: { desired: desired, workers_required: required })
        end

        capacity = city.workers_population.to_i
        other_assigned = city.city_buildings.where.not(id: cb.id).sum(:workers_assigned).to_i

        if other_assigned + desired > capacity
          return Result.new(
            ok?: false,
            error: ERROR_OVER_CAPACITY,
            details: { capacity: capacity, other_assigned: other_assigned, desired: desired }
          )
        end

        workers_before = cb.workers_assigned.to_i

        cb.update!(workers_assigned: desired)

        record_ledger_event!(
          city: city,
          city_building: cb,
          workers_before: workers_before,
          workers_after: desired
        )

        Result.new(ok?: true, city_building: cb)
      end
    end

    private

    def resolve_city
      if @city
        return Result.new(ok?: false, error: ERROR_FORBIDDEN) unless @city.user_id == @user.id
        return @city
      end

      city = @user.cities.find_by(id: @city_id)
      return Result.new(ok?: false, error: ERROR_NOT_FOUND, details: { city_id: @city_id }) unless city

      city
    end

    def parse_workers(raw)
      return Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { reason: "missing" }) if raw.nil?

      desired = Integer(raw)
      return Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { reason: "negative" }) if desired.negative?
      return Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { reason: "too_large" }) if desired > MAX_PARAM_WORKERS

      desired
    rescue ArgumentError, TypeError
      Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { reason: "not_an_integer" })
    end

    def record_ledger_event!(city:, city_building:, workers_before:, workers_after:)
      LedgerEvent.create!(
        city: city,
        actor_user: @user,
        action_type: "assign_workers",
        delta: {},
        meta: {
          "city_building_id" => city_building.id,
          "workers_before" => workers_before,
          "workers_after" => workers_after
        }
      )
    end
  end
end
