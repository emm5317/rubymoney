class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .includes(:account, :category, :tags)
      .recent
    @pagy, @transactions = pagy(scope)
  end

  def show
    @transaction = find_transaction
  end

  def new
    @transaction = Transaction.new
    @accounts = current_user.accounts
  end

  def create
    @accounts = current_user.accounts
    @transaction = Transaction.new(transaction_params)
    if @transaction.save
      redirect_to transactions_path, notice: "Transaction created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @transaction = find_transaction
    @accounts = current_user.accounts
  end

  def update
    @transaction = find_transaction
    @accounts = current_user.accounts
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction = find_transaction
    @transaction.destroy
    redirect_to transactions_path, notice: "Transaction deleted."
  end

  def uncategorized
    scope = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .uncategorized
      .includes(:account)
      .recent
    @pagy, @transactions = pagy(scope)
  end

  def categorize
    @transaction = find_transaction
    @transaction.update!(category_id: params[:category_id].presence)
    respond_to do |format|
      format.html { redirect_back fallback_location: transactions_path, notice: "Transaction categorized." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "transaction_#{@transaction.id}_category",
          partial: "transactions/category_cell",
          locals: { transaction: @transaction.reload }
        )
      end
    end
  end

  def create_rule
    @transaction = find_transaction
    redirect_to new_rule_path(
      match_value: @transaction.normalized_desc || @transaction.description,
      match_field: :normalized_desc,
      match_type: :contains
    )
  end

  def link_transfer
    @transaction = find_transaction
    head :ok
  end

  def unlink_transfer
    @transaction = find_transaction
    head :ok
  end

  def bulk_categorize
    ids = params[:transaction_ids].to_s.split(",")
    transactions = find_transactions_by_ids(ids)
    count = transactions.update_all(category_id: params[:category_id])
    redirect_back fallback_location: transactions_path, notice: "#{count} transactions categorized."
  end

  def bulk_tag
    ids = params[:transaction_ids].to_s.split(",")
    transactions = find_transactions_by_ids(ids)
    tag_ids = Array(params[:tag_ids]).reject(&:blank?)

    count = 0
    transactions.find_each do |txn|
      tag_ids.each do |tag_id|
        txn.transaction_tags.find_or_create_by!(tag_id: tag_id)
        count += 1
      end
    end
    redirect_back fallback_location: transactions_path, notice: "Tags applied to #{transactions.count} transactions."
  end

  private

  def find_transaction
    user_transactions_scope.find(params[:id])
  end

  def find_transactions_by_ids(ids)
    user_transactions_scope.where(id: ids)
  end

  def user_transactions_scope
    Transaction.joins(:account).where(accounts: { user_id: current_user.id })
  end

  def transaction_params
    params.require(:transaction).permit(
      :account_id, :category_id, :date, :posted_date, :description,
      :amount, :amount_cents, :transaction_type, :status, :memo, :source_type,
      tag_ids: []
    )
  end
end
