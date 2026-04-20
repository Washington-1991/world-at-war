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
      ensure_sufficient_buyer_money!(locked_buyer_city, locked_listing)
      ensure_destination_logistic_capacity!(locked_buyer_city, locked_listing.good_key)
      ensure_seller_trucks!(locked_seller_city)

      total_price = calculate_total_price(locked_listing)

      locked_buyer_city.update!(money: locked_buyer_city.money.to_i - total_price)

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
        market_total_price: total_price,
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
        delta: { "money" => -total_price },
        meta: {
          "listing_id" => locked_listing.id,
          "buyer_city_id" => locked_buyer_city.id,
          "seller_city_id" => locked_seller_city.id,
          "good_key" => locked_listing.good_key,
          "amount" => @amount,
          "price_per_unit" => locked_listing.price_per_unit,
          "total_price" => total_price,
          "logistic_operation_id" => operation.id
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

  def ensure_sufficient_buyer_money!(buyer_city, listing)
    return if buyer_city.money.to_i >= calculate_total_price(listing)

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

  def calculate_total_price(listing)
    listing.price_per_unit.to_i * @amount
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
