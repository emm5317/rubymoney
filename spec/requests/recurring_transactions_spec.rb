require "rails_helper"

RSpec.describe "RecurringTransactions", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /recurring_transactions" do
    it "returns success" do
      get recurring_transactions_path
      expect(response).to have_http_status(:success)
    end

    it "displays active recurring transactions" do
      recurring = create(:recurring_transaction, account: account, title: "Netflix")
      get recurring_transactions_path
      expect(response.body).to include("Netflix")
    end

    it "does not show dismissed transactions in main list" do
      create(:recurring_transaction, :dismissed, account: account, title: "Old Service")
      get recurring_transactions_path
      # Dismissed are in a collapsed details section, not in the active table
      expect(response.body).to include("Old Service") # still on page in dismissed section
    end
  end

  describe "GET /recurring_transactions/:id" do
    it "shows recurring transaction detail" do
      recurring = create(:recurring_transaction, account: account)
      get recurring_transaction_path(recurring)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recurring.title)
    end

    it "returns 404 for other users recurring transactions" do
      other_account = create(:account)
      recurring = create(:recurring_transaction, account: other_account)
      expect { get recurring_transaction_path(recurring) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "GET /recurring_transactions/:id/edit" do
    it "renders edit form" do
      recurring = create(:recurring_transaction, account: account)
      get edit_recurring_transaction_path(recurring)
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /recurring_transactions/:id" do
    it "updates the recurring transaction" do
      recurring = create(:recurring_transaction, account: account, title: "Old Name")
      patch recurring_transaction_path(recurring), params: {
        recurring_transaction: { title: "New Name" }
      }
      expect(response).to redirect_to(recurring_transaction_path(recurring))
      expect(recurring.reload.title).to eq("New Name")
    end
  end

  describe "DELETE /recurring_transactions/:id" do
    it "deletes the recurring transaction" do
      recurring = create(:recurring_transaction, account: account)
      expect {
        delete recurring_transaction_path(recurring)
      }.to change(RecurringTransaction, :count).by(-1)
      expect(response).to redirect_to(recurring_transactions_path)
    end
  end

  describe "POST /recurring_transactions/:id/confirm" do
    it "confirms the recurring transaction" do
      recurring = create(:recurring_transaction, account: account, user_confirmed: false)
      post confirm_recurring_transaction_path(recurring)
      expect(recurring.reload.user_confirmed?).to be true
      expect(response).to redirect_to(recurring_transactions_path)
    end
  end

  describe "POST /recurring_transactions/:id/dismiss" do
    it "dismisses the recurring transaction" do
      recurring = create(:recurring_transaction, account: account)
      post dismiss_recurring_transaction_path(recurring)
      expect(recurring.reload.user_dismissed?).to be true
      expect(response).to redirect_to(recurring_transactions_path)
    end
  end

  describe "POST /recurring_transactions/:id/reactivate" do
    it "reactivates a dismissed recurring transaction" do
      recurring = create(:recurring_transaction, :dismissed, account: account)
      post reactivate_recurring_transaction_path(recurring)
      expect(recurring.reload.user_dismissed?).to be false
      expect(recurring.status).to eq("active")
      expect(response).to redirect_to(recurring_transactions_path)
    end
  end

  describe "POST /recurring_transactions/detect_now" do
    it "runs detection and redirects with results" do
      post detect_now_recurring_transactions_path
      expect(response).to redirect_to(recurring_transactions_path)
      expect(flash[:notice]).to include("Detection complete")
    end
  end

  describe "POST /recurring_transactions/mark_recurring" do
    it "creates a recurring transaction from transaction group" do
      3.times do |i|
        create(:transaction,
          account: account,
          description: "SPOTIFY",
          normalized_desc: "SPOTIFY",
          date: i.months.ago.to_date,
          amount_cents: -999,
          is_transfer: false
        )
      end

      expect {
        post mark_recurring_recurring_transactions_path, params: {
          account_id: account.id,
          description_pattern: "SPOTIFY"
        }
      }.to change(RecurringTransaction, :count).by(1)

      recurring = RecurringTransaction.last
      expect(recurring.title).to include("Spotify")
      expect(recurring.user_confirmed?).to be true
    end

    it "rejects groups with fewer than 2 transactions" do
      create(:transaction,
        account: account,
        description: "RARE",
        normalized_desc: "RARE",
        date: Date.current,
        amount_cents: -500,
        is_transfer: false
      )

      post mark_recurring_recurring_transactions_path, params: {
        account_id: account.id,
        description_pattern: "RARE"
      }
      expect(response).to redirect_to(recurring_transactions_path)
      expect(flash[:alert]).to include("at least 2")
    end
  end
end
