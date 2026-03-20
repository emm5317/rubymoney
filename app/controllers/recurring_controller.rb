class RecurringController < ApplicationController
  before_action :authenticate_user!

  def index
    RecurringDetector.new(current_user).detect_all

    @recurring = RecurringTransaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .not_dismissed
      .order(average_amount_cents: :asc)
      .map do |item|
        {
          description: item.title,
          avg_amount_cents: item.average_amount_cents,
          frequency: item.frequency,
          last_date: item.last_seen_date,
          count: item.occurrence_count,
          transaction_type: item.average_amount_cents.to_i.negative? ? "debit" : "credit"
        }
      end
  end
end
