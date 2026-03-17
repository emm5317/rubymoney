FactoryBot.define do
  factory :account_balance do
    account
    date { Date.current }
    balance_cents { 150_000 }
    source { :calculated }
  end
end
