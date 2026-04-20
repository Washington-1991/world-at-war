class Market::CreateListing
  class Error < StandardError; end

  def initialize(seller_city:, actor_user:, good_key:, amount:, price_per_unit:)
    @seller_city = seller_city
    @actor_user = actor_user
    @good_key = GoodCatalog.normalize(good_key)
    @amount = amount.to_i
    @price_per_unit = price_per_unit.to_i
  end

  def call
    validate_basic_rules!
    authorize!

    @seller_city.with_lock do
      @seller_city.reload

      ensure_sufficient_stock!(@seller_city)

      @seller_city.remove_available_good!(@good_key, @amount)

      listing = MarketListing.create!(
        seller_user: @actor_user,
        seller_city: @seller_city,
        good_key: @good_key,
        amount_total: @amount,
        amount_available: @amount,
        amount_return_pending: 0,
        price_per_unit: @price_per_unit,
        currency_key: "money",
        status: "active"
      )

      LedgerEvent.create!(
        city: @seller_city,
        actor_user: @actor_user,
        action_type: "market_listing_created",
        delta: { @good_key => -@amount },
        meta: {
          "listing_id" => listing.id,
          "seller_city_id" => @seller_city.id,
          "good_key" => @good_key,
          "amount" => @amount,
          "price_per_unit" => @price_per_unit
        }
      )

      listing
    end
  end

  private

  def validate_basic_rules!
    raise Error, "seller_city is required" if @seller_city.nil?
    raise Error, "actor_user is required" if @actor_user.nil?
    raise Error, "good is invalid" unless GoodCatalog.include?(@good_key)
    raise Error, "amount must be greater than 0" unless @amount.positive?
    raise Error, "price_per_unit must be greater than 0" unless @price_per_unit.positive?
  end

  def authorize!
    raise Error, "forbidden for seller city" unless @seller_city.user_id == @actor_user.id
  end

  def ensure_sufficient_stock!(city)
    return if city.available_good_amount(@good_key) >= @amount

    raise Error, "insufficient stock in seller city"
  end
end
