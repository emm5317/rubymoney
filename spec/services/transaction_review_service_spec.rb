require "rails_helper"

RSpec.describe TransactionReviewService do
  describe "#suggestions" do
    let(:user) { create(:user) }
    let(:account) { create(:account, user: user) }

    before do
      create(:category, name: "Transport")
      create(:category, :income)
      create(:category, name: "Education")
    end

    it "groups date-variant descriptions under one stable signature" do
      create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 01/30 PURCHASE HINSDALE IL")
      create(:transaction, account: account, category: nil, description: "SHELL OIL 5744409 02/02 PURCHASE HINSDALE IL")

      suggestions = described_class.new(user: user).suggestions
      shell_group = suggestions.find { |suggestion| suggestion.signature == "SHELL OIL 5744409" }

      expect(shell_group).to be_present
      expect(shell_group.transaction_count).to eq(2)
      expect(shell_group.rule_pattern).to eq("SHELL OIL 5744409")
      expect(shell_group.suggested_category.name).to eq("Transport")
    end

    it "suggests income for payroll-style credits" do
      create(:transaction, :credit, account: account, category: nil,
        description: "MORGAN LEWIS DES:PAYROLL ID:RLWXXXXX0749290 INDN:MAKINEN,ERIC CO ID:XXXXX91050 PPD")

      suggestions = described_class.new(user: user).suggestions
      payroll_group = suggestions.find { |suggestion| suggestion.signature == "MORGAN LEWIS" }

      expect(payroll_group).to be_present
      expect(payroll_group.suggested_category.name).to eq("Income")
      expect(payroll_group.reason).to include("Payroll")
    end
  end
end
