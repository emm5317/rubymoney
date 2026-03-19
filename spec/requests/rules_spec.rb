require "rails_helper"

RSpec.describe "Rules", type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:category, :groceries) }

  before { sign_in user }

  describe "GET /rules" do
    it "loads successfully" do
      get rules_path
      expect(response).to have_http_status(:ok)
    end

    it "lists rules sorted by priority" do
      create(:rule, match_value: "STARBUCKS", category: category, priority: 10)
      create(:rule, match_value: "WHOLE FOODS", category: category, priority: 20)

      get rules_path
      expect(response.body).to include("STARBUCKS")
      expect(response.body).to include("WHOLE FOODS")
    end
  end

  describe "GET /rules/:id" do
    it "shows rule details" do
      rule = create(:rule, match_value: "AMAZON", category: category)
      get rule_path(rule)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AMAZON")
    end
  end

  describe "GET /rules/new" do
    it "renders the form" do
      get new_rule_path
      expect(response).to have_http_status(:ok)
    end

    it "pre-fills from query params (create rule from transaction flow)" do
      get new_rule_path(match_value: "WHOLE FOODS", match_field: "normalized_desc", match_type: "contains")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("WHOLE FOODS")
    end
  end

  describe "POST /rules" do
    it "creates a valid rule" do
      expect {
        post rules_path, params: {
          rule: {
            match_value: "TARGET",
            match_field: "description",
            match_type: "contains",
            category_id: category.id,
            priority: 5,
            enabled: true
          }
        }
      }.to change(Rule, :count).by(1)
      expect(response).to redirect_to(rules_path)
      follow_redirect!
      expect(response.body).to include("Rule created")
    end

    it "rejects blank match_value" do
      post rules_path, params: {
        rule: {
          match_value: "",
          match_field: "description",
          match_type: "contains",
          category_id: category.id,
          priority: 5
        }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "with apply_retroactive" do
      let(:account) { create(:account, user: user) }

      it "auto-categorizes existing uncategorized transactions" do
        txn = create(:transaction, account: account, description: "COSTCO #123",
                     category: nil, amount_cents: -5000)

        post rules_path, params: {
          rule: {
            match_value: "COSTCO",
            match_field: "description",
            match_type: "contains",
            category_id: category.id,
            priority: 5,
            enabled: true,
            apply_retroactive: true
          }
        }

        expect(response).to redirect_to(rules_path)
        follow_redirect!
        expect(response.body).to include("auto-categorized")
        expect(txn.reload.category).to eq(category)
      end
    end
  end

  describe "PATCH /rules/:id" do
    let!(:rule) { create(:rule, match_value: "OLD VALUE", category: category) }

    it "updates the rule" do
      patch rule_path(rule), params: { rule: { match_value: "NEW VALUE" } }
      expect(response).to redirect_to(rules_path)
      expect(rule.reload.match_value).to eq("NEW VALUE")
    end

    it "rejects invalid update" do
      patch rule_path(rule), params: { rule: { match_value: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /rules/:id" do
    let!(:rule) { create(:rule, match_value: "TO DELETE", category: category) }

    it "deletes and redirects" do
      expect {
        delete rule_path(rule)
      }.to change(Rule, :count).by(-1)
      expect(response).to redirect_to(rules_path)
    end
  end

  describe "enabled/disabled" do
    it "creates a disabled rule" do
      post rules_path, params: {
        rule: {
          match_value: "DISABLED",
          match_field: "description",
          match_type: "contains",
          category_id: category.id,
          priority: 1,
          enabled: false
        }
      }
      expect(Rule.last.enabled).to be false
    end
  end

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users" do
      get rules_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
