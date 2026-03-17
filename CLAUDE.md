# Finance Reconciler

Personal finance app built with Rails 7.2, PostgreSQL, Hotwire (Turbo + Stimulus), good_job, Devise.

## Architecture
- Import pipeline uses adapter pattern: `app/services/importers/`
- Each bank/file format has its own adapter implementing `BaseAdapter#parse`
- Supports CSV, OFX/QFX, and PDF imports
- Smart import preview: parsed data shown for review before committing
- ImportProfile model learns column mappings, date formats, and description corrections per account
- All amounts stored as integer cents (amount_cents), never floats
- Deduplication via SHA256 fingerprint (CSV/PDF) or FITID (OFX/QFX)
- Categorization via priority-ordered rules in `Categorizer` service
- Flexible tagging system via has_many :through (TransactionTag uses `financial_transaction` association name to avoid AR conflict)
- Transfer detection: auto-matches inter-account transfers, excludes from income/expense totals
- Per-month budgets in dedicated `budgets` table
- Background jobs via good_job (PostgreSQL-backed, no Redis)
- Authentication via Devise (single user)
- Account balance tracking and net worth over time

## Conventions
- Service objects in `app/services/`
- No API mode — full Rails with Hotwire
- Turbo Frames for partial updates, Stimulus for JS behavior
- Chart.js rendered via Stimulus controllers (not Chartkick)
- RSpec for testing, FactoryBot for fixtures
- Tailwind CSS for styling
- Pagy for pagination

## Key scopes
- `Transaction.uncategorized` — no category assigned
- `Transaction.non_transfer` — excludes inter-account transfers
- `Transaction.for_month(date)` — transactions within a calendar month
- `Transaction.tagged_with(tag)` — filtered by tag

## Key commands
- `bin/rails server` — start dev server (good_job runs inline in dev by default)
- `bin/rails db:seed` — seed default categories and dev user
- `bundle exec rspec` — run tests
- `GoodJob::Engine` mounted at `/good_job` in development for job dashboard
- Dev login: admin@example.com / password123

## Known conventions
- `TransactionTag` uses `belongs_to :financial_transaction` (not `:transaction`) to avoid AR method conflict
- Rule `match_field` enum uses `amount_field` (not `amount`) for same reason
