package db

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"budgetexcel/service/internal/models"
)

type SuggestionContext struct {
	Transaction models.Transaction
	AccountType string
}

func GetSuggestionContext(db *sql.DB, txnID string) (SuggestionContext, bool, error) {
	const q = `
SELECT t.txn_id, t.external_txn_id, t.account_id, t.posted_date, t.amount, t.payee, t.memo,
       t.category, t.subcategory, t.category_source,
       t.suggested_category, t.suggested_subcategory, t.suggested_confidence, t.suggested_model_id, t.suggested_status, t.suggested_reason_code,
       t.pending, t.fingerprint, t.raw_ref, t.imported_at,
       a.account_type
FROM transactions t
JOIN accounts a ON a.account_id = t.account_id
WHERE t.txn_id = ?;
`
	row := db.QueryRow(q, txnID)

	var t models.Transaction
	var extID sql.NullString
	var category sql.NullString
	var subcategory sql.NullString
	var suggestedCategory sql.NullString
	var suggestedSubcategory sql.NullString
	var suggestedConfidence sql.NullFloat64
	var suggestedModelID sql.NullString
	var suggestedStatus sql.NullString
	var suggestedReasonCode sql.NullString
	var rawRef sql.NullString
	var pendingInt int
	var accountType string

	if err := row.Scan(
		&t.TxnID, &extID, &t.AccountID, &t.PostedDate, &t.Amount, &t.Payee, &t.Memo,
		&category, &subcategory, &t.CategorySource,
		&suggestedCategory, &suggestedSubcategory, &suggestedConfidence, &suggestedModelID, &suggestedStatus, &suggestedReasonCode,
		&pendingInt, &t.Fingerprint, &rawRef, &t.ImportedAt,
		&accountType,
	); err != nil {
		if err == sql.ErrNoRows {
			return SuggestionContext{}, false, nil
		}
		return SuggestionContext{}, false, err
	}

	if extID.Valid {
		t.ExternalTxnID = extID.String
	}
	if category.Valid {
		t.Category = category.String
	}
	if subcategory.Valid {
		t.Subcategory = subcategory.String
	}
	if suggestedCategory.Valid {
		t.SuggestedCategory = suggestedCategory.String
	}
	if suggestedSubcategory.Valid {
		t.SuggestedSubcategory = suggestedSubcategory.String
	}
	if suggestedConfidence.Valid {
		t.SuggestedConfidence = suggestedConfidence.Float64
	}
	if suggestedModelID.Valid {
		t.SuggestedModelID = suggestedModelID.String
	}
	if suggestedStatus.Valid {
		t.SuggestedStatus = suggestedStatus.String
	}
	if suggestedReasonCode.Valid {
		t.SuggestedReasonCode = suggestedReasonCode.String
	}
	if rawRef.Valid {
		t.RawRef = rawRef.String
	}
	t.Pending = pendingInt == 1

	return SuggestionContext{Transaction: t, AccountType: accountType}, true, nil
}

func InsertSuggestionAudit(db *sql.DB, audit models.SuggestionAudit) error {
	const q = `
INSERT INTO txn_category_suggestions (
  txn_id, model_id, status, top_category, subcategory, confidence, latency_ms, prompt_version, created_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
`
	_, err := db.Exec(q,
		audit.TxnID,
		nullIfEmpty(audit.ModelID),
		audit.Status,
		nullIfEmpty(audit.TopCategory),
		nullIfEmpty(audit.Subcategory),
		nullFloatIfZero(audit.Confidence),
		nullIntIfZero(audit.LatencyMs),
		audit.PromptVersion,
		audit.CreatedAt,
	)
	return err
}

func UpdateTransactionSuggestion(db *sql.DB, txnID, category, subcategory, status, modelID, reasonCode string, confidence float64) error {
	const q = `
UPDATE transactions
SET suggested_category = ?,
    suggested_subcategory = ?,
    suggested_confidence = ?,
    suggested_model_id = ?,
    suggested_status = ?,
    suggested_reason_code = ?
WHERE txn_id = ?;
`
	_, err := db.Exec(q,
		nullIfEmpty(category),
		nullIfEmpty(subcategory),
		nullFloatIfZero(confidence),
		nullIfEmpty(modelID),
		status,
		nullIfEmpty(reasonCode),
		txnID,
	)
	return err
}

func UpdateSuggestionStatus(db *sql.DB, txnID, status string) error {
	const q = `UPDATE transactions SET suggested_status = ? WHERE txn_id = ?;`
	_, err := db.Exec(q, status, txnID)
	return err
}

func EnqueueSuggestionJobs(db *sql.DB, txnIDs []string, categoriesJSON, promptVersion string) (int, error) {
	if len(txnIDs) == 0 {
		return 0, nil
	}

	const q = `
INSERT OR IGNORE INTO txn_suggestion_jobs (
  txn_id, status, attempts, last_error, categories_json, prompt_version, created_at
) VALUES (?, 'queued', 0, NULL, ?, ?, ?);
`

	tx, err := db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(q)
	if err != nil {
		return 0, err
	}
	defer stmt.Close()

	now := time.Now().UTC().Format(time.RFC3339)
	created := 0
	for _, id := range txnIDs {
		res, err := stmt.Exec(id, categoriesJSON, promptVersion, now)
		if err != nil {
			return 0, fmt.Errorf("enqueue job %s: %w", id, err)
		}
		rows, _ := res.RowsAffected()
		if rows > 0 {
			created++
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return created, nil
}

func ClaimNextSuggestionJob(db *sql.DB) (models.SuggestionJob, bool, error) {
	tx, err := db.Begin()
	if err != nil {
		return models.SuggestionJob{}, false, err
	}
	defer tx.Rollback()

	const selectQ = `
SELECT job_id, txn_id, status, attempts, last_error, categories_json, prompt_version, created_at
FROM txn_suggestion_jobs
WHERE status = 'queued'
ORDER BY job_id ASC
LIMIT 1;
`
	var job models.SuggestionJob
	var lastError sql.NullString
	row := tx.QueryRow(selectQ)
	if err := row.Scan(&job.JobID, &job.TxnID, &job.Status, &job.Attempts, &lastError, &job.CategoriesJSON, &job.PromptVersion, &job.CreatedAt); err != nil {
		if err == sql.ErrNoRows {
			return models.SuggestionJob{}, false, nil
		}
		return models.SuggestionJob{}, false, err
	}
	if lastError.Valid {
		job.LastError = lastError.String
	}

	const updateQ = `UPDATE txn_suggestion_jobs SET status = 'running' WHERE job_id = ? AND status = 'queued';`
	res, err := tx.Exec(updateQ, job.JobID)
	if err != nil {
		return models.SuggestionJob{}, false, err
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		return models.SuggestionJob{}, false, nil
	}

	if err := tx.Commit(); err != nil {
		return models.SuggestionJob{}, false, err
	}
	job.Status = "running"
	return job, true, nil
}

func UpdateSuggestionJob(db *sql.DB, jobID int64, status string, attempts int, lastError string) error {
	const q = `
UPDATE txn_suggestion_jobs
SET status = ?,
    attempts = ?,
    last_error = ?
WHERE job_id = ?;
`
	_, err := db.Exec(q, status, attempts, nullIfEmpty(lastError), jobID)
	return err
}

func FindLatestCategoryForPayee(db *sql.DB, accountID, payee string) (string, string, bool, error) {
	const q = `
SELECT category, subcategory
FROM transactions
WHERE account_id = ?
  AND LOWER(TRIM(payee)) = ?
  AND category IS NOT NULL
  AND category <> ''
ORDER BY posted_date DESC
LIMIT 1;
`
	row := db.QueryRow(q, accountID, payee)
	var category string
	var subcategory sql.NullString
	if err := row.Scan(&category, &subcategory); err != nil {
		if err == sql.ErrNoRows {
			return "", "", false, nil
		}
		return "", "", false, err
	}
	outSub := ""
	if subcategory.Valid {
		outSub = subcategory.String
	}
	return category, outSub, true, nil
}

func CountRecentCategoryForPayee(db *sql.DB, accountID, payee, category, subcategory string, limit int) (int, error) {
	if limit <= 0 {
		return 0, nil
	}
	const q = `
SELECT category, subcategory
FROM transactions
WHERE account_id = ?
  AND LOWER(TRIM(payee)) = ?
  AND category IS NOT NULL
  AND category <> ''
ORDER BY posted_date DESC
LIMIT ?;
`
	rows, err := db.Query(q, accountID, payee, limit)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	count := 0
	for rows.Next() {
		var cat string
		var sub sql.NullString
		if err := rows.Scan(&cat, &sub); err != nil {
			return 0, err
		}
		subVal := ""
		if sub.Valid {
			subVal = sub.String
		}
		if strings.EqualFold(cat, category) && strings.EqualFold(subVal, subcategory) {
			count++
		}
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}
	return count, nil
}

func GetSuggestionCacheEntry(db *sql.DB, cacheKey string) (models.SuggestionCacheEntry, bool, error) {
	const q = `
SELECT cache_key, status, category, subcategory, confidence, model_id, suggested_at, prompt_version
FROM txn_suggestion_cache
WHERE cache_key = ?;
`
	row := db.QueryRow(q, cacheKey)
	var entry models.SuggestionCacheEntry
	var category sql.NullString
	var subcategory sql.NullString
	var confidence sql.NullFloat64
	var modelID sql.NullString
	if err := row.Scan(&entry.CacheKey, &entry.Status, &category, &subcategory, &confidence, &modelID, &entry.SuggestedAt, &entry.PromptVersion); err != nil {
		if err == sql.ErrNoRows {
			return models.SuggestionCacheEntry{}, false, nil
		}
		return models.SuggestionCacheEntry{}, false, err
	}
	if category.Valid {
		entry.Category = category.String
	}
	if subcategory.Valid {
		entry.Subcategory = subcategory.String
	}
	if confidence.Valid {
		entry.Confidence = confidence.Float64
	}
	if modelID.Valid {
		entry.ModelID = modelID.String
	}
	return entry, true, nil
}

func UpsertSuggestionCacheEntry(db *sql.DB, entry models.SuggestionCacheEntry) error {
	const q = `
INSERT INTO txn_suggestion_cache (
  cache_key, status, category, subcategory, confidence, model_id, suggested_at, prompt_version
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(cache_key) DO UPDATE SET
  status = excluded.status,
  category = excluded.category,
  subcategory = excluded.subcategory,
  confidence = excluded.confidence,
  model_id = excluded.model_id,
  suggested_at = excluded.suggested_at,
  prompt_version = excluded.prompt_version;
`
	_, err := db.Exec(q,
		entry.CacheKey,
		entry.Status,
		nullIfEmpty(entry.Category),
		nullIfEmpty(entry.Subcategory),
		nullFloatIfZero(entry.Confidence),
		nullIfEmpty(entry.ModelID),
		entry.SuggestedAt,
		entry.PromptVersion,
	)
	return err
}

func nullFloatIfZero(value float64) interface{} {
	if value == 0 {
		return nil
	}
	return value
}

func nullIntIfZero(value int) interface{} {
	if value == 0 {
		return nil
	}
	return value
}
