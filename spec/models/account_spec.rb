require 'rails_helper'

RSpec.describe Account, type: :model do
  describe "validations" do
    subject { build(:account) }

    it "is valid with valid attributes" do
      expect(subject).to be_valid
    end

    it "requires a name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires a unique name per user" do
      user = create(:user)
      create(:account, user: user, name: "Checking")
      account = build(:account, user: user, name: "Checking")
      expect(account).not_to be_valid
    end

    it "allows same name for different users" do
      create(:account, name: "Checking")
      subject.name = "Checking"
      expect(subject).to be_valid
    end

    it "requires currency" do
      subject.currency = nil
      expect(subject).not_to be_valid
    end
  end

  describe "enums" do
    it "defines account_type" do
      expect(Account.account_types.keys).to include("checking", "savings", "credit_card", "investment")
    end

    it "defines source_type" do
      expect(Account.source_types.keys).to include("manual", "csv", "ofx", "pdf", "plaid")
    end
  end

  describe "#display_balance" do
    it "converts cents to dollars" do
      account = build(:account, current_balance_cents: 150_075)
      expect(account.display_balance).to eq(1500.75)
    end
  end
end
