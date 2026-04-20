class Market::WithdrawPendingReturn
  class Error < StandardError; end

  def initialize(listing:, actor_user:)
    @listing = listing
    @actor_user = actor_user
  end

  def call
    validate!

    with_locks do |listing, city|
      listing.reload
      city.reload

      pending = listing.amount_return_pending.to_i
      raise Error, "no pending returns to withdraw" if pending <= 0

      free_storage = city.storage_free_for(listing.good_key)
      withdraw_amount = [ pending, free_storage ].min

      raise Error, "no storage capacity available" if withdraw_amount <= 0

      city.send(:increase_final_stored_good!, listing.good_key, withdraw_amount)

      listing.update!(
        amount_return_pending: pending - withdraw_amount
      )

      create_ledger_event!(city, listing, withdraw_amount)

      listing
    end
  end

  private

  def validate!
    raise Error, "listing is required" if @listing.nil?
    raise Error, "actor_user is required" if @actor_user.nil?

    unless @listing.seller_user_id == @actor_user.id
      raise Error, "forbidden for listing seller city"
    end
  end

  def with_locks
    city = @listing.seller_city

    @listing.with_lock do
      city.with_lock do
        yield(@listing, city)
      end
    end
  end

  def create_ledger_event!(city, listing, amount)
    LedgerEvent.create!(
      city: city,
      actor_user: @actor_user,
      action_type: "market_return_withdrawn",
      delta: {
        listing.good_key => amount
      },
      meta: {
        listing_id: listing.id,
        amount: amount
      }
    )
  end
end
