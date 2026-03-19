require "rails_helper"

RSpec.describe "Budgets", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "POST /budgets/copy_previous" do
    let!(:groceries) { create(:category, :groceries) }
    let!(:dining) { create(:category, :dining) }

    context "when previous month has budgets" do
      let(:prev_date) { Date.current - 1.month }

      before do
        create(:budget, category: groceries, month: prev_date.month,
               year: prev_date.year, amount_cents: 30_000)
        create(:budget, category: dining, month: prev_date.month,
               year: prev_date.year, amount_cents: 20_000)
      end

      it "copies budgets to the current month" do
        expect {
          post copy_previous_budgets_path(month: Date.current.month, year: Date.current.year)
        }.to change(Budget, :count).by(2)

        expect(response).to redirect_to(budgets_path)
        follow_redirect!
        expect(response.body).to include("Copied 2 budget(s)")
      end

      it "skips categories that already have budgets" do
        create(:budget, category: groceries, month: Date.current.month,
               year: Date.current.year, amount_cents: 25_000)

        expect {
          post copy_previous_budgets_path(month: Date.current.month, year: Date.current.year)
        }.to change(Budget, :count).by(1)
      end

      it "shows message when all budgets already exist for target month" do
        create(:budget, category: groceries, month: Date.current.month,
               year: Date.current.year, amount_cents: 25_000)
        create(:budget, category: dining, month: Date.current.month,
               year: Date.current.year, amount_cents: 15_000)

        post copy_previous_budgets_path(month: Date.current.month, year: Date.current.year)
        expect(response).to redirect_to(budgets_path)
        follow_redirect!
        expect(response.body).to include("already exist")
      end
    end

    context "when previous month has no budgets" do
      it "redirects with alert" do
        post copy_previous_budgets_path(month: Date.current.month, year: Date.current.year)
        expect(response).to redirect_to(budgets_path)
        follow_redirect!
        expect(response.body).to include("No budgets found")
      end
    end
  end
end
