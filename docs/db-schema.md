# Database Schema

## Migration Tool

Use `golang-migrate` for SQLite migrations.

## Schema (SQL)

```sql
CREATE TABLE accounts (
  account_id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  institution TEXT NOT NULL,
  connector_type TEXT NOT NULL,
  external_id TEXT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  last_sync_at TEXT NULL,
  sync_status TEXT NULL
);

CREATE TABLE transactions (
  txn_id TEXT PRIMARY KEY,
  external_txn_id TEXT NULL,
  account_id TEXT NOT NULL,
  posted_date TEXT NOT NULL,
  amount REAL NOT NULL,
  payee TEXT NOT NULL,
  memo TEXT NOT NULL,
  pending INTEGER NOT NULL,
  fingerprint TEXT NOT NULL,
  category TEXT NULL,
  subcategory TEXT NULL,
  category_source TEXT NOT NULL,
  suggested_category TEXT NULL,
  suggested_subcategory TEXT NULL,
  suggested_confidence REAL NULL,
  suggested_model_id TEXT NULL,
  suggested_status TEXT NOT NULL DEFAULT 'none',
  suggested_reason_code TEXT NULL,
  raw_ref TEXT NULL,
  imported_at TEXT NOT NULL,
  FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

CREATE UNIQUE INDEX ux_txn_external_id
  ON transactions(account_id, external_txn_id)
  WHERE external_txn_id IS NOT NULL;

CREATE UNIQUE INDEX ux_txn_fingerprint
  ON transactions(account_id, fingerprint)
  WHERE external_txn_id IS NULL;

CREATE INDEX ix_txn_account_posted
  ON transactions(account_id, posted_date);

CREATE INDEX ix_txn_external
  ON transactions(external_txn_id);

CREATE INDEX ix_txn_fingerprint
  ON transactions(fingerprint);

CREATE INDEX ix_txn_posted
  ON transactions(posted_date);

CREATE TABLE rules (
  rule_id TEXT PRIMARY KEY,
  priority INTEGER NOT NULL,
  enabled INTEGER NOT NULL,
  match_field TEXT NOT NULL,
  match_type TEXT NOT NULL,
  match_value TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  notes TEXT NULL
);

CREATE TABLE overrides (
  txn_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  subcategory TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (txn_id) REFERENCES transactions(txn_id)
);

CREATE TABLE sync_runs (
  sync_run_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  ended_at TEXT NULL,
  since TEXT NOT NULL,
  status TEXT NOT NULL,
  summary_json TEXT NOT NULL
);

CREATE TABLE raw_blobs (
  raw_ref TEXT PRIMARY KEY,
  content_type TEXT NOT NULL,
  payload BLOB NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE txn_category_suggestions (
  id INTEGER PRIMARY KEY,
  txn_id TEXT NOT NULL,
  model_id TEXT NULL,
  status TEXT NOT NULL,
  top_category TEXT NULL,
  subcategory TEXT NULL,
  confidence REAL NULL,
  latency_ms INTEGER NULL,
  prompt_version TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (txn_id) REFERENCES transactions(txn_id)
);

CREATE TABLE txn_suggestion_jobs (
  job_id INTEGER PRIMARY KEY,
  txn_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL,
  last_error TEXT NULL,
  categories_json TEXT NOT NULL,
  prompt_version TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (txn_id) REFERENCES transactions(txn_id)
);

CREATE TABLE txn_suggestion_cache (
  cache_key TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  category TEXT NULL,
  subcategory TEXT NULL,
  confidence REAL NULL,
  model_id TEXT NULL,
  suggested_at DATETIME NOT NULL,
  prompt_version TEXT NOT NULL
);
```

## Notes

- `summary_json` is redacted and must not include secrets.
- `raw_blobs` is optional and should be size-capped.
- `memo` defaults to empty string for stable hashing.
