class RecurringTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  enum :frequency, { monthly: 0, weekly: 1, biweekly: 2, quarterly: 3, annual: 4 }
  enum :status, { active: 0, paused: 1, cancelled: 2, missed: 3 }

  validates :title, :description_pattern, presence: true
  validates :average_amount_cents, presence: true
  validates :description_pattern, uniqueness: { scope: :account_id }

  scope :active_or_missed, -> { where(status: [:active, :missed]) }
  scope :not_dismissed, -> { where(user_dismissed: false) }
  scope :confirmed, -> { where(user_confirmed: true) }
  scope :auto_detected, -> { where(user_confirmed: false) }
  scope :upcoming, -> { where("next_expected_date <= ?", 30.days.from_now).order(:next_expected_date) }
  scope :by_amount, -> { order(Arel.sql("ABS(average_amount_cents) DESC")) }

  def monthly_cost_cents
    case frequency
    when "weekly" then average_amount_cents * 4
    when "biweekly" then average_amount_cents * 2
    when "monthly" then average_amount_cents
    when "quarterly" then (average_amount_cents / 3.0).round
    when "annual" then (average_amount_cents / 12.0).round
    else 0
    end
  end

  def amount_changed_significantly?
    return false unless last_amount_cents && average_amount_cents
    return false if average_amount_cents == 0

    (last_amount_cents - average_amount_cents).abs > (average_amount_cents.abs * 0.15)
  end

  def overdue?
    next_expected_date.present? && next_expected_date < Date.current
  end

  def formatted_average_amount
    "$#{'%.2f' % (average_amount_cents.abs / 100.0)}"
  end

  def formatted_last_amount
    return nil unless last_amount_cents

    "$#{'%.2f' % (last_amount_cents.abs / 100.0)}"
  end
end
