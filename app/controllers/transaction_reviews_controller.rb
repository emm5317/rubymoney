class TransactionReviewsController < ApplicationController
  before_action :authenticate_user!

  def show
    review = TransactionReviewService.new(user: current_user)
    @summary = review.summary
    @suggestions = review.suggestions
    @categories = Category.sorted
  end

  def apply
    result = TransactionReviewApplier.new(user: current_user, entries: suggestion_entries).call

    redirect_to transaction_review_path,
      notice: "#{result[:groups_updated]} groups reviewed, #{result[:transactions_categorized]} transactions categorized, #{result[:rules_created]} rules created."
  end

  private

  def suggestion_entries
    params.fetch(:suggestions, {}).values.map do |entry|
      entry.permit(:signature, :category_id, :rule_pattern, :apply, :create_rule)
    end
  end
end
