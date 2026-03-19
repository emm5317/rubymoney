class BalanceSnapshotJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each do |user|
      user.accounts.find_each do |account|
        AccountBalance.find_or_initialize_by(
          account: account,
          date: Date.current
        ).update!(
          balance_cents: account.current_balance_cents,
          source: :calculated
        )
      end
    end
  end
end
