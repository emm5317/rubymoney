# Codex Prompt — Phase 6: Polish, Search, Export & Backup

## Context

This is a personal finance Rails app (single-user, self-hosted). Phases 1–4 are complete: models, import pipeline (CSV + OFX), categorization rules, tags, dashboard with Chart.js, budgets, inline editing via Turbo Frames. Phase 5 (PDF import) is deferred. Phase 6 adds production-quality polish.

**Stack:** Rails 7.2 · Ruby 3.3 · PostgreSQL 16 · Hotwire (Turbo + Stimulus) · Tailwind CSS · good_job · Devise · Chart.js · Pagy · RSpec + FactoryBot

**Environment:** Ruby runs inside Docker only. App container is production-mode. Test container uses `docker-compose.test.yml` overlay. No local Ruby.

---

## What to Build (Phase 6)

Build these features in order. After each feature, write RSpec request specs following the pattern in `spec/requests/dashboard_spec.rb`. Run tests via `docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test`.

### 1. Transaction Full-Text Search (pg_search)

Add `pg_search` gem to Gemfile. Add `PgSearch::Model` to `Transaction` model with `pg_search_scope :search_by_description, against: [:description, :normalized_desc, :memo]`. Add a search text input to `app/views/transactions/_filters.html.erb`. Wire it into `TransactionsController#index` — when `params[:q]` is present, chain `.search_by_description(params[:q])` onto the query scope. Search should work alongside existing filters (account, category, type, date range).

**Key files:** `app/models/transaction.rb`, `app/controllers/transactions_controller.rb`, `app/views/transactions/_filters.html.erb`, `Gemfile`

### 2. Recurring Transaction Detection

Create `app/services/recurring_detector.rb` service. Logic: group transactions by `normalized_desc`, find descriptions that appear in 3+ distinct months with similar amounts (within 20% tolerance). Return array of `{ description:, avg_amount_cents:, frequency:, last_date:, count: }`. Add `is_recurring` boolean column to transactions (migration). Add a `RecurringController` with `index` action showing detected recurring transactions grouped by description. Add route `resources :recurring, only: [:index]`. Add "Recurring" link to the nav bar. Do NOT auto-flag transactions — just surface the detection for the user to review.

**Key files:** `app/services/recurring_detector.rb`, `app/controllers/recurring_controller.rb`, `app/views/recurring/index.html.erb`, `config/routes.rb`, migration for `is_recurring`

### 3. CSV Export

Add `export` collection action to `TransactionsController`. When hit with `.csv` format, stream a CSV of the current filtered transaction set (respecting all active filters: account, category, type, date range, search). Columns: Date, Description, Amount, Type, Category, Account, Tags, Status, Memo. Add an "Export CSV" button to the transactions index page that links to the same URL with `.csv` extension. Use Ruby's built-in `csv` library (already in Gemfile). Set `Content-Disposition: attachment` header.

**Key files:** `app/controllers/transactions_controller.rb`, `app/views/transactions/index.html.erb`, `config/routes.rb`

### 4. Automated Database Backup

Create `lib/tasks/backup.rake` with task `db:backup` that runs `pg_dump` with timestamped filename into `db/backups/` directory (create it if missing). Create `app/jobs/database_backup_job.rb` that calls the rake task. Add to good_job cron in `config/application.rb`: daily at 3 AM. Add rotation: delete backups older than 30 days. The `DATABASE_URL` env var provides connection info — parse it for pg_dump args.

**Key files:** `lib/tasks/backup.rake`, `app/jobs/database_backup_job.rb`, `config/application.rb`

### 5. Data Cleanup: Merge Categories

Add `merge` action to `CategoriesController` (POST). Accepts `source_id` and `target_id`. Reassigns all transactions from source category to target, reassigns all rules, reassigns all budgets (summing amounts if both exist for same month/year), then deletes source. Add a "Merge into..." dropdown on the categories index. Add confirmation via `data-turbo-confirm`.

**Key files:** `app/controllers/categories_controller.rb`, `app/views/categories/index.html.erb`, `config/routes.rb`

### 6. Data Cleanup: Merge Tags

Same pattern as category merge. Add `merge` action to `TagsController`. Reassigns all transaction_tags from source to target (skip duplicates via `find_or_create_by`), then deletes source. Add merge UI to tags index.

**Key files:** `app/controllers/tags_controller.rb`, `app/views/tags/index.html.erb`, `config/routes.rb`

---

## Critical Rules

Read CLAUDE.md and `app/views/CLAUDE.md` before writing any code. Key rules:

- **Money:** Always integer cents. Never floats. `amount_cents` columns are `bigint`.
- **Scoping:** Transaction queries MUST go through `current_user` via `Transaction.joins(:account).where(accounts: { user_id: current_user.id })`. Never use `Transaction.all` in views.
- **Delete buttons:** Always `button_to` with `method: :delete`, never `link_to method: :delete`.
- **Associations:** Use `:financial_transaction` (not `:transaction`) for TransactionTag. Use `:amount_field` (not `:amount`) for Rule enum.
- **No Redis.** good_job uses PostgreSQL.
- **No Chartkick.** Chart.js via Stimulus only.
- **Tailwind CSS** — follow the design system in `app/views/CLAUDE.md` exactly: card styles, table styles, button classes, form input classes, empty states.
- **Pagy** for pagination on any list view.
- **RSpec** with FactoryBot. Factories in `spec/factories/`. Use `sign_in user` from Devise helpers. Test pattern: `let(:user) { create(:user) }; before { sign_in user }`.

## Existing Patterns to Follow

- **Service objects** in `app/services/` — see `Categorizer`, `TransferMatcher`, `ImportProcessor` for patterns.
- **Inline editing** via Stimulus `inline_edit_controller.js` + Turbo Frames.
- **Bulk operations** via Stimulus `bulk_select_controller.js`.
- **Flash messages:** `redirect_to path, notice: "Success message."` — layout handles rendering.
- **Form pattern:** `form_with(model: ..., class: "space-y-6")` inside `bg-white shadow rounded-lg p-6` card.
- **Table pattern:** `bg-white shadow rounded-lg overflow-hidden` wrapping `min-w-full divide-y divide-gray-200` table with alternating row colors.
- **Helpers:** `format_cents(cents)` for money display, `category_label(category)` for category with color dot.

## Database Schema Notes

- `transactions` table has: `normalized_desc` (string, indexed), `merchant_id` (bigint FK, currently unused), `source_fingerprint` (string, unique per account), `auto_categorized` (boolean), `is_transfer` (boolean).
- `categories` table has: `parent_id` (self-ref), `color`, `icon`, `position`. Unique index on `name`.
- `tags` table has: `name` (unique), `color`.
- `transaction_tags` join table with unique index on `[transaction_id, tag_id]`.
- `budgets` table has unique index on `[category_id, month, year]`.
- good_job cron is configured in `config/application.rb` under `config.good_job.cron`. See `BalanceSnapshotJob` for existing cron pattern.

## File Structure

```
app/controllers/    — 9 controllers + ApplicationController
app/models/         — 11 models
app/views/          — 7 resource dirs + layouts + dashboard + shared
app/services/       — ImportProcessor, Categorizer, TransferMatcher, importers/
app/helpers/        — ApplicationHelper (format_cents, category_label, etc.)
app/jobs/           — ImportProcessJob, BalanceSnapshotJob
app/javascript/     — Stimulus controllers (chart, drilldown, bulk_select, inline_edit)
config/routes.rb    — All routes defined
spec/requests/      — dashboard, budgets, transactions, categories, tags, rules specs
spec/services/      — transfer_matcher, categorizer, csv_adapter, import_processor specs
spec/factories/     — 10 factory files
```

## After All Features

Update `CLAUDE.md` project status to mark Phase 6 as complete. Update the file map if new controllers/models were added. Update `docs/dev-cheatsheet.md` with any new commands (e.g., `db:backup`).
