require "rails_helper"

RSpec.describe RecurringTransaction, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      recurring = build(:recurring_transaction)
      expect(recurring).to be_valid
    end

    it "requires a title" do
      recurring = build(:recurring_transaction, title: nil)
      expect(recurring).not_to be_valid
    end

    it "requires a description_pattern" do
      recurring = build(:recurring_transaction, description_pattern: nil)
      expect(recurring).not_to be_valid
    end

    it "requires average_amount_cents" do
      recurring = build(:recurring_transaction, average_amount_cents: nil)
      expect(recurring).not_to be_valid
    end

    it "enforces uniqueness of description_pattern per account" do
      account = create(:account)
      create(:recurring_transaction, account: account, description_pattern: "NETFLIX.COM")
      duplicate = build(:recurring_transaction, account: account, description_pattern: "NETFLIX.COM")
      expect(duplicate).not_to be_valid
    end

    it "allows same description_pattern on different accounts" do
      recurring1 = create(:recurring_transaction, description_pattern: "NETFLIX.COM")
      recurring2 = build(:recurring_transaction, description_pattern: "NETFLIX.COM")
      expect(recurring2).to be_valid
    end
  end

  describe "enums" do
    it "defines frequency enum" do
      expect(RecurringTransaction.frequencies).to include(
        "monthly" => 0, "weekly" => 1, "biweekly" => 2, "quarterly" => 3, "annual" => 4
      )
    end

    it "defines status enum" do
      expect(RecurringTransaction.statuses).to include(
        "active" => 0, "paused" => 1, "cancelled" => 2, "missed" => 3
      )
    end
  end

  describe "scopes" do
    let(:account) { create(:account) }

    it ".active_or_missed returns active and missed only" do
      active = create(:recurring_transaction, account: account, description_pattern: "A", status: :active)
      missed = create(:recurring_transaction, account: account, description_pattern: "B", status: :missed)
      create(:recurring_transaction, account: account, description_pattern: "C", status: :cancelled)

      expect(RecurringTransaction.active_or_missed).to contain_exactly(active, missed)
    end

    it ".not_dismissed excludes dismissed records" do
      visible = create(:recurring_transaction, account: account, description_pattern: "A", user_dismissed: false)
      create(:recurring_transaction, account: account, description_pattern: "B", user_dismissed: true)

      expect(RecurringTransaction.not_dismissed).to contain_exactly(visible)
    end
  end

  describe "#monthly_cost_cents" do
    it "returns amount directly for monthly" do
      recurring = build(:recurring_transaction, frequency: :monthly, average_amount_cents: -1499)
      expect(recurring.monthly_cost_cents).to eq(-1499)
    end

    it "multiplies by 4 for weekly" do
      recurring = build(:recurring_transaction, frequency: :weekly, average_amount_cents: -500)
      expect(recurring.monthly_cost_cents).to eq(-2000)
    end

    it "multiplies by 2 for biweekly" do
      recurring = build(:recurring_transaction, frequency: :biweekly, average_amount_cents: -1000)
      expect(recurring.monthly_cost_cents).to eq(-2000)
    end

    it "divides by 3 for quarterly" do
      recurring = build(:recurring_transaction, frequency: :quarterly, average_amount_cents: -3000)
      expect(recurring.monthly_cost_cents).to eq(-1000)
    end

    it "divides by 12 for annual" do
      recurring = build(:recurring_transaction, frequency: :annual, average_amount_cents: -12000)
      expect(recurring.monthly_cost_cents).to eq(-1000)
    end
  end

  describe "#amount_changed_significantly?" do
    it "returns false when amounts are close" do
      recurring = build(:recurring_transaction, average_amount_cents: -1000, last_amount_cents: -1050)
      expect(recurring.amount_changed_significantly?).to be false
    end

    it "returns true when last amount differs by more than 15%" do
      recurring = build(:recurring_transaction, average_amount_cents: -1000, last_amount_cents: -1200)
      expect(recurring.amount_changed_significantly?).to be true
    end

    it "returns false when last_amount_cents is nil" do
      recurring = build(:recurring_transaction, average_amount_cents: -1000, last_amount_cents: nil)
      expect(recurring.amount_changed_significantly?).to be false
    end
  end

  describe "#overdue?" do
    it "returns true when next_expected_date is in the past" do
      recurring = build(:recurring_transaction, next_expected_date: 5.days.ago.to_date)
      expect(recurring.overdue?).to be true
    end

    it "returns false when next_expected_date is in the future" do
      recurring = build(:recurring_transaction, next_expected_date: 5.days.from_now.to_date)
      expect(recurring.overdue?).to be false
    end

    it "returns false when next_expected_date is nil" do
      recurring = build(:recurring_transaction, next_expected_date: nil)
      expect(recurring.overdue?).to be false
    end
  end
end
