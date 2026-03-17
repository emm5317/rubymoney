FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag-#{n}" }
    color { "#3B82F6" }

    trait :tax_deductible do
      name { "tax-deductible" }
      color { "#16A34A" }
    end

    trait :reimbursable do
      name { "reimbursable" }
      color { "#D97706" }
    end
  end
end
