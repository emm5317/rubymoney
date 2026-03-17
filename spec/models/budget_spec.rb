require 'rails_helper'

RSpec.describe Budget, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:budget)).to be_valid
    end

    it "requires month between 1-12" do
      expect(build(:budget, month: 0)).not_to be_valid
      expect(build(:budget, month: 13)).not_to be_valid
    end

    it "requires year > 2000" do
      expect(build(:budget, year: 1999)).not_to be_valid
    end

    it "requires unique category per month/year" do
      category = create(:category, name: "Budget Test")
      create(:budget, category: category, month: 3, year: 2026)
      expect(build(:budget, category: category, month: 3, year: 2026)).not_to be_valid
    end

    it "allows same category in different months" do
      category = create(:category, name: "Budget Test 2")
      create(:budget, category: category, month: 3, year: 2026)
      expect(build(:budget, category: category, month: 4, year: 2026)).to be_valid
    end
  end

  describe "#display_amount" do
    it "converts cents to dollars" do
      budget = build(:budget, amount_cents: 50_000)
      expect(budget.display_amount).to eq(500.0)
    end
  end
end
