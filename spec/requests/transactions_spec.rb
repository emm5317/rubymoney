require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, :groceries) }

  before { sign_in user }

  describe "GET /transactions" do
    it "loads successfully with no transactions" do
      get transactions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No transactions yet")
    end

    it "lists transactions" do
      txn = create(:transaction, account: account, description: "WHOLE FOODS", date: Date.current)
      get transactions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("WHOLE FOODS")
    end

    it "filters by account" do
      txn = create(:transaction, account: account, description: "My Account Txn")
      other_account = create(:account, user: user, name: "Other")
      create(:transaction, account: other_account, description: "Other Account Txn")

      get transactions_path(account_id: account.id)
      expect(response.body).to include("My Account Txn")
      expect(response.body).not_to include("Other Account Txn")
    end

    it "filters by category" do
      create(:transaction, account: account, category: category, description: "Categorized")
      create(:transaction, account: account, category: nil, description: "Uncategorized One")

      get transactions_path(category_id: category.id)
      expect(response.body).to include("Categorized")
      expect(response.body).not_to include("Uncategorized One")
    end

    it "filters by uncategorized" do
      create(:transaction, account: account, category: category, description: "Categorized")
      create(:transaction, account: account, category: nil, description: "Uncategorized One")

      get transactions_path(category_id: "uncategorized")
      expect(response.body).to include("Uncategorized One")
      expect(response.body).not_to include("Categorized")
    end

    it "filters by transaction type" do
      create(:transaction, account: account, transaction_type: :debit, description: "Debit Txn")
      create(:transaction, account: account, transaction_type: :credit, description: "Credit Txn")

      get transactions_path(type: "debit")
      expect(response.body).to include("Debit Txn")
      expect(response.body).not_to include("Credit Txn")
    end

    it "filters by date range" do
      create(:transaction, account: account, date: Date.new(2026, 1, 15), description: "Jan Txn")
      create(:transaction, account: account, date: Date.new(2026, 3, 15), description: "Mar Txn")

      get transactions_path(date_from: "2026-03-01", date_to: "2026-03-31")
      expect(response.body).to include("Mar Txn")
      expect(response.body).not_to include("Jan Txn")
    end

    it "shows empty state when filters match nothing" do
      create(:transaction, account: account, transaction_type: :debit, description: "Debit Only")

      get transactions_path(type: "credit")
      expect(response.body).to include("No transactions match your filters")
    end
  end

  describe "GET /transactions/:id" do
    it "shows transaction details" do
      txn = create(:transaction, account: account, description: "STARBUCKS #1234", date: Date.current, category: category)
      get transaction_path(txn)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("STARBUCKS #1234")
      expect(response.body).to include("Groceries")
    end

    it "shows transfer candidates for non-transfer transactions" do
      savings = create(:account, user: user, name: "Savings")
      txn = create(:transaction, account: account, amount_cents: -50000, date: Date.current, description: "Transfer out")
      candidate = create(:transaction, account: savings, amount_cents: 50000, date: Date.current, description: "Transfer in")

      get transaction_path(txn)
      expect(response.body).to include("Transfer in")
    end

    it "cannot access another user's transaction" do
      other_user = create(:user)
      other_account = create(:account, user: other_user)
      other_txn = create(:transaction, account: other_account)

      get transaction_path(other_txn)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /transactions/new" do
    it "renders the form" do
      get new_transaction_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("form")
    end
  end

  describe "POST /transactions" do
    it "creates a valid transaction" do
      expect {
        post transactions_path, params: {
          transaction: {
            account_id: account.id,
            date: Date.current,
            description: "Test Purchase",
            amount: "25.50",
            transaction_type: "debit"
          }
        }
      }.to change(Transaction, :count).by(1)

      expect(response).to redirect_to(transactions_path)
      follow_redirect!
      expect(response.body).to include("Transaction created")
    end

    it "rejects invalid transaction (missing date)" do
      post transactions_path, params: {
        transaction: {
          account_id: account.id,
          description: "No Date",
          amount: "10.00",
          transaction_type: "debit"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects zero amount" do
      post transactions_path, params: {
        transaction: {
          account_id: account.id,
          date: Date.current,
          description: "Zero",
          amount: "0",
          transaction_type: "debit"
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /transactions/:id" do
    let!(:txn) { create(:transaction, account: account, description: "Original") }

    it "updates the transaction" do
      patch transaction_path(txn), params: {
        transaction: { description: "Updated" }
      }
      expect(response).to redirect_to(transaction_path(txn))
      expect(txn.reload.description).to eq("Updated")
    end

    it "rejects invalid update" do
      patch transaction_path(txn), params: {
        transaction: { description: "" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /transactions/:id" do
    let!(:txn) { create(:transaction, account: account) }

    it "deletes and redirects" do
      expect {
        delete transaction_path(txn)
      }.to change(Transaction, :count).by(-1)
      expect(response).to redirect_to(transactions_path)
    end
  end

  describe "GET /transactions/uncategorized" do
    it "shows only uncategorized transactions" do
      create(:transaction, account: account, category: category, description: "Has Category")
      create(:transaction, account: account, category: nil, description: "No Category")

      get uncategorized_transactions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No Category")
      expect(response.body).not_to include("Has Category")
    end

    it "shows success message when all categorized" do
      get uncategorized_transactions_path
      expect(response.body).to include("All transactions are categorized")
    end
  end

  describe "PATCH /transactions/:id/categorize" do
    let!(:txn) { create(:transaction, account: account, category: nil) }

    it "sets the category" do
      patch categorize_transaction_path(txn), params: { category_id: category.id }
      expect(txn.reload.category).to eq(category)
    end

    it "responds to turbo_stream" do
      patch categorize_transaction_path(txn), params: { category_id: category.id },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-stream")
    end

    it "clears category when blank" do
      txn.update!(category: category)
      patch categorize_transaction_path(txn), params: { category_id: "" }
      expect(txn.reload.category_id).to be_nil
    end
  end

  describe "PATCH /transactions/:id/update_tags" do
    let!(:txn) { create(:transaction, account: account) }
    let!(:tag1) { create(:tag, name: "tax") }
    let!(:tag2) { create(:tag, name: "business") }

    it "sets tags on a transaction" do
      patch update_tags_transaction_path(txn), params: { tag_ids: [tag1.id, tag2.id] }
      expect(txn.reload.tags).to contain_exactly(tag1, tag2)
    end

    it "replaces existing tags" do
      txn.tags << tag1
      patch update_tags_transaction_path(txn), params: { tag_ids: [tag2.id] }
      expect(txn.reload.tags).to contain_exactly(tag2)
    end

    it "clears all tags when none sent" do
      txn.tags << tag1
      patch update_tags_transaction_path(txn), params: { tag_ids: [""] }
      expect(txn.reload.tags).to be_empty
    end

    it "responds to turbo_stream" do
      patch update_tags_transaction_path(txn), params: { tag_ids: [tag1.id] },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-stream")
    end
  end

  describe "POST /transactions/:id/create_rule" do
    let!(:txn) { create(:transaction, account: account, description: "WHOLE FOODS #1234") }

    it "redirects to new rule with pre-filled params" do
      post create_rule_transaction_path(txn)
      expect(response).to redirect_to(new_rule_path(
        match_value: txn.normalized_desc || txn.description,
        match_field: "normalized_desc",
        match_type: "contains"
      ))
    end
  end

  describe "POST /transactions/:id/link_transfer" do
    let(:savings) { create(:account, user: user, name: "Savings") }
    let!(:debit) { create(:transaction, account: account, amount_cents: -50000, date: Date.current) }
    let!(:credit) { create(:transaction, account: savings, amount_cents: 50000, date: Date.current) }

    it "links two transactions as a transfer pair" do
      post link_transfer_transaction_path(debit), params: { transfer_pair_id: credit.id }
      expect(debit.reload.is_transfer).to be true
      expect(credit.reload.is_transfer).to be true
      expect(debit.transfer_pair_id).to eq(credit.id)
    end
  end

  describe "DELETE /transactions/:id/unlink_transfer" do
    let(:savings) { create(:account, user: user, name: "Savings") }
    let!(:debit) { create(:transaction, account: account, amount_cents: -50000, date: Date.current) }
    let!(:credit) { create(:transaction, account: savings, amount_cents: 50000, date: Date.current) }

    before { TransferMatcher.new.link!(debit, credit) }

    it "unlinks the transfer pair" do
      delete unlink_transfer_transaction_path(debit)
      expect(debit.reload.is_transfer).to be false
      expect(credit.reload.is_transfer).to be false
      expect(debit.transfer_pair_id).to be_nil
    end
  end

  describe "POST /transactions/bulk_categorize" do
    let!(:txn1) { create(:transaction, account: account, category: nil) }
    let!(:txn2) { create(:transaction, account: account, category: nil) }

    it "categorizes multiple transactions" do
      post bulk_categorize_transactions_path, params: {
        transaction_ids: "#{txn1.id},#{txn2.id}",
        category_id: category.id
      }
      expect(txn1.reload.category).to eq(category)
      expect(txn2.reload.category).to eq(category)
      expect(response).to redirect_to(transactions_path)
    end
  end

  describe "POST /transactions/bulk_tag" do
    let!(:txn1) { create(:transaction, account: account) }
    let!(:txn2) { create(:transaction, account: account) }
    let!(:tag) { create(:tag, name: "bulk-tag") }

    it "applies tags to multiple transactions" do
      post bulk_tag_transactions_path, params: {
        transaction_ids: "#{txn1.id},#{txn2.id}",
        tag_ids: [tag.id]
      }
      expect(txn1.reload.tags).to include(tag)
      expect(txn2.reload.tags).to include(tag)
    end
  end

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users" do
      get transactions_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
