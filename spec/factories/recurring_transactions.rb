FactoryBot.define do
  factory :recurring_transaction do
    account
    title { "Netflix" }
    description_pattern { "NETFLIX.COM" }
    average_amount_cents { -1499 }
    last_amount_cents { -1499 }
    frequency { :monthly }
    confidence { 0.85 }
    occurrence_count { 5 }
    last_seen_date { 15.days.ago.to_date }
    next_expected_date { 15.days.from_now.to_date }
    status { :active }
    user_confirmed { false }
    user_dismissed { false }
    amount_variance { 0.0 }
    average_interval_days { 30 }

    trait :weekly do
      title { "Bus Pass" }
      description_pattern { "METRO TRANSIT" }
      frequency { :weekly }
      average_interval_days { 7 }
    end

    trait :annual do
      title { "Amazon Prime" }
      description_pattern { "AMAZON PRIME MEMBERSHIP" }
      frequency { :annual }
      average_amount_cents { -13900 }
      last_amount_cents { -13900 }
      average_interval_days { 365 }
    end

    trait :missed do
      status { :missed }
      next_expected_date { 10.days.ago.to_date }
    end

    trait :dismissed do
      user_dismissed { true }
    end

    trait :user_confirmed do
      user_confirmed { true }
      confidence { 1.0 }
    end

    trait :with_category do
      category
    end
  end
end
