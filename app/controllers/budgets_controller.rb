class BudgetsController < ApplicationController
  before_action :authenticate_user!

  def index
    @budgets = Budget.includes(:category).order(:category_id)
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

  private

  def budget_params
    params.require(:budget).permit(:category_id, :month, :year, :amount_cents, :notes)
  end
end
