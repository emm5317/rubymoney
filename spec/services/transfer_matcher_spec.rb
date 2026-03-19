require "rails_helper"

RSpec.describe TransferMatcher do
  let(:user) { create(:user) }
  let(:checking) { create(:account, user: user, name: "Checking") }
  let(:savings) { create(:account, user: user, name: "Savings") }
  let(:matcher) { described_class.new }

  describe "#find_candidates" do
    let!(:debit) do
      create(:transaction, account: checking, amount_cents: -50000, date: Date.new(2026, 3, 10), description: "Transfer to Savings")
    end

    it "finds matching opposite-sign transaction in different account" do
      credit = create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer from Checking")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to include(credit)
    end

    it "excludes transactions from the same account" do
      create(:transaction, account: checking, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Refund")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to be_empty
    end

    it "excludes transactions with different amounts" do
      create(:transaction, account: savings, amount_cents: 30000, date: Date.new(2026, 3, 10), description: "Partial transfer")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to be_empty
    end

    it "excludes transactions outside the date window" do
      create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 20), description: "Late transfer")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to be_empty
    end

    it "includes transactions within the date window" do
      credit = create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 12), description: "Transfer from Checking")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to include(credit)
    end

    it "excludes already-linked transfers" do
      create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), is_transfer: true, transfer_pair_id: 999, description: "Already linked")
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to be_empty
    end

    it "returns empty when transaction is already a transfer" do
      debit.update!(is_transfer: true)
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates).to be_empty
    end

    it "limits results to 10" do
      12.times do |i|
        create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer #{i}")
      end
      candidates = matcher.find_candidates(debit, user: user)
      expect(candidates.size).to eq(10)
    end
  end

  describe "#detect_transfers" do
    let!(:debit) do
      create(:transaction, account: checking, amount_cents: -50000, date: Date.new(2026, 3, 10), description: "Transfer to Savings")
    end

    it "auto-links unambiguous transfer pair" do
      credit = create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer from Checking")
      linked = matcher.detect_transfers([debit], user: user)

      expect(linked).to eq(1)
      expect(debit.reload.is_transfer).to be true
      expect(credit.reload.is_transfer).to be true
      expect(debit.transfer_pair_id).to eq(credit.id)
    end

    it "skips when multiple candidates exist (ambiguous)" do
      create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer A")
      create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 11), description: "Transfer B")
      linked = matcher.detect_transfers([debit], user: user)

      expect(linked).to eq(0)
      expect(debit.reload.is_transfer).to be false
    end

    it "skips transactions already marked as transfers" do
      create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer from Checking")
      debit.update!(is_transfer: true)
      linked = matcher.detect_transfers([debit], user: user)

      expect(linked).to eq(0)
    end

    it "returns count of linked pairs" do
      credit = create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10), description: "Transfer from Checking")
      debit2 = create(:transaction, account: checking, amount_cents: -25000, date: Date.new(2026, 3, 12), description: "Another transfer")
      credit2 = create(:transaction, account: savings, amount_cents: 25000, date: Date.new(2026, 3, 12), description: "Another transfer in")
      linked = matcher.detect_transfers([debit, debit2], user: user)

      expect(linked).to eq(2)
    end
  end

  describe "#link!" do
    let!(:debit) { create(:transaction, account: checking, amount_cents: -50000, date: Date.new(2026, 3, 10)) }
    let!(:credit) { create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10)) }

    it "links both transactions as a transfer pair" do
      matcher.link!(debit, credit)

      debit.reload
      credit.reload

      expect(debit.is_transfer).to be true
      expect(credit.is_transfer).to be true
      expect(debit.transfer_pair_id).to eq(credit.id)
      expect(credit.transfer_pair_id).to eq(debit.id)
    end
  end

  describe "#unlink!" do
    let!(:debit) { create(:transaction, account: checking, amount_cents: -50000, date: Date.new(2026, 3, 10)) }
    let!(:credit) { create(:transaction, account: savings, amount_cents: 50000, date: Date.new(2026, 3, 10)) }

    before { matcher.link!(debit, credit) }

    it "unlinks both transactions" do
      matcher.unlink!(debit)

      debit.reload
      credit.reload

      expect(debit.is_transfer).to be false
      expect(credit.is_transfer).to be false
      expect(debit.transfer_pair_id).to be_nil
      expect(credit.transfer_pair_id).to be_nil
    end
  end
end
