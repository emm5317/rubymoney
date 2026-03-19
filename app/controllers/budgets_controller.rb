class BudgetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @budgets = Budget.includes(:category).order(:category_id)

    # Compute actual spending for each budget's month/year
    @actuals_by_key = {}
    @budgets.group_by { |b| [b.month, b.year] }.each do |(month, year), _|
      date = Date.new(year, month, 1)
      actuals = Transaction.joins(:account)
        .where(accounts: { user_id: current_user.id })
        .non_transfer.debits
        .for_month(date)
        .group(:category_id).sum(:amount_cents)
      actuals.each { |cat_id, cents| @actuals_by_key[[cat_id, month, year]] = cents }
    end
  end

  def new
    @budget = Budget.new(month: Date.current.month, year: Date.current.year)
  end

  def create
    @budget = Budget.new(budget_params)
    if @budget.save
      redirect_to budgets_path, notice: "Budget created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @budget = Budget.find(params[:id])
  end

  def update
    @budget = Budget.find(params[:id])
    if @budget.update(budget_params)
      redirect_to budgets_path, notice: "Budget updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Budget.find(params[:id]).destroy
    redirect_to budgets_path, notice: "Budget deleted."
  end

  def copy_previous
    target_month = (params[:month] || Date.current.month).to_i.clamp(1, 12)
    target_year = (params[:year] || Date.current.year).to_i.clamp(2000, 2099)

    prev_date = Date.new(target_year, target_month, 1) - 1.month
    previous_budgets = Budget.for_month(prev_date.month, prev_date.year)

    if previous_budgets.empty?
      redirect_to budgets_path, alert: "No budgets found for #{prev_date.strftime('%B %Y')}."
      return
    end

    copied = 0
    previous_budgets.each do |budget|
      next if Budget.exists?(category_id: budget.category_id, month: target_month, year: target_year)

      Budget.create!(
        category_id: budget.category_id,
        month: target_month,
        year: target_year,
        amount_cents: budget.amount_cents,
        notes: budget.notes
      )
      copied += 1
    end

    if copied > 0
      redirect_to budgets_path, notice: "Copied #{copied} budget(s) from #{prev_date.strftime('%B %Y')}."
    else
      redirect_to budgets_path, notice: "All budgets from #{prev_date.strftime('%B %Y')} already exist for #{Date.new(target_year, target_month).strftime('%B %Y')}."
    end
  end

  private

  def budget_params
    params.require(:budget).permit(:category_id, :month, :year, :amount_cents, :notes)
  end
end
