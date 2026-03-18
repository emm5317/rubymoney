require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      txn = build(:transaction)
      expect(txn).to be_valid
    end

    it "requires a date" do
      txn = build(:transaction, date: nil)
      expect(txn).not_to be_valid
    end

    it "requires a description" do
      txn = build(:transaction, description: nil)
      expect(txn).not_to be_valid
    end

    it "requires amount_cents" do
      txn = build(:transaction, amount_cents: nil)
      expect(txn).not_to be_valid
    end

    it "rejects zero amount" do
      txn = build(:transaction, amount_cents: 0)
      expect(txn).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:user) { create(:user) }
    let!(:account) { create(:account, user: user) }
    let!(:category) { create(:category) }

    it ".uncategorized returns transactions without category" do
      uncategorized = create(:transaction, account: account, category: nil)
      categorized = create(:transaction, account: account, category: category, description: "Other")
      expect(Transaction.uncategorized).to include(uncategorized)
      expect(Transaction.uncategorized).not_to include(categorized)
    end

    it ".non_transfer excludes transfers" do
      normal = create(:transaction, account: account, is_transfer: false)
      transfer = create(:transaction, account: account, is_transfer: true, description: "Transfer")
      expect(Transaction.non_transfer).to include(normal)
      expect(Transaction.non_transfer).not_to include(transfer)
    end

    it ".for_month returns transactions in the given month" do
      march = create(:transaction, account: account, date: Date.new(2026, 3, 15))
      april = create(:transaction, account: account, date: Date.new(2026, 4, 1), description: "April")
      expect(Transaction.for_month(Date.new(2026, 3, 1))).to include(march)
      expect(Transaction.for_month(Date.new(2026, 3, 1))).not_to include(april)
    end
  end

  describe "callbacks" do
    it "normalizes description on save" do
      txn = create(:transaction, description: "  STARBUCKS  1234****5678  NYC  ")
      expect(txn.normalized_desc).to eq("STARBUCKS NYC")
    end
  end

  describe "#amount" do
    it "converts cents to dollars" do
      txn = build(:transaction, amount_cents: -1550)
      expect(txn.amount).to eq(-15.5)
    end

    it "converts dollars to cents via setter" do
      txn = build(:transaction)
      txn.amount = 25.99
      expect(txn.amount_cents).to eq(2599)
    end
  end

  describe "#formatted_amount" do
    it "formats as currency" do
      txn = build(:transaction, amount_cents: -1550)
      expect(txn.formatted_amount).to eq("$15.50")
    end
  end
end
