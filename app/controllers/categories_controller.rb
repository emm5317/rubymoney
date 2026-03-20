class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.sorted
  end

  def show
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Category deleted."
  end

  def merge
    source = Category.find(params[:source_id])
    target = Category.find(params[:target_id])

    if source.id == target.id
      redirect_to categories_path, alert: "Cannot merge a category into itself."
      return
    end

    ActiveRecord::Base.transaction do
      source.transactions.update_all(category_id: target.id)
      source.rules.update_all(category_id: target.id)

      source.budgets.find_each do |source_budget|
        existing = target.budgets.find_by(month: source_budget.month, year: source_budget.year)
        if existing
          existing.update!(amount_cents: existing.amount_cents + source_budget.amount_cents)
          source_budget.destroy!
        else
          source_budget.update!(category_id: target.id)
        end
      end

      source.children.update_all(parent_id: target.id)
      source.destroy!
    end

    redirect_to categories_path, notice: "\"#{source.name}\" merged into \"#{target.name}\"."
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :parent_id, :color, :icon, :position)
  end
end
