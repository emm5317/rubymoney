package db

import (
	"database/sql"
	"fmt"

	"budgetexcel/service/internal/models"
	syncer "budgetexcel/service/internal/sync"
)

func UpsertRules(db *sql.DB, rules []models.Rule) error {
	if len(rules) == 0 {
		return nil
	}

	const q = `
INSERT INTO rules (
  rule_id, priority, enabled, match_field, match_type, match_value, category, subcategory, notes
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(rule_id) DO UPDATE SET
  priority = excluded.priority,
  enabled = excluded.enabled,
  match_field = excluded.match_field,
  match_type = excluded.match_type,
  match_value = excluded.match_value,
  category = excluded.category,
  subcategory = excluded.subcategory,
  notes = excluded.notes;
`

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(q)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, r := range rules {
		enabled := 0
		if r.Enabled {
			enabled = 1
		}
		if _, err := stmt.Exec(
			r.RuleID, r.Priority, enabled, r.MatchField, r.MatchType, r.MatchValue, r.Category, r.Subcategory, nullIfEmpty(r.Notes),
		); err != nil {
			return fmt.Errorf("upsert rule %s: %w", r.RuleID, err)
		}
	}

	return tx.Commit()
}

func UpsertOverrides(db *sql.DB, overrides []models.Override) error {
	if len(overrides) == 0 {
		return nil
	}

	const q = `
INSERT INTO overrides (txn_id, category, subcategory, updated_at)
VALUES (?, ?, ?, ?)
ON CONFLICT(txn_id) DO UPDATE SET
  category = excluded.category,
  subcategory = excluded.subcategory,
  updated_at = excluded.updated_at;
`

	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(q)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, o := range overrides {
		if _, err := stmt.Exec(o.TxnID, o.Category, o.Subcategory, o.UpdatedAt); err != nil {
			return fmt.Errorf("upsert override %s: %w", o.TxnID, err)
		}
	}

	return tx.Commit()
}

func ListTransactionsSince(db *sql.DB, since string) ([]models.Transaction, error) {
	const q = `
SELECT txn_id, external_txn_id, account_id, posted_date, amount, payee, memo,
       category, subcategory, category_source, pending, fingerprint, raw_ref, imported_at
FROM transactions
WHERE posted_date >= ?
ORDER BY posted_date DESC;
`

	rows, err := db.Query(q, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := []models.Transaction{}
	for rows.Next() {
		var t models.Transaction
		var extID sql.NullString
		var category sql.NullString
		var subcategory sql.NullString
		var rawRef sql.NullString
		var pendingInt int

		if err := rows.Scan(
			&t.TxnID, &extID, &t.AccountID, &t.PostedDate, &t.Amount, &t.Payee, &t.Memo,
			&category, &subcategory, &t.CategorySource, &pendingInt, &t.Fingerprint, &rawRef, &t.ImportedAt,
		); err != nil {
			return nil, err
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
		if rawRef.Valid {
			t.RawRef = rawRef.String
		}
		t.Pending = pendingInt == 1

		result = append(result, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	return result, nil
}

func GetLastSyncRun(db *sql.DB) (models.SyncRun, bool, error) {
	const q = `SELECT sync_run_id, started_at, ended_at, since, status, summary_json FROM sync_runs ORDER BY ended_at DESC LIMIT 1`
	row := db.QueryRow(q)

	var r models.SyncRun
	var endedAt sql.NullString
	if err := row.Scan(&r.SyncRunID, &r.StartedAt, &endedAt, &r.Since, &r.Status, &r.SummaryJSON); err != nil {
		if err == sql.ErrNoRows {
			return models.SyncRun{}, false, nil
		}
		return models.SyncRun{}, false, err
	}
	if endedAt.Valid {
		r.EndedAt = endedAt.String
	}
	return r, true, nil
}

func nullIfEmpty(value string) interface{} {
	if value == "" {
		return nil
	}
	return value
}

func FindPendingMatch(db *sql.DB, accountID, postedDate string, amount float64, payee, memo string) (string, bool, error) {
	const q = `
SELECT txn_id, payee, memo
FROM transactions
WHERE account_id = ?
  AND pending = 1
  AND amount = ?
  AND posted_date >= date(?, '-7 days')
  AND posted_date <= date(?, '+7 days');
`
	rows, err := db.Query(q, accountID, amount, postedDate, postedDate)
	if err != nil {
		return "", false, err
	}
	defer rows.Close()

	targetPayee := syncer.NormalizeString(payee)
	targetMemo := syncer.NormalizeString(memo)

	for rows.Next() {
		var txnID string
		var rowPayee, rowMemo string
		if err := rows.Scan(&txnID, &rowPayee, &rowMemo); err != nil {
			return "", false, err
		}
		if syncer.NormalizeString(rowPayee) == targetPayee || syncer.NormalizeString(rowMemo) == targetMemo {
			return txnID, true, nil
		}
	}
	if err := rows.Err(); err != nil {
		return "", false, err
	}

	return "", false, nil
}

func UpdatePendingToPosted(db *sql.DB, txnID string, updated models.Transaction) error {
	const q = `
UPDATE transactions
SET posted_date = ?,
    amount = ?,
    payee = ?,
    memo = ?,
    pending = 0,
    fingerprint = ?,
    external_txn_id = COALESCE(?, external_txn_id),
    raw_ref = ?,
    imported_at = ?
WHERE txn_id = ?;
`
	_, err := db.Exec(q, updated.PostedDate, updated.Amount, updated.Payee, updated.Memo, updated.Fingerprint, nullIfEmpty(updated.ExternalTxnID), nullIfEmpty(updated.RawRef), updated.ImportedAt, txnID)
	return err
}

func UpsertTransaction(db *sql.DB, t models.Transaction) (bool, bool, error) {
	if t.AccountID == "" {
		return false, false, fmt.Errorf("account_id is required")
	}
	if t.PostedDate == "" {
		return false, false, fmt.Errorf("posted_date is required")
	}
	if t.Fingerprint == "" {
		t.Fingerprint = syncer.Fingerprint(t.AccountID, t.PostedDate, t.Amount, t.Payee, t.Memo)
	}

	if t.ExternalTxnID != "" {
		const insertQ = `
INSERT OR IGNORE INTO transactions (
  txn_id, external_txn_id, account_id, posted_date, amount, payee, memo, pending,
  fingerprint, category, subcategory, category_source, raw_ref, imported_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
`
		res, err := db.Exec(insertQ,
			t.TxnID, t.ExternalTxnID, t.AccountID, t.PostedDate, t.Amount, t.Payee, t.Memo, boolToInt(t.Pending),
			t.Fingerprint, nullIfEmpty(t.Category), nullIfEmpty(t.Subcategory), t.CategorySource, nullIfEmpty(t.RawRef), t.ImportedAt,
		)
		if err != nil {
			return false, false, err
		}
		rows, _ := res.RowsAffected()
		if rows > 0 {
			return true, false, nil
		}

		const updateQ = `
UPDATE transactions SET
  posted_date = ?,
  amount = ?,
  payee = ?,
  memo = ?,
  pending = ?,
  fingerprint = ?,
  raw_ref = ?,
  imported_at = ?,
  category = CASE WHEN category IS NULL OR category = '' THEN ? ELSE category END,
  subcategory = CASE WHEN subcategory IS NULL OR subcategory = '' THEN ? ELSE subcategory END,
  category_source = CASE WHEN category_source IS NULL OR category_source = '' THEN ? ELSE category_source END
WHERE account_id = ? AND external_txn_id = ?;
`
		if _, err := db.Exec(updateQ,
			t.PostedDate, t.Amount, t.Payee, t.Memo, boolToInt(t.Pending), t.Fingerprint, nullIfEmpty(t.RawRef), t.ImportedAt,
			nullIfEmpty(t.Category), nullIfEmpty(t.Subcategory), t.CategorySource, t.AccountID, t.ExternalTxnID,
		); err != nil {
			return false, false, err
		}
		return false, true, nil
	}

	const insertQ = `
INSERT OR IGNORE INTO transactions (
  txn_id, external_txn_id, account_id, posted_date, amount, payee, memo, pending,
  fingerprint, category, subcategory, category_source, raw_ref, imported_at
) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
`
	res, err := db.Exec(insertQ,
		t.TxnID, t.AccountID, t.PostedDate, t.Amount, t.Payee, t.Memo, boolToInt(t.Pending),
		t.Fingerprint, nullIfEmpty(t.Category), nullIfEmpty(t.Subcategory), t.CategorySource, nullIfEmpty(t.RawRef), t.ImportedAt,
	)
	if err != nil {
		return false, false, err
	}
	rows, _ := res.RowsAffected()
	if rows > 0 {
		return true, false, nil
	}

	const updateQ = `
UPDATE transactions SET
  posted_date = ?,
  amount = ?,
  payee = ?,
  memo = ?,
  pending = ?,
  raw_ref = ?,
  imported_at = ?,
  category = CASE WHEN category IS NULL OR category = '' THEN ? ELSE category END,
  subcategory = CASE WHEN subcategory IS NULL OR subcategory = '' THEN ? ELSE subcategory END,
  category_source = CASE WHEN category_source IS NULL OR category_source = '' THEN ? ELSE category_source END
WHERE account_id = ? AND fingerprint = ? AND external_txn_id IS NULL;
`
	if _, err := db.Exec(updateQ,
		t.PostedDate, t.Amount, t.Payee, t.Memo, boolToInt(t.Pending), nullIfEmpty(t.RawRef), t.ImportedAt,
		nullIfEmpty(t.Category), nullIfEmpty(t.Subcategory), t.CategorySource, t.AccountID, t.Fingerprint,
	); err != nil {
		return false, false, err
	}
	return false, true, nil
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func ListRules(db *sql.DB) ([]models.Rule, error) {
	const q = `
SELECT rule_id, priority, enabled, match_field, match_type, match_value, category, subcategory, notes
FROM rules
ORDER BY priority ASC, rule_id ASC;
`
	rows, err := db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Rule
	for rows.Next() {
		var r models.Rule
		var enabled int
		var notes sql.NullString
		if err := rows.Scan(&r.RuleID, &r.Priority, &enabled, &r.MatchField, &r.MatchType, &r.MatchValue, &r.Category, &r.Subcategory, &notes); err != nil {
			return nil, err
		}
		r.Enabled = enabled == 1
		if notes.Valid {
			r.Notes = notes.String
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func ListTransactionsForRules(db *sql.DB, force bool) ([]models.Transaction, error) {
	q := `
SELECT txn_id, external_txn_id, account_id, posted_date, amount, payee, memo,
       category, subcategory, category_source, pending, fingerprint, raw_ref, imported_at
FROM transactions
`
	if !force {
		q += "WHERE (category IS NULL OR category = '' OR category_source = 'uncategorized')"
	}
	q += " ORDER BY posted_date DESC;"

	rows, err := db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Transaction
	for rows.Next() {
		var t models.Transaction
		var extID sql.NullString
		var category sql.NullString
		var subcategory sql.NullString
		var rawRef sql.NullString
		var pendingInt int

		if err := rows.Scan(
			&t.TxnID, &extID, &t.AccountID, &t.PostedDate, &t.Amount, &t.Payee, &t.Memo,
			&category, &subcategory, &t.CategorySource, &pendingInt, &t.Fingerprint, &rawRef, &t.ImportedAt,
		); err != nil {
			return nil, err
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
		if rawRef.Valid {
			t.RawRef = rawRef.String
		}
		t.Pending = pendingInt == 1

		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func ListOverrideTxnIDs(db *sql.DB) (map[string]struct{}, error) {
	const q = `SELECT txn_id FROM overrides;`
	rows, err := db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := map[string]struct{}{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out[id] = struct{}{}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func UpdateTransactionCategory(db *sql.DB, txnID, category, subcategory, source string) error {
	const q = `
UPDATE transactions
SET category = ?,
    subcategory = ?,
    category_source = ?
WHERE txn_id = ?;
`
	_, err := db.Exec(q, nullIfEmpty(category), nullIfEmpty(subcategory), source, txnID)
	return err
}
