# Personal Finance Reconciler — Build Plan

## Project Overview

A Rails 7.2+ application for importing bank and credit card statements (CSV, OFX/QFX, PDF), categorizing transactions via user-defined rules and tags, tracking account balances, and visualizing monthly spending through interactive dashboards. Built with Hotwire (Turbo + Stimulus) for a reactive UI without heavy JavaScript. Designed for single-user use initially, architected for future Plaid integration.

**Stack:** Ruby 3.3+ · Rails 7.2+ · PostgreSQL 16 · Hotwire (Turbo + Stimulus) · good_job · Devise · Chart.js

**Deployment target:** Local development initially, DigitalOcean droplet when ready

---

## Architecture Principles

1. **Import-agnostic normalization.** Every data source (CSV, OFX/QFX, PDF, future Plaid) produces the same canonical `Transaction` record. Source-specific parsing is isolated behind an adapter interface so adding Plaid later is a new adapter, not a refactor.
2. **Convention-first Rails.** Lean into Rails opinions — RESTful resources, ActiveRecord callbacks where appropriate, concerns for shared behavior. Resist the urge to over-abstract early.
3. **Hotwire over SPA.** Turbo Frames for inline editing and partial page updates. Turbo Streams for real-time feedback during imports. Stimulus controllers for lightweight JS behavior (chart rendering, rule builder UI). No React, no build pipeline complexity.
4. **Background-first imports.** All file parsing runs in good_job (PostgreSQL-backed). The UI shows progress via Turbo Streams. This keeps request/response cycles fast and handles large statements gracefully.
5. **Cents, not floats.** All monetary values stored as integer cents. No floating-point math anywhere in the money path.
6. **Zero-dependency queue.** good_job uses PostgreSQL as its backend — no Redis to install, configure, or monitor. One less moving part in dev and production.

---

## Data Model

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   accounts   │────<│   transactions   │>────│  categories  │
└─────────────┘     └──────────────────┘     └─────────────┘
                           │    │
┌─────────────┐            │    │             ┌──────────────┐
│   imports    │────────────┘    │        ┌───<│    rules     │
└─────────────┘                 │        │    └──────────────┘
                                │        │
                           ┌────┘   categories
                           │
               ┌───────────┴────────────┐
               │  transaction_tags (join)│
               └───────────┬────────────┘
                           │
                    ┌──────┴──────┐
                    │    tags      │
                    └─────────────┘

┌──────────────────┐
│ account_balances  │  ← daily/monthly balance snapshots
└──────────────────┘
```

### users (Devise)

| Column                 | Type      | Notes                          |
| ---------------------- | --------- | ------------------------------ |
| id                     | bigint PK |                                |
| email                  | string    | Devise default                 |
| encrypted_password     | string    | Devise default                 |
| remember_created_at    | datetime  | Devise rememberable            |
| sign_in_count          | integer   | Devise trackable               |
| current_sign_in_at     | datetime  | Devise trackable               |
| last_sign_in_at        | datetime  | Devise trackable               |
| current_sign_in_ip     | string    | Devise trackable               |
| last_sign_in_ip        | string    | Devise trackable               |
| created_at             | datetime  |                                |
| updated_at             | datetime  |                                |

### accounts

| Column           | Type      | Notes                                         |
| ---------------- | --------- | --------------------------------------------- |
| id               | bigint PK |                                               |
| user_id          | bigint FK |                                               |
| name             | string    | "Chase Sapphire", "Schwab Checking"           |
| account_type     | enum      | checking, savings, credit_card, investment    |
| institution      | string    | "Chase", "Schwab" — future FK to institutions |
| currency         | string    | Default "USD"                                 |
| source_type      | enum      | manual, csv, ofx, pdf, plaid (future)         |
| plaid_account_id | string    | Nullable — reserved for future Plaid linkage  |
| current_balance_cents | bigint | Latest known balance                        |
| last_imported_at | datetime  |                                               |
| created_at       | datetime  |                                               |
| updated_at       | datetime  |                                               |

### transactions

| Column             | Type      | Notes                                        |
| ------------------ | --------- | -------------------------------------------- |
| id                 | bigint PK |                                              |
| account_id         | bigint FK |                                              |
| import_id          | bigint FK | Nullable — manual entries have no import     |
| category_id        | bigint FK | Nullable until categorized                   |
| date               | date      | Transaction date                             |
| posted_date        | date      | Nullable — when it cleared                   |
| description        | string    | Raw description from statement               |
| normalized_desc    | string    | Cleaned/normalized version for rule matching |
| amount_cents       | bigint    | Store as integer cents, never float          |
| transaction_type   | enum      | debit, credit                                |
| status             | enum      | pending, cleared, reconciled                 |
| memo               | text      | User notes                                   |
| source_type        | string    | csv, ofx, pdf, plaid, manual                 |
| source_fingerprint | string    | SHA256 of raw row — deduplication key        |
| auto_categorized   | boolean   | Default false — tracks rule vs. manual       |
| created_at         | datetime  |                                              |
| updated_at         | datetime  |                                              |

**Indexes:** composite unique on `[account_id, source_fingerprint]` for dedup. Index on `[account_id, date]`, `[category_id]`, `[normalized_desc]`.

### categories

| Column       | Type      | Notes                                     |
| ------------ | --------- | ----------------------------------------- |
| id           | bigint PK |                                           |
| name         | string    | "Groceries", "Dining", "Utilities"        |
| parent_id    | bigint FK | Self-referential — supports subcategories |
| color        | string    | Hex color for charts                      |
| icon         | string    | Optional icon identifier                  |
| budget_cents | bigint    | Optional monthly budget target            |
| position     | integer   | Sort order                                |
| created_at   | datetime  |                                           |
| updated_at   | datetime  |                                           |

**Seed data:** Start with ~15 standard categories (Housing, Utilities, Groceries, Dining, Transport, Insurance, Healthcare, Entertainment, Subscriptions, Shopping, Travel, Education, Gifts, Income, Transfers).

### tags

| Column     | Type      | Notes                                          |
| ---------- | --------- | ---------------------------------------------- |
| id         | bigint PK |                                                |
| name       | string    | "vacation", "tax-deductible", "reimbursable"   |
| color      | string    | Hex color for UI badges                        |
| created_at | datetime  |                                                |
| updated_at | datetime  |                                                |

**Unique index** on `name`.

### transaction_tags (join table)

| Column         | Type      | Notes |
| -------------- | --------- | ----- |
| id             | bigint PK |       |
| transaction_id | bigint FK |       |
| tag_id         | bigint FK |       |

**Unique composite index** on `[transaction_id, tag_id]`.

### rules

| Column            | Type      | Notes                                                   |
| ----------------- | --------- | ------------------------------------------------------- |
| id                | bigint PK |                                                         |
| category_id       | bigint FK |                                                         |
| match_field       | enum      | description, normalized_desc, amount                    |
| match_type        | enum      | contains, exact, starts_with, regex, gt, lt, between    |
| match_value       | string    | The pattern or value to match                           |
| match_value_upper | string    | For "between" amount ranges                             |
| priority          | integer   | Higher priority rules win conflicts                     |
| enabled           | boolean   | Default true                                            |
| apply_retroactive | boolean   | When created, also apply to existing uncategorized txns |
| auto_tag_ids      | jsonb     | Optional — also apply these tags when rule matches      |
| created_at        | datetime  |                                                         |
| updated_at        | datetime  |                                                         |

### imports

| Column         | Type      | Notes                                  |
| -------------- | --------- | -------------------------------------- |
| id             | bigint PK |                                        |
| account_id     | bigint FK |                                        |
| file_name      | string    | Original filename                      |
| file_type      | enum      | csv, ofx, qfx, pdf                    |
| status         | enum      | pending, processing, completed, failed |
| total_rows     | integer   | Total rows detected                    |
| imported_count | integer   | Successfully imported                  |
| skipped_count  | integer   | Duplicates skipped                     |
| error_count    | integer   | Rows that failed parsing               |
| error_log      | jsonb     | Array of {row, error} for failed rows  |
| started_at     | datetime  |                                        |
| completed_at   | datetime  |                                        |
| created_at     | datetime  |                                        |
| updated_at     | datetime  |                                        |

**File storage:** ActiveStorage attachment on Import for the original file. Local disk in dev, future migration to Backblaze B2 or DO Spaces.

### account_balances

| Column       | Type      | Notes                                      |
| ------------ | --------- | ------------------------------------------ |
| id           | bigint PK |                                            |
| account_id   | bigint FK |                                            |
| date         | date      | Balance as of this date                    |
| balance_cents| bigint    | Balance in cents                           |
| source       | enum      | calculated, imported, manual               |
| created_at   | datetime  |                                            |
| updated_at   | datetime  |                                            |

**Unique index** on `[account_id, date]`. Used for net worth tracking and reconciliation against statement ending balances.

---

## Import Architecture

### The Adapter Pattern

```ruby
# app/services/importers/base_adapter.rb
module Importers
  class BaseAdapter
    def initialize(raw_content, account:)
      @raw_content = raw_content
      @account = account
    end

    # Returns array of normalized hashes:
    # { date:, posted_date:, description:, amount_cents:, transaction_type: }
    def parse
      raise NotImplementedError
    end

    private

    def normalize_description(raw)
      raw.gsub(/\s+/, ' ').strip.gsub(/\d{4}\*+\d{4}/, '').strip
    end

    def to_cents(amount_string)
      (BigDecimal(amount_string.gsub(/[,$]/, '')) * 100).to_i
    end
  end
end

# app/services/importers/chase_csv_adapter.rb
# app/services/importers/schwab_csv_adapter.rb
# app/services/importers/generic_csv_adapter.rb
# app/services/importers/ofx_adapter.rb          ← OFX/QFX support
# app/services/importers/pdf_adapter.rb           ← Phase 4
# app/services/importers/plaid_adapter.rb         ← future
```

### Auto-Detection Strategy

Each bank's CSV has recognizable headers. OFX/QFX files are identified by extension and XML structure. Build a detector that inspects the first few rows:

```ruby
# app/services/importers/format_detector.rb
module Importers
  class FormatDetector
    SIGNATURES = {
      chase_credit:   ['Transaction Date', 'Post Date', 'Description', 'Category', 'Type', 'Amount'],
      chase_checking: ['Details', 'Posting Date', 'Description', 'Amount', 'Type', 'Balance', 'Check or Slip #'],
      schwab_checking: ['Date', 'Type', 'Check #', 'Description', 'Withdrawal (-)', 'Deposit (+)', 'RunningBalance'],
      amex:           ['Date', 'Description', 'Amount', 'Extended Details', 'Appears On Your Statement As'],
      generic:        :fallback
    }.freeze

    def self.detect(file_name, headers_or_content)
      return :ofx if file_name.match?(/\.(ofx|qfx)$/i)
      return :pdf if file_name.match?(/\.pdf$/i)
      # Match CSV against known signatures, fall back to generic
    end
  end
end
```

### OFX/QFX Import

OFX (Open Financial Exchange) and QFX (Quicken Financial Exchange) are structured XML-based formats supported by most US banks. They contain typed transaction data including FITID (Financial Institution Transaction ID) — a unique identifier that makes deduplication trivial.

```ruby
# app/services/importers/ofx_adapter.rb
module Importers
  class OfxAdapter < BaseAdapter
    def parse
      ofx = OFX(StringIO.new(@raw_content))
      ofx.account.transactions.map do |txn|
        {
          date: txn.posted_at.to_date,
          description: txn.memo || txn.name,
          amount_cents: (txn.amount * 100).to_i,
          transaction_type: txn.amount.negative? ? :debit : :credit,
          source_fingerprint: Digest::SHA256.hexdigest("#{@account.id}:#{txn.fit_id}")
        }
      end
    end
  end
end
```

**Advantages over CSV:** Standardized format, typed fields, built-in transaction IDs (FITID), account balance included, no column mapping needed.

### CSV Auto-Detection

The generic adapter handles standard two-column (date + amount) or three-column (date + debit + credit) formats with user-assisted column mapping on first import.

### Deduplication

Generate `source_fingerprint` as SHA256 of `"#{account_id}:#{date}:#{description}:#{amount_cents}"` for CSV imports, or `"#{account_id}:#{fit_id}"` for OFX (using the bank's unique transaction ID). On import, skip any transaction whose fingerprint already exists for that account. Track skip count on the Import record.

**Edge case:** Some banks produce identical rows for genuinely different transactions (two $5.00 Starbucks charges same day). Handle by appending a sequence counter to the fingerprint when exact duplicates are detected within the same import file.

---

## Phase Breakdown

### Phase 1 — Foundation (Estimated: 3-4 sessions)

**Goal:** Rails app scaffolded, data model migrated, authentication working, basic CSV and OFX import working.

**Tasks:**

- [ ] `rails new finance_reconciler --database=postgresql --css=tailwind --skip-jbuilder`
- [ ] Configure PostgreSQL (dev/test databases)
- [ ] Install and configure Devise (single user, registration disabled after initial setup)
- [ ] Generate models: Account, Transaction, Category, Rule, Import, Tag, TransactionTag, AccountBalance
- [ ] Write and run migrations with all indexes and constraints
- [ ] Seed default categories
- [ ] Implement `Importers::FormatDetector` and one concrete CSV adapter (Chase credit)
- [ ] Implement `Importers::GenericCsvAdapter` as fallback with column mapping
- [ ] Implement `Importers::OfxAdapter` for OFX/QFX files
- [ ] Build `ImportsController` — file upload form (accepts .csv, .ofx, .qfx), create action dispatches background job
- [ ] `ImportJob` — parses file, creates transactions, updates import stats
- [ ] Basic import status page showing counts
- [ ] Install and configure good_job (PostgreSQL-backed job queue)
- [ ] Transaction index view with basic filtering (account, date range) and Pagy pagination
- [ ] RSpec setup with FactoryBot, sample CSV/OFX fixtures

**Key gems this phase:** devise, good_job, ofx, pagy, smarter_csv, rspec-rails, factory_bot_rails, faker

**Testing focus:** Model validations, adapter parsing (unit tests with fixture CSVs and OFX files), deduplication logic, OFX FITID-based dedup.

---

### Phase 2 — Categorization Engine & Tags (Estimated: 2-3 sessions)

**Goal:** Rules-based auto-categorization with manual override. Tag management. Creating a rule from a transaction.

**Tasks:**

- [ ] `RulesController` — CRUD for categorization rules
- [ ] `Categorizer` service — applies rules in priority order to a transaction, also applies auto-tags from matching rules
- [ ] Hook categorizer into import pipeline (auto-categorize on import)
- [ ] "Categorize" action on transaction show/index — dropdown to assign category manually
- [ ] "Create rule from this" action — pre-fills rule form from transaction's description
- [ ] Retroactive application — when a new rule is created with `apply_retroactive`, run a background job to categorize matching uncategorized transactions
- [ ] Bulk categorization — select multiple transactions, assign category
- [ ] Uncategorized transactions filter/view (the "inbox" pattern)
- [ ] `TagsController` — CRUD for tags
- [ ] Tag assignment UI on transactions — multi-select tag picker (Stimulus controller with autocomplete)
- [ ] Bulk tagging — select multiple transactions, apply/remove tags
- [ ] Filter transactions by tag (in addition to existing filters)

**Key learning:** Rails enums, ActiveRecord scopes, service object patterns, form objects, Turbo Frame basics for inline category/tag assignment, has_many :through for tags.

**Testing focus:** Rule matching logic (contains, regex, amount ranges), priority resolution, retroactive application, tag assignment.

---

### Phase 3 — Hotwire-Powered Dashboard (Estimated: 3-4 sessions)

**Goal:** Interactive spending dashboard with Turbo Frames and Stimulus-driven Chart.js. Monthly/weekly views, category breakdowns, trend lines, balance tracking.

**Tasks:**

- [ ] `DashboardController` with configurable date range (default: current month)
- [ ] Monthly summary: total income, total expenses, net, by-category breakdown
- [ ] Stimulus Chart.js controller — reusable controller for rendering/updating charts
- [ ] Category spending bar chart (Stimulus + Chart.js)
- [ ] Spending trend line chart (last 6 months)
- [ ] Turbo Frame: clicking a category in the chart filters the transaction list below it (no full page reload)
- [ ] Turbo Frame: date range picker updates dashboard content via frame replacement
- [ ] Budget vs. actual — if `budget_cents` set on category, show progress bars
- [ ] Top merchants view — group by normalized_desc, rank by total spend
- [ ] Income vs. expenses over time (area chart)
- [ ] Account balances overview — current balance per account, total net worth
- [ ] Net worth over time chart (line chart from account_balances snapshots)
- [ ] `BalanceSnapshotJob` — daily job to record account balances to account_balances table
- [ ] Tag-based spending views (e.g., total vacation spending, tax-deductible expenses)

**Key learning:** Turbo Frames for partial page updates, Stimulus controllers for Chart.js integration, groupdate gem for time-series aggregation, presenter/decorator pattern.

**Testing focus:** Dashboard query performance (test with 10K+ transactions), correct aggregation math, Turbo Frame response rendering.

---

### Phase 4 — PDF Import (Estimated: 2-3 sessions)

**Goal:** Parse bank/credit card PDF statements into transactions using the same adapter interface.

**Tasks:**

- [ ] Evaluate PDF parsing: `pdf-reader` gem for text extraction, Tabula (via CLI wrapper) for table extraction
- [ ] Implement `Importers::PdfTextExtractor` — extracts raw text from PDF
- [ ] Implement `Importers::PdfTableParser` — identifies transaction tables in extracted text
- [ ] Build at least one bank-specific PDF adapter (Chase credit card statement)
- [ ] Generic PDF adapter with user-assisted field mapping for unknown formats
- [ ] Handle multi-page statements (transactions spanning page breaks)
- [ ] Error handling: flag rows that couldn't be parsed, show in import review
- [ ] Side-by-side import review: show extracted data next to PDF preview for verification
- [ ] Extract statement ending balance from PDF for reconciliation

**Key learning:** Ruby's text processing strengths (regex, StringScanner), working with external CLI tools from Ruby, more complex background job patterns.

**Edge cases:** PDF statements are notoriously inconsistent. Plan for ~80% automation with manual review for the rest. Don't over-invest in perfection here.

---

### Phase 5 — Polish & Export (Estimated: 2-3 sessions)

**Goal:** Production-quality UX, data export, reconciliation, and cleanup.

**Tasks:**

- [ ] Transaction search — full-text search on description with pg_search gem
- [ ] Bulk import — drag-and-drop multiple files at once (CSV, OFX, QFX)
- [ ] Export: monthly report to CSV
- [ ] Export: spending summary to PDF (Prawn gem)
- [ ] Recurring transaction detection — flag transactions that appear monthly with similar amounts
- [ ] Duplicate review — surface potential duplicates across imports for manual resolution
- [ ] Account reconciliation — compare running balance against imported statement balance, flag discrepancies
- [ ] Data cleanup tools — merge categories, bulk re-categorize, edit normalized descriptions
- [ ] Tag management — merge tags, bulk operations
- [ ] Mobile-responsive layout polish (Tailwind responsive utilities)
- [ ] Error handling and flash messages throughout
- [ ] System tests with Capybara for critical flows

**Key learning:** pg_search, Prawn PDF generation, Capybara system tests, Rails flash/redirect patterns, responsive Tailwind in Rails.

---

### Phase 6 — Future: Plaid Integration (Not in initial build)

**Architectural prep already in place:**

- `Account.source_type` enum includes `plaid`
- `Account.plaid_account_id` column reserved
- Adapter interface (`Importers::BaseAdapter`) accepts any source
- `Transaction.source_type` tracks provenance
- Import model can represent a Plaid sync as well as a file upload
- Balance tracking already built — Plaid just becomes another balance source

**When ready:**

- Add `plaid` gem
- Build `Importers::PlaidAdapter` implementing the same interface
- Add Plaid Link flow (Turbo Frame or Stimulus controller wrapping Plaid Link JS)
- Add `PlaidSyncJob` for scheduled pulls
- Everything downstream (categorization, tagging, dashboard, export) works unchanged

---

## Development Environment Setup

```bash
# Prerequisites
ruby --version    # 3.3+
rails --version   # 7.2+
psql --version    # 16+
# No Redis needed — good_job uses PostgreSQL

# Project init
rails new finance_reconciler \
  --database=postgresql \
  --css=tailwind \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-action-text

cd finance_reconciler

# Key gems to add to Gemfile
# --- Core ---
gem "good_job", "~> 4.0"       # PostgreSQL-backed job queue (no Redis)
gem "devise", "~> 4.9"          # Authentication
gem "pagy", "~> 9.0"            # Fast pagination
gem "groupdate"                  # Time-series grouping for dashboard queries

# --- Import/Parse ---
gem "csv"                        # stdlib, explicit require
gem "ofx", "~> 0.3"             # OFX/QFX parsing
gem "smarter_csv"                # friendlier CSV parsing
gem "pdf-reader"                 # PDF text extraction (Phase 4)

# --- Categorization & Search ---
gem "pg_search"                  # full-text search

# --- Charts ---
# Chart.js loaded via CDN or importmap — no gem needed
# Stimulus controllers handle rendering

# --- Export ---
gem "prawn"                      # PDF generation
gem "prawn-table"

# --- Dev/Test ---
gem "rspec-rails", group: [:development, :test]
gem "factory_bot_rails", group: [:development, :test]
gem "faker", group: [:development, :test]
gem "capybara", group: :test
gem "rubocop-rails", group: :development
gem "debug", group: [:development, :test]
```

---

## Key Rails Conventions to Internalize

| Concept                            | What to look for                                                                           |
| ---------------------------------- | ------------------------------------------------------------------------------------------ |
| **Fat models, skinny controllers** | Business logic in models and service objects, controllers just coordinate                   |
| **Concerns**                       | Shared model behavior (e.g., `Importable`, `Categorizable`, `Taggable`) extracted to concerns |
| **Service objects**                | `app/services/` for complex operations that don't fit in models                            |
| **Scopes**                         | `Transaction.uncategorized`, `Transaction.for_month(date)`, `Transaction.by_category(id)`, `Transaction.tagged_with(tag)` |
| **Callbacks**                      | `before_save :normalize_description` — useful but easy to overuse                          |
| **Turbo Frames**                   | `<turbo-frame id="transactions">` wraps replaceable sections                               |
| **Stimulus**                       | Small JS controllers for behavior — chart rendering, tag picker, date range                |
| **ActiveStorage**                  | File uploads without external gems — handles local and cloud storage                       |

---

## Testing Strategy

```
spec/
├── models/           # Unit tests — validations, scopes, methods
├── services/         # Adapter parsing, categorizer logic, format detection
├── requests/         # Request specs — HTTP status, redirects, flash
├── system/           # Capybara — full browser flow (import → categorize → dashboard)
└── fixtures/
    └── files/        # Sample CSVs, OFX/QFX, and PDFs from each bank format
```

**Test data:** Create a `db/seeds/sample_transactions.rb` that generates 12 months of realistic transaction data across 3 accounts with varied categories and tags. Use this for manual testing and dashboard development.

---

## Project Structure

```
finance_reconciler/
├── app/
│   ├── controllers/
│   │   ├── accounts_controller.rb
│   │   ├── categories_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── imports_controller.rb
│   │   ├── rules_controller.rb
│   │   ├── tags_controller.rb
│   │   └── transactions_controller.rb
│   ├── jobs/
│   │   ├── import_job.rb
│   │   ├── retroactive_categorize_job.rb
│   │   └── balance_snapshot_job.rb
│   ├── models/
│   │   ├── account.rb
│   │   ├── account_balance.rb
│   │   ├── category.rb
│   │   ├── import.rb
│   │   ├── rule.rb
│   │   ├── tag.rb
│   │   ├── transaction.rb
│   │   ├── transaction_tag.rb
│   │   └── user.rb
│   ├── services/
│   │   ├── importers/
│   │   │   ├── base_adapter.rb
│   │   │   ├── format_detector.rb
│   │   │   ├── chase_credit_csv_adapter.rb
│   │   │   ├── generic_csv_adapter.rb
│   │   │   ├── ofx_adapter.rb
│   │   │   └── pdf_adapter.rb         # Phase 4
│   │   ├── categorizer.rb
│   │   └── transaction_normalizer.rb
│   ├── javascript/
│   │   └── controllers/               # Stimulus controllers
│   │       ├── chart_controller.js
│   │       ├── date_range_controller.js
│   │       ├── tag_picker_controller.js
│   │       └── import_progress_controller.js
│   └── views/
│       ├── dashboard/
│       ├── imports/
│       ├── transactions/
│       ├── categories/
│       ├── rules/
│       ├── tags/
│       └── layouts/
├── config/
│   └── routes.rb
├── db/
│   ├── migrate/
│   ├── seeds.rb
│   └── seeds/
│       └── sample_transactions.rb
└── spec/
    ├── fixtures/files/                 # Sample bank CSVs, OFX, PDFs
    ├── models/
    ├── services/
    ├── requests/
    └── system/
```

---

## Routes Sketch

```ruby
Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  devise_scope :user do
    root to: "devise/sessions#new"
  end

  resource :dashboard, only: [:show], controller: "dashboard"

  resources :accounts do
    resources :imports, only: [:new, :create, :show, :index]
    resource :reconciliation, only: [:show, :update]
  end

  resources :transactions do
    member do
      patch :categorize
      post  :create_rule    # generate rule from this transaction
    end
    collection do
      get  :uncategorized
      post :bulk_categorize
      post :bulk_tag
    end
  end

  resources :categories
  resources :rules
  resources :tags

  # good_job web UI (dev only)
  mount GoodJob::Engine => "/good_job" if Rails.env.development?
end
```

---

## Session-by-Session Checklist

Use this as a working checklist. Each session is roughly 2-4 hours.

### Session 1: Scaffold & Models

- [ ] `rails new`, database setup, gem installation
- [ ] Install and configure Devise (user model, views)
- [ ] Generate all models and migrations (including tags, transaction_tags, account_balances)
- [ ] Write model validations and associations
- [ ] Seed default categories
- [ ] Configure good_job
- [ ] Verify with `rails console` — create accounts, transactions manually

### Session 2: Import Pipeline (CSV + OFX)

- [ ] FormatDetector service
- [ ] Chase credit CSV adapter (get a real statement export to test against)
- [ ] Generic CSV adapter
- [ ] OFX/QFX adapter
- [ ] ImportJob with good_job
- [ ] ImportsController (upload form accepting .csv/.ofx/.qfx → job dispatch → status page)
- [ ] Deduplication logic with fingerprinting (SHA256 for CSV, FITID for OFX)

### Session 3: Transaction Views & Basic Categorization

- [ ] Transactions index with filtering (account, date range, category, tag, uncategorized) + Pagy pagination
- [ ] Manual category assignment (dropdown on each transaction)
- [ ] Tag assignment UI (multi-select tag picker with Stimulus autocomplete)
- [ ] RulesController CRUD
- [ ] Categorizer service
- [ ] "Create rule from transaction" flow

### Session 4: Hotwire Integration

- [ ] Turbo Frame: inline category assignment without page reload
- [ ] Turbo Frame: inline tag assignment without page reload
- [ ] Turbo Stream: import progress updates in real-time
- [ ] Stimulus: date range picker on dashboard
- [ ] Turbo Frame: category/tag filter on dashboard updates transaction list

### Session 5: Dashboard & Charts

- [ ] Dashboard queries (monthly aggregates, category breakdowns)
- [ ] Chart.js integration via Stimulus controller (bar chart, line chart, area chart)
- [ ] Budget vs. actual progress bars
- [ ] Top merchants view
- [ ] Account balances overview and net worth chart
- [ ] Tag-based spending views

### Session 6: PDF Import

- [ ] pdf-reader integration
- [ ] Chase credit PDF adapter
- [ ] Import review UI (extracted data alongside PDF)

### Session 7: Polish

- [ ] pg_search on transactions
- [ ] CSV/PDF export
- [ ] Recurring transaction detection
- [ ] Account reconciliation
- [ ] Responsive layout pass
- [ ] System tests for critical flows

---

## CLAUDE.md (for Claude Code context)

Place this at project root so Claude Code understands the codebase:

```markdown
# Finance Reconciler

Personal finance app built with Rails 7.2, PostgreSQL, Hotwire (Turbo + Stimulus), good_job, Devise.

## Architecture
- Import pipeline uses adapter pattern: `app/services/importers/`
- Each bank/file format has its own adapter implementing `BaseAdapter#parse`
- Supports CSV, OFX/QFX, and PDF imports
- All amounts stored as integer cents (amount_cents), never floats
- Deduplication via SHA256 fingerprint (CSV/PDF) or FITID (OFX/QFX)
- Categorization via priority-ordered rules in `Categorizer` service
- Flexible tagging system via has_many :through
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

## Key commands
- `bin/rails server` — start dev server (good_job runs inline in dev by default)
- `bin/rails db:seed` — seed default categories
- `bundle exec rspec` — run tests
- `GoodJob::Engine` mounted at `/good_job` in development for job dashboard
```

---

## Key Differences from Original Plan

| Area | Original | Updated |
|------|----------|---------|
| **Job queue** | Sidekiq + Redis | good_job (PostgreSQL-only, no Redis) |
| **Import formats** | CSV + PDF | CSV + OFX/QFX + PDF |
| **Authentication** | None | Devise (single user) |
| **Tags** | Not included | Full tagging system with join table |
| **Pagination** | Not specified | Pagy |
| **Charts** | Chartkick | Chart.js via Stimulus (full control) |
| **Balance tracking** | Not included | AccountBalance model, net worth dashboard |
| **Dedup (OFX)** | N/A | FITID-based (bank's unique ID) |
