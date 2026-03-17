FactoryBot.define do
  factory :import_profile do
    account
    institution { "Chase" }
    column_mapping { { date: 0, description: 2, amount: 5 } }
    date_format { "%m/%d/%Y" }
    description_corrections { {} }
    amount_format { "signed" }
    skip_header_rows { 1 }
  end
end
