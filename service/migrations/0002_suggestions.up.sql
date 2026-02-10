ALTER TABLE transactions ADD COLUMN suggested_category TEXT NULL;
ALTER TABLE transactions ADD COLUMN suggested_subcategory TEXT NULL;
ALTER TABLE transactions ADD COLUMN suggested_confidence REAL NULL;
ALTER TABLE transactions ADD COLUMN suggested_model_id TEXT NULL;
ALTER TABLE transactions ADD COLUMN suggested_status TEXT NOT NULL DEFAULT 'none';
ALTER TABLE transactions ADD COLUMN suggested_reason_code TEXT NULL;

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

CREATE INDEX ix_txn_suggestion_jobs_status
  ON txn_suggestion_jobs(status);

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

CREATE INDEX ix_txn_suggestion_cache_version
  ON txn_suggestion_cache(prompt_version);
