require "rails_helper"

RSpec.describe BalanceSnapshotJob, type: :job do
  let(:user) { create(:user) }
  let!(:checking) { create(:account, user: user, current_balance_cents: 150_000) }
  let!(:savings) { create(:account, user: user, name: "Savings", current_balance_cents: 500_000) }

  it "creates balance snapshots for all accounts" do
    expect {
      described_class.perform_now
    }.to change(AccountBalance, :count).by(2)

    snapshot = AccountBalance.find_by(account: checking, date: Date.current)
    expect(snapshot.balance_cents).to eq(150_000)
    expect(snapshot.source).to eq("calculated")
  end

  it "updates existing snapshot for the same day" do
    AccountBalance.create!(account: checking, date: Date.current, balance_cents: 100_000, source: :calculated)

    expect {
      described_class.perform_now
    }.to change(AccountBalance, :count).by(1) # only savings is new

    expect(AccountBalance.find_by(account: checking, date: Date.current).balance_cents).to eq(150_000)
  end

  it "does not create snapshots for users with no accounts" do
    create(:user) # user with no accounts
    expect {
      described_class.perform_now
    }.to change(AccountBalance, :count).by(2) # only the 2 accounts from let!
  end
end
