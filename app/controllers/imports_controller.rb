class ImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account

  def index
    @imports = @account.imports.recent
  end

  def show
    @import = @account.imports.find(params[:id])
  end

  def new
    @import = @account.imports.build
  end

  def create
    @import = @account.imports.build(import_params)
    if @import.save
      redirect_to account_import_path(@account, @import), notice: "File uploaded. Processing..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def preview
    @import = @account.imports.find(params[:id])
  end

  def confirm
    @import = @account.imports.find(params[:id])
    redirect_to account_import_path(@account, @import), notice: "Import confirmed."
  end

  def rollback
    @import = @account.imports.find(params[:id])
    @import.rollback!
    redirect_to account_imports_path(@account), notice: "Import rolled back."
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:account_id])
  end

  def import_params
    params.require(:import).permit(:file_name, :file_type)
  end
end
