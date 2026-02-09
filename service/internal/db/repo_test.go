package db

import (
	"database/sql"
	"path/filepath"
	"testing"
	"time"
	"runtime"

	"budgetexcel/service/internal/models"
	syncer "budgetexcel/service/internal/sync"
)

func TestUpsertTransaction_Idempotent(t *testing.T) {
	db, cleanup := openTestDB(t)
	defer cleanup()

	accountID := "acc-1"
	insertAccount(t, db, accountID)

	txn := models.Transaction{
		TxnID:          "txn-1",
		AccountID:      accountID,
		PostedDate:     "2026-02-01",
		Amount:         -5.25,
		Payee:          "COFFEE SHOP",
		Memo:           "LATTE",
		CategorySource: "uncategorized",
		Pending:        false,
		ImportedAt:     time.Now().UTC().Format(time.RFC3339),
	}
	txn.Fingerprint = syncer.Fingerprint(accountID, txn.PostedDate, txn.Amount, txn.Payee, txn.Memo)

	created, updated, err := UpsertTransaction(db, txn)
	if err != nil {
		t.Fatalf("upsert 1: %v", err)
	}
	if !created || updated {
		t.Fatalf("expected created true updated false")
	}

	txn.Memo = "LATTE BIG"
	created, updated, err = UpsertTransaction(db, txn)
	if err != nil {
		t.Fatalf("upsert 2: %v", err)
	}
	if created || !updated {
		t.Fatalf("expected created false updated true")
	}

	count := countRows(t, db, "transactions")
	if count != 1 {
		t.Fatalf("expected 1 transaction, got %d", count)
	}
}

func TestPendingReconciliation(t *testing.T) {
	db, cleanup := openTestDB(t)
	defer cleanup()

	accountID := "acc-1"
	insertAccount(t, db, accountID)

	pendingTxn := models.Transaction{
		TxnID:          "txn-pending",
		AccountID:      accountID,
		PostedDate:     "2026-02-01",
		Amount:         -10.0,
		Payee:          "GROCERY",
		Memo:           "FOOD",
		CategorySource: "uncategorized",
		Pending:        true,
		ImportedAt:     time.Now().UTC().Format(time.RFC3339),
		Fingerprint:    syncer.Fingerprint(accountID, "2026-02-01", -10.0, "GROCERY", "FOOD"),
	}

	if _, _, err := UpsertTransaction(db, pendingTxn); err != nil {
		t.Fatalf("upsert pending: %v", err)
	}

	matchID, ok, err := FindPendingMatch(db, accountID, "2026-02-03", -10.0, "GROCERY", "FOOD")
	if err != nil {
		t.Fatalf("find pending: %v", err)
	}
	if !ok {
		t.Fatalf("expected pending match")
	}

	posted := pendingTxn
	posted.PostedDate = "2026-02-03"
	posted.Pending = false
	posted.ImportedAt = time.Now().UTC().Format(time.RFC3339)
	posted.Fingerprint = syncer.Fingerprint(accountID, posted.PostedDate, posted.Amount, posted.Payee, posted.Memo)

	if err := UpdatePendingToPosted(db, matchID, posted); err != nil {
		t.Fatalf("update pending: %v", err)
	}

	pendingCount := countWhere(t, db, "transactions", "pending = 1")
	if pendingCount != 0 {
		t.Fatalf("expected pending count 0, got %d", pendingCount)
	}
}

func TestOverridesList(t *testing.T) {
	db, cleanup := openTestDB(t)
	defer cleanup()

	accountID := "acc-1"
	insertAccount(t, db, accountID)

	txn := models.Transaction{
		TxnID:          "txn-1",
		AccountID:      accountID,
		PostedDate:     "2026-02-01",
		Amount:         -5.0,
		Payee:          "TEST",
		Memo:           "TEST",
		CategorySource: "uncategorized",
		Pending:        false,
		ImportedAt:     time.Now().UTC().Format(time.RFC3339),
		Fingerprint:    syncer.Fingerprint(accountID, "2026-02-01", -5.0, "TEST", "TEST"),
	}

	if _, _, err := UpsertTransaction(db, txn); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	overrides := []models.Override{{
		TxnID:       txn.TxnID,
		Category:    "Food",
		Subcategory: "Coffee",
		UpdatedAt:   time.Now().UTC().Format(time.RFC3339),
	}}

	if err := UpsertOverrides(db, overrides); err != nil {
		t.Fatalf("upsert overrides: %v", err)
	}

	ids, err := ListOverrideTxnIDs(db)
	if err != nil {
		t.Fatalf("list overrides: %v", err)
	}
	if _, ok := ids[txn.TxnID]; !ok {
		t.Fatalf("expected txn_id in override list")
	}
}

func openTestDB(t *testing.T) (*sql.DB, func()) {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "test.sqlite")
	if err := RunMigrations(dbPath, filepath.Join(projectRoot(t), "service", "migrations")); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	db, err := Open(dbPath)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	return db, func() { db.Close() }
}

func insertAccount(t *testing.T, db *sql.DB, accountID string) {
	t.Helper()
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := db.Exec(`INSERT INTO accounts (account_id, display_name, account_type, institution, connector_type, created_at, updated_at)
VALUES (?, 'Test', 'checking', 'TestBank', 'csv', ?, ?);`, accountID, now, now)
	if err != nil {
		t.Fatalf("insert account: %v", err)
	}
}

func countRows(t *testing.T, db *sql.DB, table string) int {
	t.Helper()
	row := db.QueryRow("SELECT COUNT(*) FROM " + table)
	var count int
	if err := row.Scan(&count); err != nil {
		t.Fatalf("count rows: %v", err)
	}
	return count
}

func countWhere(t *testing.T, db *sql.DB, table, where string) int {
	t.Helper()
	row := db.QueryRow("SELECT COUNT(*) FROM " + table + " WHERE " + where)
	var count int
	if err := row.Scan(&count); err != nil {
		t.Fatalf("count rows: %v", err)
	}
	return count
}

func projectRoot(t *testing.T) string {
	path := __file__()
	dir := filepath.Dir(path)
	for i := 0; i < 3; i++ {
		dir = filepath.Dir(dir)
	}
	return dir
}

func __file__() string {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return ""
	}
	return file
}
