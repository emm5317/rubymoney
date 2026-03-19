# Personal Finance Reconciler — Build Plan

## Project Overview

A Rails 7.2+ application for importing bank and credit card statements (CSV, OFX/QFX, PDF), categorizing transactions via user-defined rules and tags, tracking account balances and net worth, and visualizing monthly spending through interactive dashboards. Built with Hotwire (Turbo + Stimulus) for a reactive UI without heavy JavaScript. Designed for single-user use initially, architected for future Plaid integration.

**Stack:** Ruby 3.3+ · Rails 7.2+ · PostgreSQL 16 · Hotwire (Turbo + Stimulus) · good_job · Devise · Chart.js

**Deployment target:** Local development initially, DigitalOcean droplet when ready

---

## Architecture Principles

1. **Import-agnostic normalization.** Every data source (CSV, OFX/QFX, PDF, future Plaid) produces the same canonical `Transaction` record. Source-specific parsing is isolated behind an adapter interface so adding Plaid later is a new adapter, not a refactor.
2. **Smart import pipeline.** Imports go through a preview step where the user confirms and corrects parsed data. Corrections are saved to an `ImportProfile` that trains future imports — column mappings, date formats, and description normalization patterns improve over time.
3. **Convention-first Rails.** Lean into Rails opinions — RESTful resources, ActiveRecord callbacks where appropriate, concerns for shared behavior. Resist the urge to over-abstract early.
4. **Hotwire over SPA.** Turbo Frames for inline editing and partial page updates. Turbo Streams for real-time feedback during imports. Stimulus controllers for lightweight JS behavior (chart rendering, rule builder UI). No React, no build pipeline complexity.
5. **Background-first imports.** All file parsing runs in good_job (PostgreSQL-backed). The UI shows progress via Turbo Streams. This keeps request/response cycles fast and handles large statements gracefully.
6. **Cents, not floats.** All monetary values stored as integer cents. No floating-point math anywhere in the money path.
7. **Zero-dependency queue.** good_job uses PostgreSQL as its backend — no Redis to install, configure, or monitor. One less moving part in dev and production.
8. **Transfer awareness.** Inter-account transfers are detected and linked, preventing them from inflating income/expense totals on dashboards.

---

## Data Model

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   accounts   │────<│   transactions   │>────│  categories  │
└─────────────┘     └──────────────────┘     └─────────────┘
       │                  │ │ │                      │
       │    ┌─────────────┘ │ └──────────┐    ┌─────┴──────┐
       │    │               │            │    │   budgets   │
       │    │          self-ref          │    └────────────┘
       │    │       (transfer_pair)       │
       │    │                             │
┌──────┴────┴──┐   ┌─────────────────┐   │   ┌──────────────┐
│   imports     │   │ import_profiles  │   │   │    rules     │
└──────────────┘   └─────────────────┘   │   └──────────────┘
                                         │
                            ┌────────────┘
                            │
               ┌────────────┴───────────┐
               │  transaction_tags (join)│
               └────────────┬───────────┘
                            │
                     ┌──────┴──────┐
                     │    tags      │
                     └─────────────┘

┌──────────────────┐    ┌──────────────┐
│ account_balances  │    │  merchants   │  ← deferred to Phase 6
└──────────────────┘    └──────────────┘
```

### users (Devise)

| Column              | Type      | Notes               |
| ------------------- | --------- | -------------------- |
| id                  | bigint PK |                      |
| email               | string    | Devise default       |
| encrypted_password  | string    | Devise default       |
| remember_created_at | datetime  | Devise rememberable  |
| sign_in_count       | integer   | Devise trackable     |
| current_sign_in_at  | datetime  | Devise trackable     |
| last_sign_in_at     | datetime  | Devise trackable     |
| current_sign_in_ip  | string    | Devise trackable     |
| last_sign_in_ip     | string    | Devise trackable     |
| created_at          | datetime  |                      |
| updated_at          | datetime  |                      |

### accounts

| Column               | Type      | Notes                                         |
| -------------------- | --------- | --------------------------------------------- |
| id                   | bigint PK |                                               |
| user_id              | bigint FK |                                               |
| name                 | string    | "Chase Sapphire", "Schwab Checking"           |
| account_type         | enum      | checking, savings, credit_card, investment    |
| institution          | string    | "Chase", "Schwab" — future FK to institutions |
| currency             | string    | Default "USD"                                 |
| source_type          | enum      | manual, csv, ofx, pdf, plaid (future)         |
| plaid_account_id     | string    | Nullable — reserved for future Plaid linkage  |
| current_balance_cents| bigint    | Latest known balance                          |
| last_imported_at     | datetime  |                                               |
| created_at           | datetime  |                                               |
| updated_at           | datetime  |                                               |

### transactions

| Column             | Type      | Notes                                             |
| ------------------ | --------- | ------------------------------------------------- |
| id                 | bigint PK |                                                   |
| account_id         | bigint FK |                                                   |
| import_id          | bigint FK | Nullable — manual entries have no import          |
| category_id        | bigint FK | Nullable until categorized                        |
| transfer_pair_id   | bigint FK | Nullable, self-referential — links transfer halves|
| merchant_id        | bigint FK | Nullable — deferred to Phase 6                    |
| date               | date      | Transaction date                                  |
| posted_date        | date      | Nullable — when it cleared                        |
| description        | string    | Raw description from statement                    |
| normalized_desc    | string    | Cleaned/normalized version for rule matching      |
| amount_cents       | bigint    | Store as integer cents, never float               |
| transaction_type   | enum      | debit, credit                                     |
| is_transfer        | boolean   | Default false — excluded from income/expense totals|
| status             | enum      | pending, cleared, reconciled                      |
| memo               | text      | User notes                                        |
| source_type        | string    | csv, ofx, pdf, plaid, manual                      |
| source_fingerprint | string    | SHA256 of raw row — deduplication key             |
| auto_categorized   | boolean   | Default false — tracks rule vs. manual            |
| created_at         | datetime  |                                                   |
| updated_at         | datetime  |                                                   |

**Indexes:** composite unique on `[account_id, source_fingerprint]` for dedup. Index on `[account_id, date]`, `[category_id]`, `[normalized_desc]`, `[transfer_pair_id]`, `[merchant_id]`.

### categories

| Column    | Type      | Notes                                     |
| --------- | --------- | ----------------------------------------- |
| id        | bigint PK |                                           |
| name      | string    | "Groceries", "Dining", "Utilities"        |
| parent_id | bigint FK | Self-referential — supports subcategories |
| color     | string    | Hex color for charts                      |
| icon      | string    | Optional icon identifier                  |
| position  | integer   | Sort order                                |
| created_at| datetime  |                                           |
| updated_at| datetime  |                                           |

**Seed data:** Start with ~15 standard categories (Housing, Utilities, Groceries, Dining, Transport, Insurance, Healthcare, Entertainment, Subscriptions, Shopping, Travel, Education, Gifts, Income, Transfers).

### budgets

| Column       | Type      | Notes                                       |
| ------------ | --------- | ------------------------------------------- |
| id           | bigint PK |                                             |
| category_id  | bigint FK |                                             |
| month        | integer   | 1-12                                        |
| year         | integer   | e.g. 2026                                   |
| amount_cents | bigint    | Budget target for this category/month       |
| notes        | text      | Optional notes ("holiday spending bump")    |
| created_at   | datetime  |                                              |
| updated_at   | datetime  |                                              |

**Unique index** on `[category_id, month, year]`. Supports month-over-month budget changes, historical tracking, and "copy from previous month" workflow.

### tags

| Column     | Type      | Notes                                        |
| ---------- | --------- | -------------------------------------------- |
| id         | bigint PK |                                              |
| name       | string    | "vacation", "tax-deductible", "reimbursable" |
| color      | string    | Hex color for UI badges                      |
| created_at | datetime  |                                              |
| updated_at | datetime  |                                              |

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
| status         | enum      | pending, previewing, processing, completed, failed |
| total_rows     | integer   | Total rows detected                    |
| imported_count | integer   | Successfully imported                  |
| skipped_count  | integer   | Duplicates skipped                     |
| error_count    | integer   | Rows that failed parsing               |
| error_log      | jsonb     | Array of {row, error} for failed rows  |
| preview_data   | jsonb     | Parsed rows held for user review before commit |
| started_at     | datetime  |                                        |
| completed_at   | datetime  |                                        |
| created_at     | datetime  |                                        |
| updated_at     | datetime  |                                        |

**File storage:** ActiveStorage attachment on Import for the original file. Local disk in dev, future migration to Backblaze B2 or DO Spaces.

**New status `previewing`:** Import is parsed but not yet committed. User reviews in preview UI before confirming.

### import_profiles

| Column                  | Type      | Notes                                               |
| ----------------------- | --------- | --------------------------------------------------- |
| id                      | bigint PK |                                                     |
| account_id              | bigint FK | Profile for imports into this account               |
| institution             | string    | "Chase", "Schwab" — for matching                    |
| column_mapping          | jsonb     | `{date: 0, description: 2, amount: 5}` etc.        |
| date_format             | string    | e.g. "%m/%d/%Y", "%Y-%m-%d"                        |
| description_corrections | jsonb     | `{"AMZN MKTP US": "Amazon", ...}` normalization map |
| amount_format           | string    | "signed", "separate_columns" etc.                   |
| skip_header_rows        | integer   | Number of header rows to skip (default 1)           |
| notes                   | text      | User notes about this profile                       |
| created_at              | datetime  |                                                     |
| updated_at              | datetime  |                                                     |

**Unique index** on `[account_id, institution]`. Auto-applied when importing to the same account. User corrections during preview automatically update the profile.

### account_balances

| Column        | Type      | Notes                                      |
| ------------- | --------- | ------------------------------------------ |
| id            | bigint PK |                                            |
| account_id    | bigint FK |                                            |
| date          | date      | Balance as of this date                    |
| balance_cents | bigint    | Balance in cents                           |
| source        | enum      | calculated, imported, manual               |
| created_at    | datetime  |                                            |
| updated_at    | datetime  |                                            |

**Unique index** on `[account_id, date]`. Used for net worth tracking and reconciliation against statement ending balances.

### merchants (Deferred to Phase 6)

| Column          | Type      | Notes                                       |
| --------------- | --------- | ------------------------------------------- |
| id              | bigint PK |                                             |
| name            | string    | "Starbucks", "Amazon"                       |
| normalized_name | string    | Lowercase, trimmed for matching             |
| category_id     | bigint FK | Nullable — default category for merchant    |
| created_at      | datetime  |                                             |
| updated_at      | datetime  |                                             |

**Unique index** on `normalized_name`. Merchant extraction service parses merchant names from descriptions. Merging UI to combine "AMZN" and "AMAZON". `merchant_id` FK on transactions is nullable and populated when merchants feature is activated.

---

## Import Architecture

### The Adapter Pattern

```ruby
# app/services/importers/base_adapter.rb
module Importers
  class BaseAdapter
    def initialize(raw_content, account:, import_profile: nil)
      @raw_content = raw_content
      @account = account
      @import_profile = import_profile
    end

    # Returns array of normalized hashes:
    # { date:, posted_date:, description:, amount_cents:, transaction_type:, source_fingerprint: }
    def parse
      raise NotImplementedError
    end

    private

    def normalize_description(raw)
      desc = raw.gsub(/\s+/, ' ').strip.gsub(/\d{4}\*+\d{4}/, '').strip
      # Apply learned description corrections from import profile
      if @import_profile&.description_corrections&.key?(desc)
        @import_profile.description_corrections[desc]
      else
        desc
      end
    end

    def to_cents(amount_string)
      (BigDecimal(amount_string.gsub(/[,$]/, '')) * 100).to_i
    end
  end
end

# app/services/importers/chase_csv_adapter.rb
# app/services/importers/schwab_csv_adapter.rb
# app/services/importers/generic_csv_adapter.rb   ← uses ImportProfile for column mapping
# app/services/importers/ofx_adapter.rb           ← OFX/QFX support
# app/services/importers/pdf_adapter.rb           ← Phase 5
# app/services/importers/plaid_adapter.rb         ← future
```

### Auto-Detection Strategy

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

### Smart Import Flow

```
1. User uploads file → Import created with status: "pending"
2. ParseJob runs adapter → parsed rows stored in Import.preview_data (status: "previewing")
3. User sees preview table (first 20 rows + summary stats)
   - Can correct column mappings → saved to ImportProfile
   - Can fix date format → saved to ImportProfile
   - Can edit descriptions → saved to ImportProfile.description_corrections
   - Can assign categories → offered "create rule?" prompt
   - Can flag rows to skip
4. User clicks "Confirm Import" → CommitImportJob persists transactions (status: "processing" → "completed")
5. Import rollback: "Undo Import" deletes all transactions with that import_id
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

### Deduplication

Generate `source_fingerprint` as SHA256 of `"#{account_id}:#{date}:#{description}:#{amount_cents}"` for CSV imports, or `"#{account_id}:#{fit_id}"` for OFX (using the bank's unique transaction ID). On import, skip any transaction whose fingerprint already exists for that account. Track skip count on the Import record.

**Edge case:** Some banks produce identical rows for genuinely different transactions (two $5.00 Starbucks charges same day). Handle by appending a sequence counter to the fingerprint when exact duplicates are detected within the same import file.

### Transfer Detection

```ruby
# app/services/transfer_matcher.rb
class TransferMatcher
  # After import, scan for potential transfer pairs:
  # - Opposite transaction_type (one debit, one credit)
  # - Same absolute amount
  # - Different accounts
  # - Within ±3 day window
  # Auto-link high-confidence matches, surface ambiguous ones for user review
  def match(transaction)
    candidates = Transaction
      .where.not(account_id: transaction.account_id)
      .where(amount_cents: transaction.amount_cents)
      .where(transaction_type: opposite_type(transaction.transaction_type))
      .where(date: (transaction.date - 3.days)..(transaction.date + 3.days))
      .where(is_transfer: false, transfer_pair_id: nil)

    # Return candidates ranked by date proximity
  end
end
```

---

## Phase Breakdown

### Phase 1 — Foundation (Estimated: 2-3 sessions)

**Goal:** Rails app scaffolded, authentication working, all models migrated, seed data loaded, test framework ready.

**Tasks:**

- [ ] `rails new finance_reconciler --database=postgresql --css=tailwind --skip-jbuilder`
- [ ] Configure PostgreSQL (dev/test databases)
- [ ] Install and configure Devise (single user, registration disabled after initial setup)
- [ ] Generate all models and migrations:
  - Account, Transaction, Category, Budget, Rule, Import, ImportProfile, Tag, TransactionTag, AccountBalance
  - Include `transfer_pair_id`, `is_transfer`, `merchant_id` (nullable) on transactions
  - Include `preview_data` jsonb on imports
- [ ] Write all indexes and constraints
- [ ] Write model validations and associations
- [ ] Seed default categories (~15)
- [ ] Install and configure good_job (PostgreSQL-backed job queue)
- [ ] RSpec setup with FactoryBot and Faker
- [ ] Verify with `rails console` — create accounts, transactions, budgets manually
- [ ] Basic application layout with Tailwind (navigation, flash messages)

**Key gems this phase:** devise, good_job, pagy, rspec-rails, factory_bot_rails, faker

**Testing focus:** Model validations, associations, enum definitions, seed data correctness.

---

### Phase 2 — Import Pipeline (Estimated: 3-4 sessions)

**Goal:** CSV and OFX import with smart preview, ImportProfile learning, deduplication.

**Tasks:**

- [ ] Implement `Importers::FormatDetector`
- [ ] Implement `Importers::ChaseCreditCsvAdapter` (concrete adapter for Chase credit CSV)
- [ ] Implement `Importers::GenericCsvAdapter` with column mapping via ImportProfile
- [ ] Implement `Importers::OfxAdapter` for OFX/QFX files
- [ ] `ParseJob` — parses file, stores results in `Import.preview_data`, sets status to `previewing`
- [ ] Import preview UI — table showing parsed transactions, column mapping controls, date format selector
- [ ] ImportProfile creation/update from preview corrections:
  - Column mapping saved on confirm
  - Date format saved on confirm
  - Description corrections saved as normalization patterns
  - Category assignments during preview trigger "create rule?" prompt
- [ ] `CommitImportJob` — persists previewed transactions, runs categorizer, updates import stats
- [ ] Import rollback — "Undo Import" button deletes all transactions for an import_id
- [ ] Deduplication logic with fingerprinting (SHA256 for CSV, FITID for OFX)
- [ ] `ImportsController` — upload form (accepts .csv, .ofx, .qfx), preview page, confirm action
- [ ] Basic import status/history page showing counts per import
- [ ] Turbo Stream: import progress updates during commit phase

**Key gems this phase:** ofx, smarter_csv, csv

**Testing focus:** Adapter parsing (unit tests with fixture CSVs and OFX files), deduplication logic, ImportProfile auto-apply, preview-to-commit flow.

---

### Phase 3 — Categorization, Tags & Manual Entry (Estimated: 2-3 sessions)

**Goal:** Rules-based auto-categorization with manual override. Tag management. Manual transaction entry. Transfer detection.

**Tasks:**

- [ ] `Categorizer` service — applies rules in priority order to a transaction, also applies auto-tags from matching rules
- [ ] Hook categorizer into import commit pipeline (auto-categorize on commit)
- [ ] `RulesController` — CRUD for categorization rules
- [ ] "Categorize" action on transaction index — inline dropdown to assign category
- [ ] "Create rule from this" action — pre-fills rule form from transaction's description
- [ ] Retroactive application — when a new rule is created with `apply_retroactive`, background job categorizes matching uncategorized transactions
- [ ] Bulk categorization — select multiple transactions, assign category
- [ ] Uncategorized transactions filter/view (the "inbox" pattern)
- [ ] `TagsController` — CRUD for tags
- [ ] Tag assignment UI on transactions — multi-select tag picker (Stimulus controller with autocomplete)
- [ ] Bulk tagging — select multiple transactions, apply/remove tags
- [ ] Filter transactions by tag
- [ ] Manual transaction entry — form with date, description, amount, account, category, tags, memo
- [ ] `TransferMatcher` service — auto-detect transfer pairs after import
- [ ] Transfer linking UI — surface potential matches, confirm/reject, manual link/unlink
- [ ] Turbo Frame: inline category and tag assignment without page reload
- [ ] Transaction index with full filtering (account, date range, category, tag, uncategorized, transfers) + Pagy pagination

**Testing focus:** Rule matching logic (contains, regex, amount ranges), priority resolution, retroactive application, transfer matching accuracy.

---

### Phase 4 — Dashboard & Budgets (Estimated: 3-4 sessions)

**Goal:** Interactive spending dashboard with Chart.js, per-month budgets, balance tracking, net worth.

**Tasks:**

- [ ] `DashboardController` with configurable date range (default: current month)
- [ ] Monthly summary: total income, total expenses, net, by-category breakdown
  - **Exclude transfers** from income/expense totals
- [ ] Stimulus Chart.js controller — reusable controller for rendering/updating charts
- [ ] Category spending bar chart (Stimulus + Chart.js)
- [ ] Spending trend line chart (last 6 months)
- [ ] Turbo Frame: clicking a category in the chart filters the transaction list below it
- [ ] Turbo Frame: date range picker updates dashboard content via frame replacement
- [ ] `BudgetsController` — CRUD for monthly budgets per category
- [ ] "Copy from previous month" budget workflow
- [ ] Budget vs. actual — progress bars per category for the selected month
- [ ] Top merchants view — group by normalized_desc, rank by total spend
- [ ] Income vs. expenses over time (area chart)
- [ ] Account balances overview — current balance per account, total net worth
- [ ] Net worth over time chart (line chart from account_balances snapshots)
- [ ] `BalanceSnapshotJob` — daily recurring job to record account balances
- [ ] Tag-based spending views (e.g., total vacation spending, tax-deductible expenses)

**Key learning:** Stimulus controllers for Chart.js integration, groupdate gem for time-series aggregation, presenter/decorator pattern, good_job recurring jobs (cron).

**Testing focus:** Dashboard query performance (test with 10K+ transactions), correct aggregation math (especially transfer exclusion), budget calculations, Turbo Frame response rendering.

---

### Phase 5 — PDF Import (Estimated: 2-3 sessions)

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
- [ ] PDF imports go through the same preview flow as CSV

**Edge cases:** PDF statements are notoriously inconsistent. Plan for ~80% automation with manual review for the rest. Don't over-invest in perfection here.

---

### Phase 4.5 — UX Polish (COMPLETE)

**Completed features:**
- [x] Budgets + Import in main navigation
- [x] Uncategorized transaction count badge in nav (via ApplicationController before_action)
- [x] Transaction text search (ILIKE on description/normalized_desc)
- [x] Column sorting on transaction list (date, description, amount — with pagination param preservation)
- [x] Rule test/preview (SQL-pushed matching for common types)
- [x] Recent transactions + quick actions on dashboard
- [x] Mobile hamburger nav toggle (Stimulus nav_toggle controller)
- [x] CSV export with current filter support

### Phase 4.6 — Recurring Transaction Detection (COMPLETE)

**Completed features:**
- [x] `RecurringTransaction` model (frequency, confidence, status, amount tracking)
- [x] `RecurringDetector` service (interval analysis, frequency classification, confidence scoring)
- [x] `RecurringDetectionJob` (daily cron at 3 AM via good_job)
- [x] Full CRUD controller with confirm/dismiss/reactivate/detect_now/mark_recurring
- [x] Dashboard partial showing top recurring charges with monthly total
- [x] Recurring badge on transaction show page
- [x] Nav link for Recurring section
- [x] Model, service, and request specs

### Phase 5 — PDF Import (Not yet started)

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
- [ ] PDF imports go through the same preview flow as CSV

**Edge cases:** PDF statements are notoriously inconsistent. Plan for ~80% automation with manual review for the rest. Don't over-invest in perfection here.

### Phase 6 — Polish, Merchants & Backup (Estimated: 3-4 sessions)

**Goal:** Production-quality UX, merchant normalization, backup, and cleanup.

**Tasks:**

- [ ] Transaction search — upgrade to full-text search with pg_search gem (currently ILIKE, works but no ranking)
- [ ] **Merchant normalization:**
  - Merchant extraction service (parse merchant name from transaction descriptions)
  - `MerchantsController` — CRUD, merge UI (combine "AMZN" and "AMAZON")
  - Populate `merchant_id` on transactions
  - Top merchants dashboard updated to use merchants table
  - Default category assignment per merchant
- [ ] Bulk import — drag-and-drop multiple files at once (CSV, OFX, QFX)
- [ ] Export: spending summary to PDF (Prawn gem)
- [ ] Duplicate review — surface potential duplicates across imports for manual resolution
- [ ] Account reconciliation — compare running balance against imported statement balance, flag discrepancies
- [ ] Data cleanup tools — merge categories, bulk re-categorize, edit normalized descriptions
- [ ] Tag management — merge tags, bulk operations
- [ ] **Automated backup:**
  - Rake task `db:backup` running pg_dump with timestamped filename
  - good_job recurring job: daily backup, rotate keeping last 30
  - Configurable backup directory (default: `db/backups/`)
- [ ] System tests with Capybara for critical flows

**Already done (moved to Phase 4.5/4.6):** CSV export, recurring transaction detection, mobile-responsive nav, text search, error handling/flash messages.

**Key gems this phase:** pg_search, prawn, prawn-table

---

### Phase 7 — Future: Plaid Integration (Not in initial build)

**Architectural prep already in place:**

- `Account.source_type` enum includes `plaid`
- `Account.plaid_account_id` column reserved
- Adapter interface (`Importers::BaseAdapter`) accepts any source
- `Transaction.source_type` tracks provenance
- Import model can represent a Plaid sync as well as a file upload
- Balance tracking already built — Plaid just becomes another balance source
- Transfer detection works regardless of source

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
gem "good_job", "~> 4.0"        # PostgreSQL-backed job queue (no Redis)
gem "devise", "~> 4.9"           # Authentication
gem "pagy", "~> 9.0"             # Fast pagination
gem "groupdate"                   # Time-series grouping for dashboard queries

# --- Import/Parse ---
gem "csv"                         # stdlib, explicit require
gem "ofx", "~> 0.3"              # OFX/QFX parsing
gem "smarter_csv"                 # friendlier CSV parsing
gem "pdf-reader"                  # PDF text extraction (Phase 5)

# --- Categorization & Search ---
gem "pg_search"                   # full-text search (Phase 6)

# --- Charts ---
# Chart.js loaded via CDN or importmap — no gem needed
# Stimulus controllers handle rendering

# --- Export ---
gem "prawn"                       # PDF generation (Phase 6)
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

| Concept                            | What to look for                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------- |
| **Fat models, skinny controllers** | Business logic in models and service objects, controllers just coordinate                      |
| **Concerns**                       | Shared model behavior (e.g., `Importable`, `Categorizable`, `Taggable`) extracted to concerns |
| **Service objects**                | `app/services/` for complex operations that don't fit in models                               |
| **Scopes**                         | `Transaction.uncategorized`, `Transaction.for_month(date)`, `Transaction.non_transfer`, `Transaction.tagged_with(tag)` |
| **Callbacks**                      | `before_save :normalize_description` — useful but easy to overuse                             |
| **Turbo Frames**                   | `<turbo-frame id="transactions">` wraps replaceable sections                                  |
| **Stimulus**                       | Small JS controllers for behavior — chart rendering, tag picker, date range                   |
| **ActiveStorage**                  | File uploads without external gems — handles local and cloud storage                          |

---

## Testing Strategy

```
spec/
├── models/           # Unit tests — validations, scopes, methods
├── services/         # Adapter parsing, categorizer, transfer matcher, format detection
├── requests/         # Request specs — HTTP status, redirects, flash
├── system/           # Capybara — full browser flow (import → preview → categorize → dashboard)
└── fixtures/
    └── files/        # Sample CSVs, OFX/QFX, and PDFs from each bank format
```

**Test data:** Create a `db/seeds/sample_transactions.rb` that generates 12 months of realistic transaction data across 3 accounts with varied categories, tags, and inter-account transfers. Use this for manual testing and dashboard development.

---

## Project Structure

```
finance_reconciler/
├── app/
│   ├── controllers/
│   │   ├── accounts_controller.rb
│   │   ├── budgets_controller.rb
│   │   ├── categories_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── imports_controller.rb
│   │   ├── merchants_controller.rb      # Phase 6
│   │   ├── rules_controller.rb
│   │   ├── tags_controller.rb
│   │   └── transactions_controller.rb
│   ├── jobs/
│   │   ├── parse_job.rb                  # Parse file → preview_data
│   │   ├── commit_import_job.rb          # Persist previewed transactions
│   │   ├── retroactive_categorize_job.rb
│   │   ├── balance_snapshot_job.rb
│   │   └── database_backup_job.rb        # Phase 6
│   ├── models/
│   │   ├── account.rb
│   │   ├── account_balance.rb
│   │   ├── budget.rb
│   │   ├── category.rb
│   │   ├── import.rb
│   │   ├── import_profile.rb
│   │   ├── merchant.rb                   # Phase 6
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
│   │   │   └── pdf_adapter.rb            # Phase 5
│   │   ├── categorizer.rb
│   │   ├── transfer_matcher.rb
│   │   └── transaction_normalizer.rb
│   ├── javascript/
│   │   └── controllers/                  # Stimulus controllers
│   │       ├── chart_controller.js
│   │       ├── date_range_controller.js
│   │       ├── tag_picker_controller.js
│   │       ├── column_mapper_controller.js
│   │       └── import_progress_controller.js
│   └── views/
│       ├── budgets/
│       ├── dashboard/
│       ├── imports/
│       │   ├── new.html.erb              # Upload form
│       │   ├── preview.html.erb          # Preview/correct before commit
│       │   └── show.html.erb             # Import results/status
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
├── lib/
│   └── tasks/
│       └── backup.rake                   # Phase 6
└── spec/
    ├── fixtures/files/                    # Sample bank CSVs, OFX, PDFs
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
    resources :imports, only: [:new, :create, :show, :index] do
      member do
        get  :preview        # Show parsed preview for confirmation
        post :confirm         # Commit previewed transactions
        post :rollback        # Delete all transactions from this import
      end
    end
    resource :reconciliation, only: [:show, :update]
  end

  resources :transactions do
    member do
      patch :categorize
      post  :create_rule       # Generate rule from this transaction
      post  :link_transfer     # Link to a transfer pair
      delete :unlink_transfer  # Unlink transfer pair
    end
    collection do
      get  :uncategorized
      post :bulk_categorize
      post :bulk_tag
    end
  end

  resources :categories
  resources :budgets
  resources :rules
  resources :tags
  resources :merchants            # Phase 6

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
- [ ] Generate all models and migrations (Account, Transaction, Category, Budget, Rule, Import, ImportProfile, Tag, TransactionTag, AccountBalance)
- [ ] Include transfer_pair_id, is_transfer, merchant_id on transactions
- [ ] Include preview_data on imports
- [ ] Write all indexes and constraints
- [ ] Write model validations and associations
- [ ] Seed default categories
- [ ] Configure good_job
- [ ] RSpec setup with FactoryBot
- [ ] Basic application layout with Tailwind

### Session 2: Import Pipeline — Adapters

- [ ] FormatDetector service
- [ ] Chase credit CSV adapter (with fixture data)
- [ ] Generic CSV adapter (uses ImportProfile column mapping)
- [ ] OFX/QFX adapter
- [ ] ParseJob — parse file → store in Import.preview_data
- [ ] Deduplication logic with fingerprinting (SHA256 for CSV, FITID for OFX)
- [ ] Unit tests for all adapters

### Session 3: Import Pipeline — Preview & Commit

- [ ] Import upload form (ImportsController#new, #create)
- [ ] Preview UI (ImportsController#preview) — table of parsed transactions
- [ ] Column mapping UI (Stimulus controller) for generic CSV
- [ ] ImportProfile auto-creation/update from preview corrections
- [ ] CommitImportJob — persist previewed transactions
- [ ] Import rollback (delete all transactions from an import)
- [ ] Import history page with status and counts
- [ ] Turbo Stream: progress updates during commit

### Session 4: Categorization & Tags

- [ ] Categorizer service (priority-ordered rule matching)
- [ ] Hook categorizer into CommitImportJob
- [ ] RulesController CRUD
- [ ] "Create rule from transaction" flow
- [ ] Retroactive categorization job
- [ ] Uncategorized inbox view
- [ ] Bulk categorization
- [ ] TagsController CRUD
- [ ] Tag picker Stimulus controller (autocomplete multi-select)
- [ ] Bulk tagging

### Session 5: Manual Entry & Transfers

- [ ] Manual transaction entry form (TransactionsController#new, #create)
- [ ] Transaction index with full filtering + Pagy pagination
- [ ] Turbo Frame: inline category and tag assignment
- [ ] TransferMatcher service
- [ ] Transfer detection after import commit
- [ ] Transfer link/unlink UI
- [ ] Transfer-aware scopes (Transaction.non_transfer)

### Session 6: Dashboard & Charts

- [ ] DashboardController with date range
- [ ] Monthly summary (income, expenses, net — excluding transfers)
- [ ] Chart.js Stimulus controller (reusable)
- [ ] Category spending bar chart
- [ ] Spending trend line chart (6 months)
- [ ] Turbo Frame: category drill-down, date range picker
- [ ] Income vs. expenses area chart
- [ ] Top merchants view (using normalized_desc for now)

### Session 7: Budgets & Balance Tracking

- [ ] BudgetsController CRUD
- [ ] Copy from previous month workflow
- [ ] Budget vs. actual progress bars on dashboard
- [ ] Account balances overview and net worth total
- [ ] BalanceSnapshotJob (daily recurring via good_job cron)
- [ ] Net worth over time chart
- [ ] Tag-based spending views

### Session 8: PDF Import

- [ ] pdf-reader integration
- [ ] Chase credit PDF adapter
- [ ] PDF preview flow (same as CSV/OFX)
- [ ] Import review UI (extracted data alongside PDF)

### Session 9: Polish & Merchants

- [ ] pg_search on transactions
- [ ] Merchant extraction service + MerchantsController
- [ ] Merchant merge UI
- [ ] CSV/PDF export
- [ ] Recurring transaction detection
- [ ] Account reconciliation
- [ ] Automated pg_dump backup (rake task + recurring job)
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
- Smart import preview: parsed data shown for review before committing
- ImportProfile model learns column mappings, date formats, and description corrections per account
- All amounts stored as integer cents (amount_cents), never floats
- Deduplication via SHA256 fingerprint (CSV/PDF) or FITID (OFX/QFX)
- Categorization via priority-ordered rules in `Categorizer` service
- Flexible tagging system via has_many :through
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
- `bin/rails db:seed` — seed default categories
- `bundle exec rspec` — run tests
- `GoodJob::Engine` mounted at `/good_job` in development for job dashboard
```

---

## Key Differences from Original Plan

| Area                 | Original Plan              | Updated Plan                                                    |
| -------------------- | -------------------------- | --------------------------------------------------------------- |
| **Job queue**        | Sidekiq + Redis            | good_job (PostgreSQL-only, no Redis)                            |
| **Import formats**   | CSV + PDF                  | CSV + OFX/QFX + PDF                                            |
| **Import flow**      | Direct to background job   | Preview → correct → confirm → commit (with learning)           |
| **Import profiles**  | Not included               | ImportProfile model learns mappings per account                 |
| **Import rollback**  | Not included               | Undo import by deleting all transactions with that import_id   |
| **Authentication**   | None                       | Devise (single user)                                            |
| **Tags**             | Not included               | Full tagging system with join table                             |
| **Transfers**        | Not handled                | Auto-detection, linking, exclusion from income/expense totals   |
| **Budgets**          | Single column on categories| Separate `budgets` table with per-month granularity             |
| **Merchants**        | Not included               | First-class model (deferred to Phase 6)                         |
| **Manual entry**     | Not included               | Transaction entry form for cash/adjustments                     |
| **Pagination**       | Not specified              | Pagy                                                            |
| **Charts**           | Chartkick                  | Chart.js via Stimulus (full control)                            |
| **Balance tracking** | Not included               | AccountBalance model, net worth dashboard                       |
| **Backup**           | Not included               | Automated pg_dump with rotation                                 |
| **Phase structure**  | 6 phases (Phase 1 overloaded) | 7 phases, smaller increments                                |
| **Dedup (OFX)**      | N/A                        | FITID-based (bank's unique ID)                                  |
