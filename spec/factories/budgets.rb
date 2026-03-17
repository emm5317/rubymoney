FactoryBot.define do
  factory :budget do
    category
    month { Date.current.month }
    year { Date.current.year }
    amount_cents { 50_000 }

    trait :generous do
      amount_cents { 100_000 }
    end
  end
end
