require 'rails_helper'

RSpec.describe AccountBalance, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:account_balance)).to be_valid
    end

    it "requires a date" do
      expect(build(:account_balance, date: nil)).not_to be_valid
    end

    it "requires unique date per account" do
      bal = create(:account_balance)
      dup = build(:account_balance, account: bal.account, date: bal.date)
      expect(dup).not_to be_valid
    end
  end

  describe "#display_balance" do
    it "converts cents to dollars" do
      balance = build(:account_balance, balance_cents: 250_050)
      expect(balance.display_balance).to eq(2500.5)
    end
  end
end
