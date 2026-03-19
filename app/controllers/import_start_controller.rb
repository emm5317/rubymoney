class ImportStartController < ApplicationController
  before_action :authenticate_user!

  def index
    accounts = current_user.accounts
    if accounts.count == 1
      redirect_to new_account_import_path(accounts.first)
    else
      @accounts = accounts
    end
  end
end
