require "rails_helper"

RSpec.describe "Transaction reviews", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let!(:transport) { create(:category, name: "Transport") }
  let!(:income) { create(:category, :income) }

  before { sign_in user }

  describe "GET /transactions/review" do
    it "renders grouped suggestions for uncategorized transactions" do
      create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 01/30 PURCHASE HINSDALE IL")
      create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 02/02 PURCHASE HINSDALE IL")
      create(:transaction, :credit, account: account, category: nil,
        description: "MORGAN LEWIS DES:PAYROLL ID:RLWXXXXX0749290 INDN:MAKINEN,ERIC CO ID:XXXXX91050 PPD")

      get transaction_review_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Categorization Review")
      expect(response.body).to include("SHELL OIL 5744409")
      expect(response.body).to include("MORGAN LEWIS")
      expect(response.body).to include("Transport")
      expect(response.body).to include("Income")
    end
  end

  describe "POST /transactions/review/apply" do
    it "categorizes the reviewed group and creates a rule" do
      txn_one = create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 01/30 PURCHASE HINSDALE IL")
      txn_two = create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 02/02 PURCHASE HINSDALE IL")

      post apply_transaction_review_path, params: {
        suggestions: {
          "0" => {
            apply: "1",
            signature: "SHELL OIL 5744409",
            category_id: transport.id,
            rule_pattern: "SHELL OIL 5744409",
            create_rule: "1"
          }
        }
      }

      expect(response).to redirect_to(transaction_review_path)
      expect(txn_one.reload.category).to eq(transport)
      expect(txn_two.reload.category).to eq(transport)

      rule = Rule.find_by(match_value: "SHELL OIL 5744409")
      expect(rule).to be_present
      expect(rule.category).to eq(transport)
      expect(rule.match_field).to eq("normalized_desc")
      expect(rule.match_type).to eq("contains")
    end

    it "only applies changes to the signed-in user's transactions" do
      other_user = create(:user)
      other_account = create(:account, user: other_user)
      own_txn = create(:transaction, account: account, category: nil, description: "MORGAN LEWIS DES:PAYROLL ID:AAA")
      other_txn = create(:transaction, :credit, account: other_account, category: nil, description: "MORGAN LEWIS DES:PAYROLL ID:BBB")

      post apply_transaction_review_path, params: {
        suggestions: {
          "0" => {
            apply: "1",
            signature: "MORGAN LEWIS",
            category_id: income.id,
            rule_pattern: "MORGAN LEWIS",
            create_rule: "0"
          }
        }
      }

      expect(own_txn.reload.category).to eq(income)
      expect(other_txn.reload.category).to be_nil
    end
  end
end
