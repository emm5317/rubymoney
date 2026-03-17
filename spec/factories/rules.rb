FactoryBot.define do
  factory :rule do
    category
    match_field { :description }
    match_type { :contains }
    match_value { "STARBUCKS" }
    priority { 0 }
    enabled { true }
    apply_retroactive { false }
    auto_tag_ids { [] }

    trait :regex do
      match_type { :regex }
      match_value { "AMAZON|AMZN" }
    end

    trait :amount_range do
      match_field { :amount_field }
      match_type { :between }
      match_value { "1000" }
      match_value_upper { "5000" }
    end
  end
end
