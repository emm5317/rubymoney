require 'rails_helper'

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with email and password" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "requires an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
    end

    it "requires a unique email" do
      create(:user, email: "test@example.com")
      user = build(:user, email: "test@example.com")
      expect(user).not_to be_valid
    end
  end

  describe "associations" do
    it "has many accounts" do
      user = create(:user)
      create(:account, user: user)
      expect(user.accounts.count).to eq(1)
    end
  end
end
