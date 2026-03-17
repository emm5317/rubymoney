class Account < ApplicationRecord
  belongs_to :user

  has_many :transactions, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :import_profiles, dependent: :destroy
  has_many :account_balances, dependent: :destroy

  enum :account_type, { checking: 0, savings: 1, credit_card: 2, investment: 3 }
  enum :source_type, { manual: 0, csv: 1, ofx: 2, pdf: 3, plaid: 4 }

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :currency, presence: true

  scope :by_institution, ->(inst) { where(institution: inst) }

  def display_balance
    current_balance_cents / 100.0
  end
end
