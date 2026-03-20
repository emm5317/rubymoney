require "rails_helper"

RSpec.describe RecurringDetector do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  def create_monthly_transactions(description, count: 4, amount_cents: -1499, start_date: (count - 1).months.ago.to_date)
    count.times do |i|
      create(:transaction,
        account: account,
        description: description,
        normalized_desc: description,
        amount_cents: amount_cents,
        date: start_date + (i * 30).days,
        is_transfer: false
      )
    end
  end

  def create_weekly_transactions(description, count: 6, amount_cents: -500)
    count.times do |i|
      create(:transaction,
        account: account,
        description: description,
        normalized_desc: description,
        amount_cents: amount_cents,
        date: (count - 1 - i).weeks.ago.to_date,
        is_transfer: false
      )
    end
  end

  describe "#detect_all" do
    it "detects monthly recurring transactions" do
      create_monthly_transactions("NETFLIX.COM")

      results = described_class.new(user).detect_all

      expect(results[:created]).to eq(1)
      recurring = RecurringTransaction.last
      expect(recurring.description_pattern).to eq("NETFLIX.COM")
      expect(recurring.frequency).to eq("monthly")
      expect(recurring.average_amount_cents).to eq(-1499)
      expect(recurring.status).to eq("active")
      expect(recurring.occurrence_count).to eq(4)
    end

    it "detects weekly recurring transactions" do
      create_weekly_transactions("METRO TRANSIT")

      results = described_class.new(user).detect_all

      expect(results[:created]).to eq(1)
      recurring = RecurringTransaction.last
      expect(recurring.frequency).to eq("weekly")
    end

    it "ignores groups with fewer than 3 occurrences" do
      2.times do |i|
        create(:transaction,
          account: account,
          description: "RARE CHARGE",
          normalized_desc: "RARE CHARGE",
          date: i.months.ago.to_date,
          amount_cents: -999,
          is_transfer: false
        )
      end

      results = described_class.new(user).detect_all
      expect(results[:created]).to eq(0)
      expect(RecurringTransaction.count).to eq(0)
    end

    it "ignores groups with irregular intervals" do
      # Create transactions with wildly varying intervals
      [0, 5, 50, 52, 180].each do |days_ago|
        create(:transaction,
          account: account,
          description: "IRREGULAR CHARGE",
          normalized_desc: "IRREGULAR CHARGE",
          date: days_ago.days.ago.to_date,
          amount_cents: -500,
          is_transfer: false
        )
      end

      results = described_class.new(user).detect_all
      expect(results[:created]).to eq(0)
    end

    it "updates existing records on re-run without duplicating" do
      create_monthly_transactions("NETFLIX.COM")
      described_class.new(user).detect_all
      expect(RecurringTransaction.count).to eq(1)

      # Add another transaction and re-run
      create(:transaction,
        account: account,
        description: "NETFLIX.COM",
        normalized_desc: "NETFLIX.COM",
        date: Date.current,
        amount_cents: -1599,
        is_transfer: false
      )

      results = described_class.new(user).detect_all
      expect(RecurringTransaction.count).to eq(1)
      expect(results[:updated]).to eq(1)

      recurring = RecurringTransaction.last
      expect(recurring.occurrence_count).to eq(5)
      expect(recurring.last_amount_cents).to eq(-1599)
    end

    it "does not reactivate user-dismissed patterns" do
      create_monthly_transactions("NETFLIX.COM")
      described_class.new(user).detect_all

      recurring = RecurringTransaction.last
      recurring.update!(user_dismissed: true)

      results = described_class.new(user).detect_all
      recurring.reload
      expect(recurring.user_dismissed?).to be true
    end

    it "ignores transfer transactions" do
      4.times do |i|
        create(:transaction,
          account: account,
          description: "TRANSFER TO SAVINGS",
          normalized_desc: "TRANSFER TO SAVINGS",
          date: i.months.ago.to_date,
          amount_cents: -50000,
          is_transfer: true
        )
      end

      results = described_class.new(user).detect_all
      expect(results[:created]).to eq(0)
    end

    it "sets confidence based on interval regularity" do
      # Perfect 30-day intervals
      create_monthly_transactions("SPOTIFY", count: 5)

      described_class.new(user).detect_all
      recurring = RecurringTransaction.last
      expect(recurring.confidence).to be >= 0.8
    end

    it "calculates next_expected_date from last occurrence" do
      create_monthly_transactions("NETFLIX.COM", count: 4, start_date: 3.months.ago.to_date)

      described_class.new(user).detect_all
      recurring = RecurringTransaction.last
      expect(recurring.next_expected_date).to be > recurring.last_seen_date
    end

    it "reactivates a missed recurring transaction when fresh matches resume" do
      create_monthly_transactions("NETFLIX.COM", count: 4, start_date: 6.months.ago.to_date)
      described_class.new(user).detect_all

      recurring = RecurringTransaction.last
      recurring.update!(next_expected_date: 60.days.ago.to_date, status: :missed, user_confirmed: true)

      create(:transaction,
        account: account,
        description: "NETFLIX.COM",
        normalized_desc: "NETFLIX.COM",
        date: Date.current,
        amount_cents: -1499,
        is_transfer: false
      )

      described_class.new(user).detect_all
      expect(recurring.reload.status).to eq("active")
    end

    it "does not auto-detect annual patterns within the current lookback window" do
      [Date.current - 730.days, Date.current - 365.days, Date.current].each do |date|
        create(:transaction,
          account: account,
          description: "AMAZON PRIME",
          normalized_desc: "AMAZON PRIME",
          date: date,
          amount_cents: -13900,
          is_transfer: false
        )
      end

      results = described_class.new(user).detect_all
      expect(results[:created]).to eq(0)
      expect(RecurringTransaction.where(description_pattern: "AMAZON PRIME")).to be_empty
    end
  end

  describe "mark_missed_recurring" do
    it "marks active recurring as missed when significantly overdue" do
      create_monthly_transactions("OLD SERVICE", count: 4, start_date: 6.months.ago.to_date)
      described_class.new(user).detect_all

      recurring = RecurringTransaction.last
      # Force the next_expected_date to be well in the past
      recurring.update!(next_expected_date: 60.days.ago.to_date, status: :active)

      results = described_class.new(user).detect_all
      recurring.reload
      expect(recurring.status).to eq("missed")
    end
  end
end
