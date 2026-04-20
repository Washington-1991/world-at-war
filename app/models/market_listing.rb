class MarketListing < ApplicationRecord
  STATUSES = %w[
    active
    partially_filled
    sold_out
    cancelled
  ].freeze

  CURRENCY_KEYS = %w[money].freeze

  belongs_to :seller_user, class_name: "User"
  belongs_to :seller_city, class_name: "City"

  validates :good_key, presence: true
  validates :amount_total, presence: true,
                           numericality: { only_integer: true, greater_than: 0 }
  validates :amount_available, presence: true,
                               numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :amount_return_pending, presence: true,
                                    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_per_unit, presence: true,
                             numericality: { only_integer: true, greater_than: 0 }
  validates :currency_key, presence: true, inclusion: { in: CURRENCY_KEYS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  validate :good_key_must_exist_in_catalog
  validate :amount_available_cannot_exceed_total
  validate :available_plus_return_pending_cannot_exceed_total

  scope :active_market, -> { where(status: %w[active partially_filled]) }
  scope :for_good, ->(good_key) { where(good_key: good_key) }

  def active?
    status == "active"
  end

  def partially_filled?
    status == "partially_filled"
  end

  def sold_out?
    status == "sold_out"
  end

  def cancelled?
    status == "cancelled"
  end

  def purchasable?
    active? || partially_filled?
  end

  def sold_amount
    amount_total - amount_available - amount_return_pending
  end

  private

  def good_key_must_exist_in_catalog
    return if good_key.blank?
    return if GoodCatalog.include?(good_key)

    errors.add(:good_key, "is not included in GoodCatalog")
  end

  def amount_available_cannot_exceed_total
    return if amount_total.blank? || amount_available.blank?
    return if amount_available <= amount_total

    errors.add(:amount_available, "cannot exceed amount_total")
  end

  def available_plus_return_pending_cannot_exceed_total
    return if amount_total.blank? || amount_available.blank? || amount_return_pending.blank?
    return if (amount_available + amount_return_pending) <= amount_total

    errors.add(:base, "amount_available plus amount_return_pending cannot exceed amount_total")
  end
end
