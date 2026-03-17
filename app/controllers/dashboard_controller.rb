class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @accounts = current_user.accounts
  end
end
