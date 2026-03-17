FactoryBot.define do
  factory :account do
    user
    sequence(:name) { |n| "Account #{n}" }
    account_type { :checking }
    institution { "Chase" }
    currency { "USD" }
    source_type { :manual }
    current_balance_cents { 0 }

    trait :credit_card do
      account_type { :credit_card }
      name { "Chase Sapphire" }
    end

    trait :savings do
      account_type { :savings }
      name { "Savings Account" }
    end

    trait :investment do
      account_type { :investment }
      name { "Schwab Brokerage" }
      institution { "Schwab" }
    end
  end
end
