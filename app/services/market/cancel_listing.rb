class Market::CancelListing
  class Error < StandardError; end

  def initialize(listing:, actor_user:, now: Time.current)
    @listing = listing
    @actor_user = actor_user
    @now = now
  end

  def call
    validate_basic_rules!
    authorize!

    with_locked_listing_and_city do |locked_listing, locked_city|
      locked_listing.reload
      locked_city.reload

      raise Error, "listing is already cancelled" if locked_listing.cancelled?
      raise Error, "listing is already sold out" if locked_listing.sold_out?

      cancellable_amount = locked_listing.amount_available.to_i
      free_storage = locked_city.storage_free_for(locked_listing.good_key)

      amount_returned_now = [ cancellable_amount, free_storage ].min
      amount_return_pending = cancellable_amount - amount_returned_now

      if amount_returned_now.positive?
        locked_city.add_available_good!(locked_listing.good_key, amount_returned_now)
      end

      locked_listing.update!(
        amount_available: 0,
        amount_return_pending: locked_listing.amount_return_pending.to_i + amount_return_pending,
        status: "cancelled",
        cancelled_at: @now
      )

      LedgerEvent.create!(
        city: locked_city,
        actor_user: @actor_user,
        action_type: "market_listing_cancelled",
        delta: amount_returned_now.positive? ? { locked_listing.good_key => amount_returned_now } : {},
        meta: {
          "listing_id" => locked_listing.id,
          "seller_city_id" => locked_city.id,
          "good_key" => locked_listing.good_key,
          "amount_cancelled" => cancellable_amount,
          "amount_returned_now" => amount_returned_now,
          "amount_return_pending" => locked_listing.amount_return_pending
        }
      )

      locked_listing
    end
  end

  private

  def validate_basic_rules!
    raise Error, "listing is required" if @listing.nil?
    raise Error, "actor_user is required" if @actor_user.nil?
  end

  def authorize!
    raise Error, "forbidden for listing seller city" unless @listing.seller_user_id == @actor_user.id
  end

  def with_locked_listing_and_city
    city = @listing.seller_city

    first_record, second_record =
      [ @listing, city ].sort_by { |record| [ record.class.name, record.id ] }

    first_record.with_lock do
      second_record.with_lock do
        locked_listing = first_record.is_a?(MarketListing) ? first_record : second_record
        locked_city = first_record.is_a?(City) ? first_record : second_record

        yield(locked_listing, locked_city)
      end
    end
  end
end
