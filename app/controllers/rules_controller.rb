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
      if @rule.apply_retroactive?
        count = Categorizer.new.categorize_batch(Transaction.uncategorized)
        redirect_to rules_path, notice: "Rule created. #{count} existing transactions auto-categorized."
      else
        redirect_to rules_path, notice: "Rule created."
      end
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

  def preview
    rule = Rule.new(rule_params)
    scope = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .includes(:account)
      .order(date: :desc)

    field_map = { "description" => "transactions.description", "normalized_desc" => "transactions.normalized_desc", "amount_field" => "transactions.amount_cents" }
    db_field = field_map[rule.match_field.to_s]

    case rule.match_type.to_s
    when "contains"
      term = "%#{Transaction.sanitize_sql_like(rule.match_value.to_s)}%"
      scope = scope.where("#{db_field} ILIKE ?", term)
    when "exact"
      scope = scope.where("#{db_field} ILIKE ?", rule.match_value.to_s)
    when "starts_with"
      term = "#{Transaction.sanitize_sql_like(rule.match_value.to_s)}%"
      scope = scope.where("#{db_field} ILIKE ?", term)
    when "gt"
      scope = scope.where("#{db_field} > ?", rule.match_value.to_i)
    when "lt"
      scope = scope.where("#{db_field} < ?", rule.match_value.to_i)
    when "between"
      scope = scope.where("#{db_field} BETWEEN ? AND ?", rule.match_value.to_i, rule.match_value_upper.to_i)
    when "regex"
      scope = scope.limit(500)
      @matching = scope.select { |txn| rule.matches?(txn) }.first(20)
    end

    @matching ||= scope.limit(20).to_a

    render inline: "<%= turbo_frame_tag 'rule-preview' do %><%= render partial: 'rules/preview_results', locals: { transactions: @matching } %><% end %>", layout: false
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
