class AccountBalance < ApplicationRecord
  belongs_to :account

  enum :source, { calculated: 0, imported: 1, manual: 2 }

  validates :date, presence: true, uniqueness: { scope: :account_id }
  validates :balance_cents, presence: true

  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :chronological, -> { order(:date) }
  scope :recent_first, -> { order(date: :desc) }

  def display_balance
    balance_cents / 100.0
  end
end
