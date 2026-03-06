class User < ApplicationRecord
  enum :role, { player: 0, admin: 1 }

  # Relaciones
  has_many :cities, dependent: :destroy
  has_many :ledger_events, foreign_key: :actor_user_id, dependent: :nullify, inverse_of: :actor_user

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
