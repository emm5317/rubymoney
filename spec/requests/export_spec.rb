require "rails_helper"

RSpec.describe "CSV Export", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, name: "Checking") }
  let(:category) { create(:category, :groceries) }

  before { sign_in user }

  describe "GET /transactions/export.csv" do
    let!(:txn) do
      create(:transaction, account: account, category: category,
             description: "WHOLE FOODS", amount_cents: -5000,
             transaction_type: :debit, date: Date.new(2026, 3, 15),
             status: :cleared, memo: "Weekly groceries")
    end

    it "returns a CSV file" do
      get export_transactions_path(format: :csv)
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include(".csv")
    end

    it "includes correct headers" do
      get export_transactions_path(format: :csv)
      lines = response.body.lines
      expect(lines.first).to include("Date", "Description", "Amount", "Type", "Category", "Account")
    end

    it "includes transaction data" do
      get export_transactions_path(format: :csv)
      expect(response.body).to include("WHOLE FOODS")
      expect(response.body).to include("Groceries")
      expect(response.body).to include("Checking")
      expect(response.body).to include("Weekly groceries")
    end

    it "respects account filter" do
      other_account = create(:account, user: user, name: "Savings")
      create(:transaction, account: other_account, description: "OTHER TXN", date: Date.current)

      get export_transactions_path(format: :csv, account_id: account.id)
      expect(response.body).to include("WHOLE FOODS")
      expect(response.body).not_to include("OTHER TXN")
    end

    it "respects category filter" do
      create(:transaction, account: account, category: nil, description: "UNCATEGORIZED TXN", date: Date.current)

      get export_transactions_path(format: :csv, category_id: category.id)
      expect(response.body).to include("WHOLE FOODS")
      expect(response.body).not_to include("UNCATEGORIZED TXN")
    end

    it "respects date range filter" do
      create(:transaction, account: account, description: "OLD TXN", date: Date.new(2025, 1, 1))

      get export_transactions_path(format: :csv, date_from: "2026-03-01", date_to: "2026-03-31")
      expect(response.body).to include("WHOLE FOODS")
      expect(response.body).not_to include("OLD TXN")
    end

    it "includes tags" do
      tag = create(:tag, name: "tax-deductible")
      txn.tags << tag

      get export_transactions_path(format: :csv)
      expect(response.body).to include("tax-deductible")
    end

    it "requires authentication" do
      sign_out user
      get export_transactions_path(format: :csv)
      # Devise redirects unauthenticated users (may respond with 401 for non-HTML formats)
      expect(response.status).to be_in([302, 401])
    end
  end
end
