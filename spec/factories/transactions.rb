FactoryBot.define do
  factory :transaction do
    account
    date { Date.current }
    description { "STARBUCKS #1234" }
    amount_cents { -450 }
    transaction_type { :debit }
    status { :cleared }
    source_type { "manual" }

    trait :credit do
      description { "PAYROLL DEPOSIT" }
      amount_cents { 250_000 }
      transaction_type { :credit }
    end

    trait :uncategorized do
      category { nil }
    end

    trait :categorized do
      category
    end

    trait :transfer do
      is_transfer { true }
      description { "TRANSFER TO SAVINGS" }
    end

    trait :with_import do
      import
    end

    trait :with_fingerprint do
      sequence(:source_fingerprint) { |n| Digest::SHA256.hexdigest("txn-#{n}") }
    end
  end
end
