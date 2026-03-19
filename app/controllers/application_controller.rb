class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :set_uncategorized_count, if: :user_signed_in?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def set_uncategorized_count
    @uncategorized_count = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .uncategorized.count
  end
end
