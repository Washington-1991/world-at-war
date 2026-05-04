class Market::BuyListing
  class Error < StandardError; end

  DEFAULT_ETA_HOURS = 1

  def initialize(listing:, buyer_city:, actor_user:, amount:, trucks_assigned:, eta_hours: DEFAULT_ETA_HOURS, now: Time.current)
    @listing = listing
    @buyer_city = buyer_city
    @actor_user = actor_user
    @amount = amount.to_i
    @trucks_assigned = trucks_assigned.to_i
    @eta_hours = eta_hours.to_i
    @now = now
  end

  def call
    validate_basic_rules!
    authorize!

    with_locked_records do |locked_listing, locked_seller_city, locked_buyer_city|
      locked_listing.reload
      locked_seller_city.reload
      locked_buyer_city.reload

      ensure_listing_purchasable!(locked_listing)
      ensure_sufficient_listing_amount!(locked_listing)

      trade_context = resolve_trade_context!(locked_listing)
      ensure_trade_allowed!(trade_context)

      ensure_destination_logistic_capacity!(locked_buyer_city, locked_listing.good_key)
      ensure_seller_trucks!(locked_seller_city)

      base_price = calculate_base_price(locked_listing)
      tariff_rate_basis_points = trade_context.applied_tariff_rate_basis_points.to_i
      tariff_amount = calculate_tariff_amount(
        base_price: base_price,
        tariff_rate_basis_points: tariff_rate_basis_points
      )
      total_buyer_cost = base_price + tariff_amount

      ensure_sufficient_buyer_money!(locked_buyer_city, total_buyer_cost)

      locked_buyer_city.update!(money: locked_buyer_city.money.to_i - total_buyer_cost)

      remaining_amount = locked_listing.amount_available.to_i - @amount
      next_status = derive_next_status(locked_listing, remaining_amount)

      locked_listing.update!(
        amount_available: remaining_amount,
        status: next_status,
        sold_out_at: (next_status == "sold_out" ? @now : nil)
      )

      operation = LogisticOperation.create!(
        origin_city: locked_seller_city,
        destination_city: locked_buyer_city,
        market_listing: locked_listing,
        market_total_price: base_price,
        resource: locked_listing.good_key,
        amount: @amount,
        trucks_assigned: @trucks_assigned,
        fuel_cost: 0,
        distance_km: 0,
        status: "in_transit",
        started_at: @now,
        arrival_at: @now + @eta_hours.hours
      )

      LedgerEvent.create!(
        city: locked_buyer_city,
        actor_user: @actor_user,
        action_type: "market_purchase_started",
        delta: { "money" => -total_buyer_cost },
        meta: {
          "listing_id" => locked_listing.id,
          "buyer_city_id" => locked_buyer_city.id,
          "seller_city_id" => locked_seller_city.id,
          "buyer_user_id" => locked_buyer_city.user_id,
          "seller_user_id" => locked_listing.seller_user_id,
          "good_key" => locked_listing.good_key,
          "amount" => @amount,
          "price_per_unit" => locked_listing.price_per_unit,
          "base_price" => base_price,
          "seller_receives_price" => base_price,
          "tariff_rate_basis_points" => tariff_rate_basis_points,
          "tariff_amount" => tariff_amount,
          "total_buyer_cost" => total_buyer_cost,
          "total_price" => total_buyer_cost,
          "tariff_destination" => "money_sink",
          "logistic_operation_id" => operation.id,
          "diplomacy" => diplomacy_snapshot_for(
            trade_context: trade_context,
            base_price: base_price,
            tariff_amount: tariff_amount,
            total_buyer_cost: total_buyer_cost
          )
        }
      )

      operation
    end
  end

  private

  def validate_basic_rules!
    raise Error, "listing is required" if @listing.nil?
    raise Error, "buyer_city is required" if @buyer_city.nil?
    raise Error, "actor_user is required" if @actor_user.nil?
    raise Error, "amount must be greater than 0" unless @amount.positive?
    raise Error, "trucks_assigned must be greater than 0" unless @trucks_assigned.positive?
    raise Error, "eta_hours must be greater than 0" unless @eta_hours.positive?
  end

  def authorize!
    raise Error, "forbidden for buyer city" unless @buyer_city.user_id == @actor_user.id
  end

  def with_locked_records
    seller_city = @listing.seller_city

    records = [ @listing, seller_city, @buyer_city ].sort_by { |record| [ record.class.name, record.id ] }

    records[0].with_lock do
      records[1].with_lock do
        records[2].with_lock do
          locked_listing = records.find { |record| record.is_a?(MarketListing) }
          locked_seller_city = records.find { |record| record.is_a?(City) && record.id == seller_city.id }
          locked_buyer_city = records.find { |record| record.is_a?(City) && record.id == @buyer_city.id }

          yield(locked_listing, locked_seller_city, locked_buyer_city)
        end
      end
    end
  end

  def ensure_listing_purchasable!(listing)
    raise Error, "listing is cancelled" if listing.cancelled?
    raise Error, "listing is sold out" if listing.sold_out?
    raise Error, "listing is not purchasable" unless listing.purchasable?
  end

  def ensure_sufficient_listing_amount!(listing)
    return if listing.amount_available.to_i >= @amount

    raise Error, "insufficient listing amount available"
  end

  def ensure_sufficient_buyer_money!(buyer_city, total_buyer_cost)
    return if buyer_city.money.to_i >= total_buyer_cost

    raise Error, "insufficient money in buyer city"
  end

  def ensure_destination_logistic_capacity!(buyer_city, good_key)
    return if buyer_city.enough_logistic_capacity_for?(good_key, @amount)

    raise Error, "insufficient free logistic capacity in buyer city"
  end

  def ensure_seller_trucks!(seller_city)
    return if seller_city.enough_trucks_for?(@trucks_assigned)

    raise Error, "insufficient available trucks in seller city"
  end

  def resolve_trade_context!(listing)
    Diplomacy::ResolveTradeContext.call(
      importer_user: @actor_user,
      exporter_user: listing.seller_user
    )
  end

  def ensure_trade_allowed!(trade_context)
    return if trade_context.allowed?

    raise Error, "trade blocked by diplomacy: #{trade_context.blocked_reason}"
  end

  def calculate_base_price(listing)
    listing.price_per_unit.to_i * @amount
  end

  def calculate_tariff_amount(base_price:, tariff_rate_basis_points:)
    (base_price * tariff_rate_basis_points) / 10_000
  end

  def diplomacy_snapshot_for(trade_context:, base_price:, tariff_amount:, total_buyer_cost:)
    {
      "importer_user_id" => trade_context.importer_user.id,
      "exporter_user_id" => trade_context.exporter_user.id,
      "same_user" => trade_context.same_user?,
      "allowed" => trade_context.allowed?,
      "blocked_reason" => trade_context.blocked_reason,
      "importer_relation_state" => trade_context.importer_relation_state,
      "exporter_relation_state" => trade_context.exporter_relation_state,
      "importer_trade_policy" => trade_context.importer_trade_policy,
      "exporter_trade_policy" => trade_context.exporter_trade_policy,
      "importer_effective_trade_policy" => trade_context.importer_effective_trade_policy,
      "exporter_effective_trade_policy" => trade_context.exporter_effective_trade_policy,
      "tariff_rate_basis_points" => trade_context.applied_tariff_rate_basis_points,
      "base_price" => base_price,
      "tariff_amount" => tariff_amount,
      "total_buyer_cost" => total_buyer_cost,
      "tariff_destination" => "money_sink"
    }
  end

  def derive_next_status(listing, remaining_amount)
    if remaining_amount.zero?
      "sold_out"
    elsif remaining_amount < listing.amount_total.to_i
      "partially_filled"
    else
      "active"
    end
  end
end
