require "rails_helper"

RSpec.describe "Category Merge", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "POST /categories/merge" do
    let!(:source) { create(:category, name: "Eating Out") }
    let!(:target) { create(:category, name: "Dining") }

    it "reassigns transactions from source to target" do
      txn = create(:transaction, account: account, category: source)

      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(txn.reload.category).to eq(target)
    end

    it "reassigns rules from source to target" do
      rule = create(:rule, category: source)

      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(rule.reload.category).to eq(target)
    end

    it "merges budgets summing amounts for same month/year" do
      create(:budget, category: source, month: 3, year: 2026, amount_cents: 10_000)
      create(:budget, category: target, month: 3, year: 2026, amount_cents: 20_000)

      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      budget = target.budgets.find_by(month: 3, year: 2026)
      expect(budget.amount_cents).to eq(30_000)
    end

    it "moves budgets when target has none for that month" do
      budget = create(:budget, category: source, month: 1, year: 2026, amount_cents: 15_000)

      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(budget.reload.category).to eq(target)
    end

    it "deletes the source category" do
      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(Category.exists?(source.id)).to be false
    end

    it "reassigns child categories" do
      child = create(:category, name: "Fast Food", parent: source)

      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(child.reload.parent).to eq(target)
    end

    it "redirects with success notice" do
      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(response).to redirect_to(categories_path)
      follow_redirect!
      expect(response.body).to include("merged into")
    end

    it "rejects merging a category into itself" do
      post merge_categories_path, params: { source_id: source.id, target_id: source.id }
      expect(response).to redirect_to(categories_path)
      follow_redirect!
      expect(response.body).to include("Cannot merge a category into itself")
    end

    it "requires authentication" do
      sign_out user
      post merge_categories_path, params: { source_id: source.id, target_id: target.id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
