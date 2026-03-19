class RecurringTransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recurring_transaction, only: [:show, :edit, :update, :destroy, :confirm, :dismiss, :reactivate]

  def index
    scope = user_recurring_scope.not_dismissed.includes(:account, :category)

    @active = scope.where(status: :active).by_amount
    @missed = scope.where(status: :missed).by_amount
    @paused_or_cancelled = scope.where(status: [:paused, :cancelled]).by_amount
    @dismissed = user_recurring_scope.where(user_dismissed: true).includes(:account, :category).by_amount

    @total_monthly = (@active + @missed).sum(&:monthly_cost_cents)

    # For manual marking: show top transaction groups not yet tracked
    @candidate_groups = candidate_description_groups
  end

  def show
    @matched_transactions = Transaction.where(account_id: @recurring_transaction.account_id)
      .where(normalized_desc: @recurring_transaction.description_pattern)
      .where(is_transfer: false)
      .order(date: :desc)
      .limit(20)
  end

  def edit
    @categories = Category.sorted
  end

  def update
    if @recurring_transaction.update(recurring_transaction_params)
      redirect_to @recurring_transaction, notice: "Recurring transaction updated."
    else
      @categories = Category.sorted
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_transaction.destroy
    redirect_to recurring_transactions_path, notice: "Recurring transaction deleted."
  end

  def confirm
    @recurring_transaction.update!(user_confirmed: true, status: :active)
    redirect_to recurring_transactions_path, notice: "#{@recurring_transaction.title} confirmed as recurring."
  end

  def dismiss
    @recurring_transaction.update!(user_dismissed: true)
    redirect_to recurring_transactions_path, notice: "#{@recurring_transaction.title} dismissed."
  end

  def reactivate
    @recurring_transaction.update!(user_dismissed: false, status: :active)
    redirect_to recurring_transactions_path, notice: "#{@recurring_transaction.title} reactivated."
  end

  def detect_now
    results = RecurringDetector.new(current_user).detect_all
    redirect_to recurring_transactions_path,
      notice: "Detection complete: #{results[:created]} new, #{results[:updated]} updated, #{results[:missed]} missed."
  end

  def mark_recurring
    account = current_user.accounts.find(params[:account_id])
    normalized_desc = params[:description_pattern]

    transactions = Transaction.where(account: account, normalized_desc: normalized_desc)
      .where(is_transfer: false)
      .order(:date)

    if transactions.count < 2
      redirect_to recurring_transactions_path, alert: "Need at least 2 transactions to mark as recurring."
      return
    end

    amounts = transactions.map(&:amount_cents)
    dates = transactions.map(&:date).sort
    intervals = dates.each_cons(2).map { |a, b| (b - a).to_i }
    median_interval = intervals.sort[intervals.size / 2] || 30

    recurring = RecurringTransaction.find_or_initialize_by(
      account: account,
      description_pattern: normalized_desc
    )

    recurring.assign_attributes(
      title: normalized_desc.titleize.truncate(50),
      average_amount_cents: (amounts.sum.to_f / amounts.size).round,
      last_amount_cents: amounts.last,
      last_seen_date: dates.last,
      next_expected_date: dates.last + median_interval.days,
      occurrence_count: transactions.count,
      average_interval_days: median_interval,
      frequency: detect_frequency(median_interval),
      confidence: 1.0,
      user_confirmed: true,
      user_dismissed: false,
      status: :active,
      category_id: transactions.last.category_id
    )

    if recurring.save
      redirect_to recurring_transactions_path, notice: "#{recurring.title} marked as recurring."
    else
      redirect_to recurring_transactions_path, alert: "Could not create recurring transaction."
    end
  end

  private

  def set_recurring_transaction
    @recurring_transaction = user_recurring_scope.find(params[:id])
  end

  def user_recurring_scope
    RecurringTransaction.joins(:account).where(accounts: { user_id: current_user.id })
  end

  def recurring_transaction_params
    params.require(:recurring_transaction).permit(:title, :frequency, :category_id, :status)
  end

  def detect_frequency(median_interval)
    RecurringDetector::FREQUENCY_RANGES.find { |_, range| median_interval.between?(range[:min], range[:max]) }&.first || :monthly
  end

  def candidate_description_groups
    existing_patterns = user_recurring_scope.pluck(:description_pattern)

    scope = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .where.not(normalized_desc: [nil, ""])
      .where(is_transfer: false)
      .where("transactions.date >= ?", 12.months.ago)

    scope = scope.where.not(normalized_desc: existing_patterns) if existing_patterns.any?

    scope.group(:account_id, :normalized_desc)
      .having("COUNT(*) >= 3")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(10)
      .pluck(:account_id, :normalized_desc, Arel.sql("COUNT(*)"), Arel.sql("AVG(amount_cents)"))
      .map do |account_id, desc, count, avg_amount|
        {
          account_id: account_id,
          description_pattern: desc,
          count: count,
          average_amount_cents: avg_amount.to_i
        }
      end
  end
end
