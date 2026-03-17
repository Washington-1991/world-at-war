class City::CompleteDueLogisticOperations
  def self.call(now: Time.current)
    new(now: now).call
  end

  def initialize(now: Time.current)
    @now = now
  end

  def call
    LogisticOperation.due_for_completion(now).find_each do |operation|
      complete_operation(operation)
    end
  end

  private

  attr_reader :now

  def complete_operation(operation)
    LogisticOperation.transaction do
      operation.lock!

      return unless completable?(operation)

      locked_cities = lock_cities_in_stable_order(operation)
      destination = locked_cities.fetch(operation.destination_city_id)

      destination.update!(
        operation.resource => destination.public_send(operation.resource) + operation.amount
      )

      operation.update!(
        status: LogisticOperation::STATUSES[:completed],
        completed_at: now
      )
    end
  end

  def completable?(operation)
    operation.in_transit? && operation.arrival_at <= now
  end

  def lock_cities_in_stable_order(operation)
    city_ids = [ operation.origin_city_id, operation.destination_city_id ].sort

    City.where(id: city_ids)
        .order(:id)
        .lock
        .index_by(&:id)
  end
end
