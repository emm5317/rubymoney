class Budget < ApplicationRecord
  belongs_to :category

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year, presence: true, numericality: { greater_than: 2000 }
  validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :category_id, uniqueness: { scope: [:month, :year], message: "already has a budget for this month" }

  scope :for_month, ->(month, year) { where(month: month, year: year) }
  scope :for_date, ->(date) { where(month: date.month, year: date.year) }

  def display_amount
    amount_cents / 100.0
  end
end
