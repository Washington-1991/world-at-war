class City::CompleteDueLogisticOperations
  def self.call(now: Time.current)
    new(now: now).call
  end

  def initialize(now: Time.current)
    @now = now
  end

  def call
    LogisticOperation.due_for_completion(@now).pluck(:id).each do |operation_id|
      complete_operation!(operation_id)
    end
  end

  private

  def complete_operation!(operation_id)
    LogisticOperation.transaction do
      operation = LogisticOperation.lock.includes(:market_listing).find_by(id: operation_id)
      return if operation.nil?
      return unless completable?(operation)

      with_locked_cities(operation.origin_city, operation.destination_city) do |origin, destination|
        operation.reload
        destination.reload
        origin.reload

        return unless completable?(operation)

        receipt = destination.receive_good_into_logistics!(operation.resource_key, operation.amount)

        operation.update!(
          status: "completed",
          completed_at: @now
        )

        record_transport_completed_ledger_event!(
          operation: operation,
          destination: destination,
          receipt: receipt
        )

        settle_market_sale_if_needed!(
          operation: operation,
          seller_city: origin
        )
      end
    end
  end

  def completable?(operation)
    operation.in_transit? &&
      operation.completed_at.blank? &&
      operation.arrival_at.present? &&
      operation.arrival_at <= @now
  end

  def settle_market_sale_if_needed!(operation:, seller_city:)
    return unless operation.market_operation?
    return if market_sale_already_completed?(operation)

    total_price = operation.market_total_price.to_i
    return if total_price <= 0

    seller_city.update!(money: seller_city.money.to_i + total_price)

    LedgerEvent.create!(
      city: seller_city,
      actor_user: operation.market_listing&.seller_user,
      action_type: "market_sale_completed",
      delta: { "money" => total_price },
      meta: {
        "source" => "market",
        "listing_id" => operation.market_listing_id,
        "logistic_operation_id" => operation.id,
        "seller_city_id" => seller_city.id,
        "buyer_city_id" => operation.destination_city_id,
        "good_key" => operation.resource_key,
        "amount" => operation.amount,
        "market_total_price" => total_price
      }
    )
  end

  def market_sale_already_completed?(operation)
    LedgerEvent.exists?(
      city_id: operation.origin_city_id,
      action_type: "market_sale_completed",
      meta: {
        "logistic_operation_id" => operation.id
      }
    )
  end

  def record_transport_completed_ledger_event!(operation:, destination:, receipt:)
    unloaded_amount = receipt[:unloaded_amount].to_i
    delta = unloaded_amount.positive? ? { operation.resource_key => unloaded_amount } : {}

    LedgerEvent.create!(
      city: destination,
      actor_user: nil,
      action_type: "transport_completed",
      delta: delta,
      meta: {
        "source" => "logistics",
        "origin_city_id" => operation.origin_city_id,
        "destination_city_id" => operation.destination_city_id,
        "resource" => operation.resource_key,
        "requested_amount" => operation.amount,
        "received_amount" => receipt[:received_amount].to_i,
        "unloaded_amount" => unloaded_amount,
        "remaining_in_logistics" => receipt[:remaining_in_logistics].to_i,
        "trucks_assigned" => operation.trucks_assigned,
        "distance_km" => operation.distance_km.to_f,
        "logistic_operation_id" => operation.id
      }
    )
  end

  def with_locked_cities(origin_city, destination_city)
    first_city, second_city = [origin_city, destination_city].sort_by(&:id)

    first_city.with_lock do
      second_city.with_lock do
        origin = first_city.id == origin_city.id ? first_city : second_city
        destination = first_city.id == destination_city.id ? first_city : second_city

        yield(origin, destination)
      end
    end
  end
end