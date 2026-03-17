FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    color { "#4F46E5" }
    sequence(:position) { |n| n }

    trait :groceries do
      name { "Groceries" }
      color { "#059669" }
    end

    trait :dining do
      name { "Dining" }
      color { "#D97706" }
    end

    trait :income do
      name { "Income" }
      color { "#16A34A" }
    end

    trait :transfers do
      name { "Transfers" }
      color { "#6B7280" }
    end
  end
end
