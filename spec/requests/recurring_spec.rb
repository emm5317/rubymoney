require "rails_helper"

RSpec.describe "Recurring Transactions", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /recurring" do
    it "loads successfully with no transactions" do
      get recurring_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recurring Transactions")
      expect(response.body).to include("No recurring transactions detected")
    end

    it "detects recurring transactions" do
      # Create transactions that appear in 3+ distinct months with similar amounts
      ["2026-01-15", "2026-02-15", "2026-03-15"].each do |date|
        create(:transaction, account: account, description: "NETFLIX SUBSCRIPTION",
               amount_cents: -1599, date: Date.parse(date), transaction_type: :debit)
      end

      get recurring_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("NETFLIX SUBSCRIPTION")
      expect(response.body).to include("Monthly")
    end

    it "does not detect non-recurring transactions" do
      create(:transaction, account: account, description: "ONE TIME PURCHASE",
             amount_cents: -5000, date: Date.new(2026, 1, 15))

      get recurring_index_path
      expect(response.body).not_to include("ONE TIME PURCHASE")
    end

    it "requires authentication" do
      sign_out user
      get recurring_index_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
