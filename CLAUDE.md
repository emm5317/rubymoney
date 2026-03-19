# Finance Reconciler — CLAUDE.md

## What This Is

Personal finance app: import bank/credit card statements, categorize transactions, track budgets, view dashboards. Single-user, self-hosted.

**Stack:** Rails 7.2 · Ruby 3.3 · PostgreSQL 16 · Hotwire (Turbo + Stimulus) · Tailwind CSS · good_job · Devise · Chart.js · Pagy

## Project Status

**Phase 1 complete** — Foundation (models, migrations, controllers, views, auth, seeds, test setup). See BUILD_PLAN.md for full roadmap.

**Phase 2 complete** — Import pipeline (CSV + OFX adapters, ImportProcessor, Categorizer, preview/confirm flow, deduplication). See BUILD_PLAN.md for full roadmap.

**Phase 3 complete** — Categorization, tags, manual entry, transfer detection, inline editing, bulk operations, request specs for all Phase 3 controllers.

**Phase 4 complete** — Dashboard charts (category spending, monthly trends, budget progress, tag spending, period navigation, drilldown, income vs. expenses area chart, net worth over time, top merchants, accounts overview with net worth total, BalanceSnapshotJob daily cron).

**Not yet built:** PDF import (Phase 5), merchant normalization, recurring detection, export, pg_search, automated backup (Phase 6).

## Development Environment

**Ruby runs inside Docker** — there is no local Ruby installation. Always use `docker compose` to start the app, run Rails commands, and execute tests. Do NOT attempt `bin/rails` or `bundle exec` directly on the host.

## Key Commands

```bash
docker compose up -d --build                    # Start app (port 3030)
docker compose exec web bin/rails db:seed       # Seed default categories + dev user
docker compose exec web bin/rails console       # Rails console
docker compose logs -f web                      # View app logs
```

### Running Tests

The production Docker image does not include test gems. Use `docker-compose.test.yml` to run RSpec:

```bash
# First run (builds test image, creates DB, precompiles assets, runs specs):
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test

# Subsequent runs (reuse built image, run specific specs):
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/requests/"

# Rebuild test image after Gemfile changes:
docker compose -f docker-compose.yml -f docker-compose.test.yml build test
```

**Dev login:** admin@example.com / password123
**Job dashboard:** http://localhost:3030/good_job (development only)

## Architecture Rules

### Money
- ALL monetary values are integer cents (`amount_cents`, `balance_cents`, `current_balance_cents`). Never use floats for storage.
- `Transaction#amount` and `Account#balance` are virtual accessors that convert cents to dollars for display. Forms submit via `amount` (dollars) which the setter converts to cents.

### Naming Conflicts with ActiveRecord
- `TransactionTag` uses `belongs_to :financial_transaction` (not `:transaction`) — AR reserves `#transaction`.
- `Rule#match_field` enum uses `amount_field` (not `amount`) — AR reserves `#amount` in some contexts.
- When adding new models/associations, check for AR method name conflicts.

### Import Pipeline
- Adapter pattern: `app/services/importers/base_adapter.rb` defines the interface.
- `Importers::CsvAdapter` — parses CSV files, auto-detects column mappings, handles currency symbols/parentheses/separate debit-credit columns.
- `Importers::OfxAdapter` — parses OFX/QFX files using `ofx` gem, uses FITID for deduplication.
- `ImportProcessor` orchestrates the flow: parse → preview → confirm → categorize.
- Deduplication: SHA256 fingerprint for CSV, FITID for OFX/QFX. Unique index on `[account_id, source_fingerprint]`.
- Smart preview: ImportProfile learns column mappings, date formats, description corrections per account+institution.
- Flow: upload → parse preview (transactions shown in table with duplicate detection) → user confirms → persist + auto-categorize.

### Categorization
- `Categorizer` service applies `Rule` records in priority order (highest priority wins).
- `#categorize(txn)` — single transaction. `#categorize_batch(txns)` — bulk. `#apply_retroactive` — all uncategorized.
- Rules match on `description`, `normalized_desc`, or `amount_field` with types: `contains`, `exact`, `starts_with`, `regex`, `gt`, `lt`, `between`.
- Auto-categorization runs automatically after import confirm.

### Background Jobs
- good_job with PostgreSQL backend. No Redis anywhere.
- Imports will run as background jobs with Turbo Stream progress updates.
- `good_job` runs inline in development (no separate process needed).

## Data Model Quick Reference

```
User -< Account -< Transaction >- Category
                      |    |           |
                      |    |       Budget (per month)
                      |    |
                      |    >- TransactionTag >- Tag
                      |
                  Import    ImportProfile (learns per account)

Transaction.transfer_pair_id -> Transaction (self-ref)
Account -< AccountBalance (historical snapshots)
```

### Key Scopes on Transaction
- `.uncategorized` — `category_id IS NULL`
- `.non_transfer` — `is_transfer = false`
- `.for_month(date)` — within calendar month
- `.for_date_range(start, end)` — date range
- `.tagged_with(tag)` — by tag id
- `.debits` / `.credits` — by transaction type
- `.recent` — `ORDER BY date DESC`

### Key Scopes on Other Models
- `Category.sorted` — by position
- `Category.top_level` — no parent
- `Rule.enabled` / `Rule.by_priority`
- `Tag.sorted` — by name
- `Budget.for_month(month, year)` / `Budget.for_date(date)`
- `AccountBalance.chronological` / `.recent_first`

## Conventions

### Code Organization
- **Service objects** go in `app/services/`. Import adapters in `app/services/importers/`.
- **No API mode** — full Rails with server-rendered HTML + Hotwire for interactivity.
- **Turbo Frames** for partial page updates (inline editing, modal-like flows).
- **Stimulus controllers** for JS behavior (charts, form enhancements). No React/Vue.
- **Chart.js** rendered via Stimulus controllers (not Chartkick).

### Controllers
- All controllers require `authenticate_user!`.
- Transaction queries always scope through `current_user` via: `Transaction.joins(:account).where(accounts: { user_id: current_user.id })`.
- Account queries scope via `current_user.accounts`.
- Categories, rules, tags are global (single-user app) — no user scoping needed.
- Budgets are global (single-user) — document if multi-user is added later.
- Forms that reference accounts must pass `@accounts = current_user.accounts` from controller (never `Account.all` in views).

### Views
- **Tailwind CSS** — consistent card layout: `max-w-7xl mx-auto px-4 py-8`, white bg with shadow.
- Tables use alternating row colors, indigo action links.
- Delete actions use `button_to` (not `link_to method: :delete`) for Turbo compatibility.
- Pagy pagination via `<%== pagy_nav(@pagy) %>` — include on any list that could grow.

### Testing
- **RSpec** with FactoryBot. Factories in `spec/factories/`.
- Devise test helpers included for request and system specs.
- Model specs for all 10 models. Service specs for CsvAdapter, Categorizer, ImportProcessor.
- Controller/request/system specs not yet written.
- Run with `bundle exec rspec`. Test DB: `rubymoney_test`.

### Database
- PostgreSQL only. No SQLite, no MySQL.
- All migrations use `bigint` for monetary columns.
- Deduplication index: `[account_id, source_fingerprint]` unique on transactions.
- Budget uniqueness: `[category_id, month, year]`.
- ImportProfile uniqueness: `[account_id, institution]`.

## File Map

```
app/
  controllers/    # 9 controllers (application, dashboard, accounts, transactions,
                  #   categories, budgets, rules, tags, imports)
  models/         # 11 models (user, account, transaction, category, budget,
                  #   tag, transaction_tag, rule, import, import_profile, account_balance)
  views/          # 7 resource dirs + layouts + dashboard + shared
  services/       # ImportProcessor, Categorizer, importers/ (BaseAdapter, CsvAdapter, OfxAdapter)
  helpers/        # ApplicationHelper with Pagy::Frontend
  jobs/           # ImportProcessJob (parse + confirm imports)
  javascript/     # Importmap + Stimulus (controllers Phase 4+)
config/
  routes.rb       # All routes defined, some controller actions are stubs
  initializers/   # devise.rb, pagy.rb, standard Rails
db/
  schema.rb       # 12 tables (including good_job tables)
  seeds.rb        # 15 categories + dev user
  migrate/        # All Phase 1 migrations
spec/
  models/         # 10 model specs
  services/       # CsvAdapter, Categorizer, ImportProcessor specs
  factories/      # 10 factory files
```

## What NOT to Do

- Never store money as floats or decimals. Always integer cents.
- Never use `Account.all` or `Transaction.all` in views — scope to current_user.
- Never use `link_to ... method: :delete` — use `button_to` for Turbo.
- Never add `:transaction` as an association name — AR conflict. Use `:financial_transaction`.
- Never add `:amount` as an enum value — AR conflict. Use `:amount_field`.
- Never require Redis — use PostgreSQL-backed good_job for everything.
- Never add Chartkick — Chart.js via Stimulus controllers only.
