# frozen_string_literal: true

class City
  class AssignStorage
    Result = Struct.new(:ok?, :city_building, :error, :details, keyword_init: true)

    ERROR_NOT_FOUND             = :not_found
    ERROR_INVALID_INPUT         = :invalid_input
    ERROR_FORBIDDEN             = :forbidden
    ERROR_NOT_ASSIGNABLE        = :building_not_assignable
    ERROR_INCOMPATIBLE_RESOURCE = :incompatible_resource
    ERROR_OVERFLOW              = :overflow_after_reassignment

    STORAGE_PER_LEVEL = 10_000

    def self.call(user:, city: nil, city_id: nil, city_building_id:, assigned_resource:)
      new(
        user: user,
        city: city,
        city_id: city_id,
        city_building_id: city_building_id,
        assigned_resource: assigned_resource
      ).call
    end

    def initialize(user:, city:, city_id:, city_building_id:, assigned_resource:)
      @user = user
      @city = city
      @city_id = city_id
      @city_building_id = city_building_id
      @assigned_resource_raw = assigned_resource
    end

    def call
      city = resolve_city
      return city if city.is_a?(Result)

      city.with_lock do
        city_building = city.city_buildings.includes(:building).find_by(id: @city_building_id)
        return Result.new(ok?: false, error: ERROR_NOT_FOUND, details: { city_building_id: @city_building_id }) unless city_building

        unless city_building.assignable_storage_building?
          return Result.new(
            ok?: false,
            error: ERROR_NOT_ASSIGNABLE,
            details: { city_building_id: city_building.id }
          )
        end

        desired_resource = parse_resource(@assigned_resource_raw)
        return desired_resource if desired_resource.is_a?(Result)

        unless city_building.allowed_assigned_resources.include?(desired_resource)
          return Result.new(
            ok?: false,
            error: ERROR_INCOMPATIBLE_RESOURCE,
            details: {
              city_building_id: city_building.id,
              building_key: building_key_for(city_building),
              assigned_resource: desired_resource
            }
          )
        end

        previous_resource = city_building.assigned_resource

        if previous_resource == desired_resource
          return Result.new(
            ok?: true,
            city_building: city_building,
            details: { noop: true }
          )
        end

        overflow_result = ensure_reassignment_is_safe(
          city: city,
          city_building: city_building,
          previous_resource: previous_resource,
          desired_resource: desired_resource
        )
        return overflow_result if overflow_result

        city_building.update!(assigned_resource: desired_resource)

        record_ledger_event!(
          city: city,
          city_building: city_building,
          previous_resource: previous_resource,
          assigned_resource: desired_resource
        )

        Result.new(ok?: true, city_building: city_building)
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

    def parse_resource(raw)
      value = raw.to_s.strip.downcase
      return Result.new(ok?: false, error: ERROR_INVALID_INPUT, details: { reason: "blank_resource" }) if value.blank?

      value
    end

    def ensure_reassignment_is_safe(city:, city_building:, previous_resource:, desired_resource:)
      resources_to_check = [ previous_resource ].compact.uniq
      return nil if resources_to_check.empty?

      resources_to_check.each do |resource|
        current_amount = city.public_send(resource).to_i
        projected_max = projected_max_storage_for(
          city: city,
          city_building: city_building,
          desired_resource: desired_resource,
          resource: resource
        )

        next if current_amount <= projected_max

        return Result.new(
          ok?: false,
          error: ERROR_OVERFLOW,
          details: {
            resource: resource,
            current_amount: current_amount,
            projected_max_storage: projected_max,
            city_building_id: city_building.id
          }
        )
      end

      nil
    end

    def projected_max_storage_for(city:, city_building:, desired_resource:, resource:)
      family_scope =
        if city_building.resource_depot_building?
          city.city_buildings.includes(:building).select(&:resource_depot_building?)
        elsif city_building.fluid_depot_building?
          city.city_buildings.includes(:building).select(&:fluid_depot_building?)
        else
          []
        end

      family_scope.sum do |cb|
        effective_resource =
          if cb.id == city_building.id
            desired_resource
          else
            cb.assigned_resource
          end

        next 0 unless effective_resource == resource

        cb.level.to_i * STORAGE_PER_LEVEL
      end
    end

    def building_key_for(city_building)
      city_building.building&.key ||
        city_building.building&.code ||
        city_building.building&.slug ||
        city_building.building&.kind ||
        city_building.building&.name
    end

    def record_ledger_event!(city:, city_building:, previous_resource:, assigned_resource:)
      LedgerEvent.create!(
        city: city,
        actor_user: @user,
        action_type: "assign_storage",
        delta: {},
        meta: {
          "city_building_id" => city_building.id,
          "building_key" => building_key_for(city_building),
          "previous_assigned_resource" => previous_resource,
          "assigned_resource" => assigned_resource
        }
      )
    end
  end
end
