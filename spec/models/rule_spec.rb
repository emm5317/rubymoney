require 'rails_helper'

RSpec.describe Rule, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:rule)).to be_valid
    end

    it "requires match_value" do
      expect(build(:rule, match_value: nil)).not_to be_valid
    end
  end

  describe "#matches?" do
    let(:category) { create(:category, name: "Coffee") }
    let(:txn) { build(:transaction, description: "STARBUCKS #1234 NYC", amount_cents: -550) }

    it "matches contains rule" do
      rule = build(:rule, category: category, match_type: :contains, match_value: "STARBUCKS", match_field: :description)
      expect(rule.matches?(txn)).to be true
    end

    it "does not match when value is absent" do
      rule = build(:rule, category: category, match_type: :contains, match_value: "DUNKIN", match_field: :description)
      expect(rule.matches?(txn)).to be false
    end

    it "matches exact rule (case-insensitive)" do
      rule = build(:rule, category: category, match_type: :exact, match_value: "starbucks #1234 nyc", match_field: :description)
      expect(rule.matches?(txn)).to be true
    end

    it "matches starts_with rule" do
      rule = build(:rule, category: category, match_type: :starts_with, match_value: "STAR", match_field: :description)
      expect(rule.matches?(txn)).to be true
    end

    it "matches regex rule" do
      rule = build(:rule, category: category, match_type: :regex, match_value: "STARBUCKS|PEETS", match_field: :description)
      expect(rule.matches?(txn)).to be true
    end

    it "matches amount between rule" do
      rule = build(:rule, category: category, match_field: :amount_field, match_type: :between, match_value: "100", match_value_upper: "1000")
      txn_with_amount = build(:transaction, amount_cents: 550, description: "test")
      expect(rule.matches?(txn_with_amount)).to be true
    end
  end
end
