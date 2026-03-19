require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /dashboard" do
    it "loads successfully with no accounts" do
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Welcome to Finance Reconciler")
    end

    context "with accounts" do
      before { account }

      it "loads successfully" do
        get dashboard_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Dashboard")
        expect(response.body).to include(account.name)
      end

      it "shows summary stats with zero values when no transactions" do
        get dashboard_path
        expect(response.body).to include("Income")
        expect(response.body).to include("Expenses")
        expect(response.body).to include("Net Change")
        expect(response.body).to include("$0.00")
      end
    end

    context "with transactions" do
      let!(:groceries) { create(:category, :groceries) }
      let!(:debit_txn) do
        create(:transaction, account: account, transaction_type: :debit,
               amount_cents: 5000, date: Date.current, category: groceries)
      end
      let!(:credit_txn) do
        create(:transaction, :credit, account: account,
               amount_cents: 300_000, date: Date.current)
      end

      it "displays correct income and expense totals" do
        get dashboard_path
        expect(response.body).to include("$3,000.00") # income
        expect(response.body).to include("$50.00")    # expenses
      end

      it "excludes transfers from totals" do
        create(:transaction, :transfer, account: account,
               amount_cents: 100_000, transaction_type: :credit, date: Date.current)
        get dashboard_path
        # Income should still be $3,000.00, not $4,000.00
        expect(response.body).to include("$3,000.00")
      end

      it "shows uncategorized count" do
        create(:transaction, :uncategorized, account: account,
               amount_cents: 1000, date: Date.current)
        get dashboard_path
        expect(response.body).to include("Uncategorized")
      end

      it "shows category spending chart" do
        get dashboard_path
        expect(response.body).to include("Spending by Category")
        expect(response.body).to include("Groceries")
      end

      it "excludes transactions from other users' accounts" do
        other_account = create(:account, user: create(:user))
        create(:transaction, account: other_account, transaction_type: :debit,
               amount_cents: 999_999, date: Date.current)
        get dashboard_path
        expect(response.body).not_to include("$9,999.99")
      end
    end

    context "period navigation" do
      before { account } # ensure account exists so dashboard renders full layout

      it "defaults to current month" do
        get dashboard_path
        expect(response.body).to include(Date.current.strftime("%B %Y"))
      end

      it "navigates to a specific month" do
        get dashboard_path(month: 1, year: 2025)
        expect(response.body).to include("January 2025")
      end

      it "handles invalid month param gracefully" do
        account # ensure account exists
        get dashboard_path(month: 13, year: 2025)
        expect(response).to have_http_status(:ok)
      end

      it "shows transactions only for the selected month" do
        create(:transaction, account: account, transaction_type: :debit,
               amount_cents: 5000, date: Date.new(2025, 1, 15))
        create(:transaction, account: account, transaction_type: :debit,
               amount_cents: 7000, date: Date.new(2025, 2, 15))

        get dashboard_path(month: 1, year: 2025)
        expect(response.body).to include("$50.00")
        expect(response.body).not_to include("$70.00")
      end
    end

    context "budget vs actual" do
      let!(:groceries) { create(:category, :groceries) }

      it "shows budget progress when budgets exist" do
        create(:budget, category: groceries, month: Date.current.month,
               year: Date.current.year, amount_cents: 30_000)
        create(:transaction, account: account, category: groceries,
               transaction_type: :debit, amount_cents: 15_000, date: Date.current)

        get dashboard_path
        expect(response.body).to include("Budget vs. Actual")
        expect(response.body).to include("$150.00")  # spent
        expect(response.body).to include("$300.00")  # budgeted
      end

      it "does not show budget section when no budgets" do
        get dashboard_path
        expect(response.body).not_to include("Budget vs. Actual")
      end
    end
  end

  describe "new Phase 4 features" do
    context "accounts overview and net worth" do
      it "shows net worth total" do
        account.update!(current_balance_cents: 250_000)
        create(:account, user: user, name: "Savings", current_balance_cents: 500_000)
        get dashboard_path
        expect(response.body).to include("Net Worth")
        expect(response.body).to include("$7,500.00")
      end

      it "shows account cards" do
        account # create account
        get dashboard_path
        expect(response.body).to include(account.name)
        expect(response.body).to include(account.institution)
      end
    end

    context "top merchants" do
      it "shows top merchants when transactions exist" do
        create(:transaction, account: account, transaction_type: :debit,
               amount_cents: 5000, date: Date.current, description: "STARBUCKS #1234")
        get dashboard_path
        expect(response.body).to include("Top Merchants")
      end
    end

    context "income vs expenses chart" do
      it "shows income vs expenses section" do
        create(:transaction, account: account, transaction_type: :debit,
               amount_cents: 5000, date: Date.current)
        get dashboard_path
        expect(response.body).to include("Income vs. Expenses")
      end
    end

    context "net worth chart" do
      it "shows empty state when no balance history" do
        account
        get dashboard_path
        expect(response.body).to include("No balance history yet")
      end

      it "shows chart when balance history exists" do
        create(:account_balance, account: account, date: 1.month.ago.to_date, balance_cents: 100_000)
        create(:account_balance, account: account, date: Date.current, balance_cents: 150_000)
        get dashboard_path
        expect(response.body).to include("Net Worth Over Time")
      end
    end
  end

  describe "GET /dashboard/drilldown" do
    let!(:groceries) { create(:category, :groceries) }
    let!(:txn) do
      create(:transaction, account: account, category: groceries,
             transaction_type: :debit, amount_cents: 2500, date: Date.current,
             description: "WHOLE FOODS")
    end

    it "returns transactions for the given category" do
      get drilldown_dashboard_path(category_id: groceries.id,
                                    month: Date.current.month,
                                    year: Date.current.year)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("WHOLE FOODS")
      expect(response.body).to include("Groceries")
    end

    it "shows empty state when category has no transactions" do
      empty_cat = create(:category, :dining)
      get drilldown_dashboard_path(category_id: empty_cat.id,
                                    month: Date.current.month,
                                    year: Date.current.year)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No transactions found")
    end
  end
end
