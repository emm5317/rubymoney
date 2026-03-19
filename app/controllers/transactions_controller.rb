require "csv"

class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    scope = filtered_scope

    sort_col = %w[date description amount_cents].include?(params[:sort]) ? params[:sort] : "date"
    sort_dir = params[:direction] == "asc" ? "asc" : "desc"
    @sort_column = sort_col
    @sort_direction = sort_dir
    @pagy, @transactions = pagy(scope.order("transactions.#{sort_col} #{sort_dir}"))
    @tags = Tag.sorted
  end

  def show
    @transaction = find_transaction
    unless @transaction.is_transfer?
      @transfer_candidates = TransferMatcher.new.find_candidates(@transaction, user: current_user)
    end
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
      .includes(:account, :tags)

    if params[:search].present?
      search_term = "%#{Transaction.sanitize_sql_like(params[:search])}%"
      scope = scope.where("transactions.description ILIKE :q OR transactions.normalized_desc ILIKE :q", q: search_term)
    end

    sort_col = %w[date description amount_cents].include?(params[:sort]) ? params[:sort] : "date"
    sort_dir = params[:direction] == "asc" ? "asc" : "desc"
    @sort_column = sort_col
    @sort_direction = sort_dir
    @pagy, @transactions = pagy(scope.order("transactions.#{sort_col} #{sort_dir}"))
    @tags = Tag.sorted
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

  def update_tags
    @transaction = find_transaction
    @transaction.tag_ids = Array(params[:tag_ids]).reject(&:blank?).map(&:to_i)
    respond_to do |format|
      format.html { redirect_back fallback_location: transactions_path, notice: "Tags updated." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "transaction_#{@transaction.id}_tags",
          partial: "transactions/tag_cell",
          locals: { transaction: @transaction, tags: Tag.sorted }
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
    pair = find_transaction_by_id(params[:transfer_pair_id])

    matcher = TransferMatcher.new
    matcher.link!(@transaction, pair)
    redirect_to @transaction, notice: "Transactions linked as transfer."
  end

  def unlink_transfer
    @transaction = find_transaction
    TransferMatcher.new.unlink!(@transaction)
    redirect_to @transaction, notice: "Transfer unlinked."
  end

  def export
    transactions = filtered_scope.order(date: :desc)

    csv_data = CSV.generate do |csv|
      csv << ["Date", "Description", "Amount", "Type", "Category", "Account", "Tags", "Memo", "Status"]
      transactions.find_each do |txn|
        csv << [
          txn.date.iso8601,
          txn.description,
          txn.amount,
          txn.transaction_type,
          txn.category&.name,
          txn.account.name,
          txn.tags.map(&:name).join("; "),
          txn.memo,
          txn.status
        ]
      end
    end

    filename = "transactions_#{Date.current.iso8601}.csv"
    send_data csv_data, filename: filename, type: "text/csv", disposition: "attachment"
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

  def find_transaction_by_id(id)
    user_transactions_scope.find(id)
  end

  def find_transactions_by_ids(ids)
    user_transactions_scope.where(id: ids)
  end

  def user_transactions_scope
    Transaction.joins(:account).where(accounts: { user_id: current_user.id })
  end

  def filtered_scope
    scope = Transaction.joins(:account)
      .where(accounts: { user_id: current_user.id })
      .includes(:account, :category, :tags)

    scope = scope.by_account(params[:account_id]) if params[:account_id].present?

    if params[:category_id] == "uncategorized"
      scope = scope.uncategorized
    elsif params[:category_id].present?
      scope = scope.by_category(params[:category_id])
    end

    scope = scope.where(transaction_type: params[:type]) if params[:type].present?
    scope = scope.where("transactions.date >= ?", params[:date_from]) if params[:date_from].present?
    scope = scope.where("transactions.date <= ?", params[:date_to]) if params[:date_to].present?

    if params[:search].present?
      search_term = "%#{Transaction.sanitize_sql_like(params[:search])}%"
      scope = scope.where("transactions.description ILIKE :q OR transactions.normalized_desc ILIKE :q", q: search_term)
    end

    scope
  end

  def transaction_params
    params.require(:transaction).permit(
      :account_id, :category_id, :date, :posted_date, :description,
      :amount, :amount_cents, :transaction_type, :status, :memo, :source_type,
      tag_ids: []
    )
  end
end
