FactoryBot.define do
  factory :import do
    account
    file_name { "statement_2026_03.csv" }
    file_type { :csv }
    status { :pending }
    total_rows { 0 }
    imported_count { 0 }
    skipped_count { 0 }
    error_count { 0 }
    error_log { [] }

    trait :completed do
      status { :completed }
      total_rows { 50 }
      imported_count { 48 }
      skipped_count { 2 }
      completed_at { Time.current }
    end

    trait :previewing do
      status { :previewing }
      preview_data { [{ date: "2026-03-01", description: "Test", amount_cents: -500 }] }
    end

    trait :ofx do
      file_name { "statement.ofx" }
      file_type { :ofx }
    end
  end
end
