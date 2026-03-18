require 'rails_helper'

RSpec.describe Categorizer do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:groceries) { create(:category, :groceries) }
  let(:dining) { create(:category, :dining) }

  describe "#categorize" do
    it "categorizes a transaction matching a rule" do
      create(:rule, category: groceries, match_value: "WHOLE FOODS", match_type: :contains, priority: 10)
      txn = create(:transaction, account: account, description: "WHOLE FOODS #1234", category: nil)

      result = described_class.new.categorize(txn)

      expect(result).to be_a(Rule)
      expect(txn.reload.category).to eq(groceries)
      expect(txn.auto_categorized).to be true
    end

    it "skips already-categorized transactions" do
      create(:rule, category: groceries, match_value: "WHOLE FOODS", match_type: :contains, priority: 10)
      txn = create(:transaction, account: account, description: "WHOLE FOODS", category: dining)

      result = described_class.new.categorize(txn)

      expect(result).to be_nil
      expect(txn.reload.category).to eq(dining)
    end

    it "returns nil when no rules match" do
      txn = create(:transaction, account: account, description: "UNKNOWN VENDOR", category: nil)

      result = described_class.new.categorize(txn)

      expect(result).to be_nil
      expect(txn.reload.category_id).to be_nil
    end

    it "applies highest priority rule when multiple match" do
      create(:rule, category: groceries, match_value: "STORE", match_type: :contains, priority: 5)
      create(:rule, category: dining, match_value: "STORE", match_type: :contains, priority: 10)
      txn = create(:transaction, account: account, description: "THE STORE", category: nil)

      described_class.new.categorize(txn)

      expect(txn.reload.category).to eq(dining)
    end
  end

  describe "#categorize_batch" do
    it "categorizes multiple uncategorized transactions" do
      create(:rule, category: groceries, match_value: "GROCERY", match_type: :contains, priority: 10)
      txn1 = create(:transaction, account: account, description: "GROCERY OUTLET", category: nil)
      txn2 = create(:transaction, account: account, description: "GROCERY STORE", category: nil)
      txn3 = create(:transaction, account: account, description: "UNKNOWN", category: nil)

      count = described_class.new.categorize_batch([txn1, txn2, txn3])

      expect(count).to eq(2)
      expect(txn1.reload.category).to eq(groceries)
      expect(txn2.reload.category).to eq(groceries)
      expect(txn3.reload.category_id).to be_nil
    end

    it "skips disabled rules" do
      create(:rule, category: groceries, match_value: "STARBUCKS", match_type: :contains, priority: 10, enabled: false)
      txn = create(:transaction, account: account, description: "STARBUCKS COFFEE", category: nil)

      count = described_class.new.categorize_batch([txn])

      expect(count).to eq(0)
    end
  end
end
