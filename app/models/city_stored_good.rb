class CityStoredGood < ApplicationRecord
  belongs_to :city

  before_validation :normalize_good_key

  validates :good_key,
            presence: true,
            inclusion: { in: GoodCatalog.stored_good_keys },
            uniqueness: { scope: :city_id }

  validates :amount,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def good_kind
    GoodCatalog.kind_for(good_key)
  end

  def final_storage_target
    GoodCatalog.final_storage_target_for(good_key)
  end

  private

  def normalize_good_key
    self.good_key = GoodCatalog.normalize(good_key)
  end
end
