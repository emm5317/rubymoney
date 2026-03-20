class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @accounts = current_user.accounts
    @date = build_date

    user_transactions = dashboard_transactions_scope
    reporting_transactions = spending_transactions_scope(user_transactions)
    month_txns = reporting_transactions.for_month(@date)

    # Summary stats
    @total_income = month_txns.credits.sum(:amount_cents)
    @total_expenses = month_txns.debits.sum("ABS(amount_cents)")
    @net_change = @total_income - @total_expenses
    @uncategorized_count = user_transactions.for_month(@date).uncategorized.count

    # Category spending (debits grouped by category)
    @category_spending = month_txns.debits.group(:category_id).sum("ABS(amount_cents)")
    @categories_map = Category.where(id: @category_spending.keys).index_by(&:id)

    # Monthly trends (last 6 months) via groupdate
    range_start = (@date - 5.months).beginning_of_month
    trend_txns = reporting_transactions.for_date_range(range_start, @date.end_of_month)
    @monthly_income = trend_txns.credits.group_by_month(:date).sum(:amount_cents)
    @monthly_expenses = trend_txns.debits.group_by_month(:date).sum("ABS(amount_cents)")

    # Budget vs. actual (reuse @category_spending for actuals)
    @budgets = Budget.for_month(@date.month, @date.year).includes(:category)

    # Tag spending (only if tagged transactions exist)
    @tag_spending = month_txns.debits
      .joins(:tags)
      .group("tags.id", "tags.name", "tags.color")
      .sum("ABS(amount_cents)")

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
      .sum("ABS(amount_cents)")
      .sort_by { |_, cents| -cents }
      .first(10)
      .to_h

    # Recurring charges (active or missed, top 8 by amount)
    @recurring_charges = RecurringTransaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .not_dismissed.active_or_missed
      .includes(:account, :category)
      .by_amount.limit(8)
    @total_monthly_recurring = @recurring_charges.sum(&:monthly_cost_cents)
    @missed_recurring_count = @recurring_charges.count(&:overdue?)

    # Recent transactions (latest 5 across all accounts)
    @recent_transactions = dashboard_transactions_scope
      .includes(:account, :category)
      .recent.limit(5)
  end

  def drilldown
    @date = build_date
    scope = spending_transactions_scope(dashboard_transactions_scope)
      .includes(:account)
      .debits
      .for_month(@date)
      .order(date: :desc)
      .limit(20)

    if params[:category_id] == "uncategorized"
      @category = nil
      @drilldown_title = "Uncategorized"
      @transactions = scope.where(category_id: nil)
    elsif params[:category_id].present?
      @category = Category.find_by(id: params[:category_id])
      @drilldown_title = @category&.name || "Category"
      @transactions = scope.where(category_id: params[:category_id])
    else
      @category = nil
      @drilldown_title = "Transactions"
      @transactions = Transaction.none
    end

    render partial: "drilldown_results", locals: {
      transactions: @transactions,
      category: @category,
      title: @drilldown_title
    }
  end

  private

  def dashboard_transactions_scope
    Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .non_transfer
  end

  def spending_transactions_scope(scope)
    transfers_category = Category.find_by(name: "Transfers")
    return scope unless transfers_category

    scope.where.not(category_id: transfers_category.id)
  end

  def build_date
    default_date = if params[:month].present? || params[:year].present?
      Date.current
    else
      dashboard_transactions_scope.maximum(:date) || Date.current
    end

    month = (params[:month] || default_date.month).to_i.clamp(1, 12)
    year = (params[:year] || default_date.year).to_i.clamp(2000, 2099)
    Date.new(year, month, 1)
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end
