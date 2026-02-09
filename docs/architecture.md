# Architecture

## ASCII Diagram

+--------------------------------------------------------------+
|                     Budget.xlsm (Excel UI)                   |
|  Sheets: Config | Accounts | Rules | Budgets | Transactions  |
|  Buttons: Sync | Re-categorize | Commit Overrides | Diag     |
|                                                              |
|  VBA:                                                     +--+---+
|   - ensure service running (budgetd.exe)                  | DPAPI |
|   - push rules                                            +--+---+
|   - request sync + fetch txns                                |
|   - detect overrides + push changes                          |
+-----------------------------|--------------------------------+
                              | HTTP (localhost only)
                              v
+--------------------------------------------------------------+
|                 Go Service: budgetd (Fiber)                  |
|  Bind: 127.0.0.1:8787                                       |
|  Modules: api | sync | rules | connectors/csv | db | logs    |
|                                                              |
|  Endpoints: /v1/health /v1/sync /v1/transactions ...         |
|  - CSV import + parsing + mapping                            |
|  - Idempotent upsert + pending->posted reconciliation        |
|  - Deterministic rules engine                                |
|  - Overrides protect manual edits                            |
|  - Structured logs (redacted)                                |
+-----------------------------|--------------------------------+
                              |
                              v
+--------------------------------------------------------------+
|                  SQLite (source of truth)                    |
|  accounts, transactions, rules, overrides, sync_runs, raw... |
|  Migrations (golang-migrate)                                 |
+--------------------------------------------------------------+

Install/Package:
  WiX MSI installs budgetd.exe + Start menu shortcut (optional startup)
Local-only:
  No remote listeners, no secrets exposed to Excel/logs/API

## Component Responsibilities

- Excel VBA
- UI tables for accounts, rules, budgets, transactions
- Runs sync and rules workflows
- Pushes overrides from manual edits
- Never handles secrets

- Go Service
- HTTP API (Fiber) on localhost
- CSV import and parsing
- Idempotent upserts, pending->posted reconciliation
- Rules engine and overrides handling
- SQLite persistence and migrations
- Redacted structured logs

- SQLite
- System of record for accounts, rules, transactions, overrides

- Secrets
- DPAPI encrypted blobs on disk or Credential Manager
- Never exposed to Excel or logs

## Data Flow (Sync)

- Excel reads settings from Config table
- VBA ensures service is running and healthy
- VBA posts rules to `/v1/rules/import`
- VBA posts `/v1/sync` with accounts + since
- Service imports, dedupes, applies rules, stores in SQLite
- VBA fetches `/v1/transactions?since=...`
- VBA replaces Transactions table and refreshes pivots

## Data Flow (Overrides)

- User edits category/subcategory in Transactions table
- VBA detects changes relative to snapshot
- VBA posts `/v1/overrides/import`
- Service upserts overrides and protects from rule apply
