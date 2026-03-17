class RulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_rule, only: [:show, :edit, :update, :destroy]

  def index
    @rules = Rule.includes(:category).by_priority
  end

  def show
  end

  def new
    @rule = Rule.new(
      match_value: params[:match_value],
      match_field: params[:match_field] || :description,
      match_type: params[:match_type] || :contains
    )
  end

  def create
    @rule = Rule.new(rule_params)
    if @rule.save
      redirect_to rules_path, notice: "Rule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @rule.update(rule_params)
      redirect_to rules_path, notice: "Rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to rules_path, notice: "Rule deleted."
  end

  private

  def set_rule
    @rule = Rule.find(params[:id])
  end

  def rule_params
    params.require(:rule).permit(
      :category_id, :match_field, :match_type, :match_value,
      :match_value_upper, :priority, :enabled, :apply_retroactive
    )
  end
end
