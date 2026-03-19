class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @accounts = current_user.accounts
    @date = build_date

    user_transactions = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .non_transfer

    month_txns = user_transactions.for_month(@date)

    # Summary stats
    @total_income = month_txns.credits.sum(:amount_cents)
    @total_expenses = month_txns.debits.sum(:amount_cents)
    @net_change = @total_income - @total_expenses
    @uncategorized_count = month_txns.uncategorized.count

    # Category spending (debits grouped by category)
    @category_spending = month_txns.debits.group(:category_id).sum(:amount_cents)
    @categories_map = Category.where(id: @category_spending.keys).index_by(&:id)

    # Monthly trends (last 6 months) via groupdate
    range_start = (@date - 5.months).beginning_of_month
    trend_txns = user_transactions.for_date_range(range_start, @date.end_of_month)
    @monthly_income = trend_txns.credits.group_by_month(:date).sum(:amount_cents)
    @monthly_expenses = trend_txns.debits.group_by_month(:date).sum(:amount_cents)

    # Budget vs. actual (reuse @category_spending for actuals)
    @budgets = Budget.for_month(@date.month, @date.year).includes(:category)

    # Tag spending (only if tagged transactions exist)
    @tag_spending = month_txns.debits
      .joins(:tags)
      .group("tags.id", "tags.name", "tags.color")
      .sum(:amount_cents)

    # Net worth
    @net_worth = @accounts.sum(:current_balance_cents)

    # Net worth over time (from account_balances snapshots)
    @net_worth_history = AccountBalance
      .joins(account: :user)
      .where(accounts: { user_id: current_user.id })
      .where("account_balances.date >= ?", 6.months.ago.to_date)
      .group(:date)
      .order(:date)
      .sum(:balance_cents)

    # Income vs expenses area chart (last 6 months, same data as trends)
    @income_vs_expenses = { income: @monthly_income, expenses: @monthly_expenses }

    # Top merchants (by normalized_desc, top 10 by total spend this month)
    @top_merchants = month_txns.debits
      .where.not(normalized_desc: [nil, ""])
      .group(:normalized_desc)
      .order(Arel.sql("SUM(amount_cents) ASC"))
      .limit(10)
      .sum(:amount_cents)

    # Recurring charges (active or missed, top 8 by amount)
    @recurring_charges = RecurringTransaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .not_dismissed.active_or_missed
      .includes(:account, :category)
      .by_amount.limit(8)
    @total_monthly_recurring = @recurring_charges.sum(&:monthly_cost_cents)
    @missed_recurring_count = @recurring_charges.count(&:overdue?)

    # Recent transactions (latest 5 across all accounts)
    @recent_transactions = user_transactions
      .includes(:account, :category)
      .recent.limit(5)
  end

  def drilldown
    @date = build_date
    @category = Category.find_by(id: params[:category_id])

    @transactions = Transaction.joins(:account).includes(:account)
      .where(accounts: { user_id: current_user.id })
      .non_transfer.debits
      .for_month(@date)
      .where(category_id: params[:category_id])
      .order(date: :desc)
      .limit(20)

    render partial: "drilldown_results", locals: { transactions: @transactions, category: @category }
  end

  private

  def build_date
    month = (params[:month] || Date.current.month).to_i.clamp(1, 12)
    year = (params[:year] || Date.current.year).to_i.clamp(2000, 2099)
    Date.new(year, month, 1)
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end
