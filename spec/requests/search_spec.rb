require "rails_helper"

RSpec.describe "Transaction Search", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /transactions?q=..." do
    let!(:starbucks) { create(:transaction, account: account, description: "STARBUCKS COFFEE", date: Date.current) }
    let!(:walmart) { create(:transaction, account: account, description: "WALMART GROCERY", date: Date.current) }

    it "filters transactions by search term" do
      get transactions_path(q: "STARBUCKS")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("STARBUCKS COFFEE")
      expect(response.body).not_to include("WALMART GROCERY")
    end

    it "returns no results for non-matching search" do
      get transactions_path(q: "COSTCO")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No transactions match your filters")
    end

    it "combines search with other filters" do
      other_account = create(:account, user: user, name: "Savings")
      create(:transaction, account: other_account, description: "STARBUCKS DRIVE THRU", date: Date.current)

      get transactions_path(q: "STARBUCKS", account_id: account.id)
      expect(response.body).to include("STARBUCKS COFFEE")
      expect(response.body).not_to include("STARBUCKS DRIVE THRU")
    end

    it "shows search term in filter as active" do
      get transactions_path(q: "STARBUCKS")
      expect(response.body).to include("Clear")
    end

    it "shows all transactions when search is blank" do
      get transactions_path(q: "")
      expect(response.body).to include("STARBUCKS COFFEE")
      expect(response.body).to include("WALMART GROCERY")
    end
  end
end
