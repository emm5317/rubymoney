# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_03_19_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_balances", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "date", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.integer "source", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "date"], name: "index_account_balances_on_account_id_and_date", unique: true
    t.index ["account_id"], name: "index_account_balances_on_account_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "account_type", default: 0, null: false
    t.string "institution"
    t.string "currency", default: "USD", null: false
    t.integer "source_type", default: 0, null: false
    t.string "plaid_account_id"
    t.bigint "current_balance_cents", default: 0
    t.datetime "last_imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_accounts_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.bigint "amount_cents", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "month", "year"], name: "index_budgets_on_category_id_and_month_and_year", unique: true
    t.index ["category_id"], name: "index_budgets_on_category_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "color"
    t.string "icon"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "import_profiles", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "institution"
    t.jsonb "column_mapping", default: {}
    t.string "date_format"
    t.jsonb "description_corrections", default: {}
    t.string "amount_format"
    t.integer "skip_header_rows", default: 1
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "institution"], name: "index_import_profiles_on_account_id_and_institution", unique: true
    t.index ["account_id"], name: "index_import_profiles_on_account_id"
  end

  create_table "imports", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "file_name", null: false
    t.integer "file_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "total_rows", default: 0
    t.integer "imported_count", default: 0
    t.integer "skipped_count", default: 0
    t.integer "error_count", default: 0
    t.jsonb "error_log", default: []
    t.jsonb "preview_data"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_imports_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_imports_on_account_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "category_id"
    t.string "title", null: false
    t.string "description_pattern", null: false
    t.bigint "average_amount_cents", null: false
    t.bigint "last_amount_cents"
    t.integer "frequency", default: 0, null: false
    t.float "confidence", default: 0.0
    t.integer "occurrence_count", default: 0
    t.date "last_seen_date"
    t.date "next_expected_date"
    t.integer "status", default: 0, null: false
    t.boolean "user_confirmed", default: false
    t.boolean "user_dismissed", default: false
    t.float "amount_variance", default: 0.0
    t.integer "average_interval_days"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "description_pattern"], name: "idx_recurring_on_account_desc_pattern", unique: true
    t.index ["account_id"], name: "index_recurring_transactions_on_account_id"
    t.index ["category_id"], name: "index_recurring_transactions_on_category_id"
    t.index ["next_expected_date"], name: "index_recurring_transactions_on_next_expected_date"
    t.index ["status"], name: "index_recurring_transactions_on_status"
  end

  create_table "rules", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.integer "match_field", default: 0, null: false
    t.integer "match_type", default: 0, null: false
    t.string "match_value", null: false
    t.string "match_value_upper"
    t.integer "priority", default: 0, null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "apply_retroactive", default: false, null: false
    t.jsonb "auto_tag_ids", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_rules_on_category_id"
    t.index ["enabled"], name: "index_rules_on_enabled"
    t.index ["priority"], name: "index_rules_on_priority"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "transaction_tags", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_on_transaction_id_and_tag_id", unique: true
    t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "import_id"
    t.bigint "category_id"
    t.bigint "transfer_pair_id"
    t.bigint "merchant_id"
    t.date "date", null: false
    t.date "posted_date"
    t.string "description", null: false
    t.string "normalized_desc"
    t.bigint "amount_cents", null: false
    t.integer "transaction_type", default: 0, null: false
    t.boolean "is_transfer", default: false, null: false
    t.integer "status", default: 0, null: false
    t.text "memo"
    t.string "source_type", default: "manual", null: false
    t.string "source_fingerprint"
    t.boolean "auto_categorized", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "date"], name: "index_transactions_on_account_id_and_date"
    t.index ["account_id", "source_fingerprint"], name: "idx_transactions_on_account_fingerprint", unique: true, where: "(source_fingerprint IS NOT NULL)"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["import_id"], name: "index_transactions_on_import_id"
    t.index ["merchant_id"], name: "index_transactions_on_merchant_id"
    t.index ["normalized_desc"], name: "index_transactions_on_normalized_desc"
    t.index ["transfer_pair_id"], name: "index_transactions_on_transfer_pair_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "account_balances", "accounts"
  add_foreign_key "accounts", "users"
  add_foreign_key "budgets", "categories"
  add_foreign_key "import_profiles", "accounts"
  add_foreign_key "imports", "accounts"
  add_foreign_key "recurring_transactions", "accounts"
  add_foreign_key "recurring_transactions", "categories"
  add_foreign_key "rules", "categories"
  add_foreign_key "transaction_tags", "tags"
  add_foreign_key "transaction_tags", "transactions"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "imports"
end
