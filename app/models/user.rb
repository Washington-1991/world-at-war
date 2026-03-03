class User < ApplicationRecord
  enum :role, { player: 0, admin: 1 }

  # Seguridad / integridad
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true, length: { in: 2..32 }
  validates :birth_date, presence: true
  validates :birth_country, presence: true, length: { in: 2..64 }

  validate :birth_date_not_in_future

  private

  def birth_date_not_in_future
    return if birth_date.blank?
    errors.add(:birth_date, "cannot be in the future") if birth_date > Date.current
  end
end
