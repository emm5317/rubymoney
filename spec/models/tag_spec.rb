require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe "validations" do
    it "is valid with a name" do
      expect(build(:tag)).to be_valid
    end

    it "requires a name" do
      expect(build(:tag, name: nil)).not_to be_valid
    end

    it "requires unique name" do
      create(:tag, name: "vacation")
      expect(build(:tag, name: "vacation")).not_to be_valid
    end
  end

  describe "associations" do
    it "has many transactions through transaction_tags" do
      tag = create(:tag)
      account = create(:account)
      txn = create(:transaction, account: account)
      TransactionTag.create!(financial_transaction: txn, tag: tag)
      expect(tag.transactions).to include(txn)
    end
  end
end
