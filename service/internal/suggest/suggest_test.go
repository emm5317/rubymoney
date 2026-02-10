package suggest

import (
	"database/sql"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"budgetexcel/service/internal/db"
	"budgetexcel/service/internal/models"
)

func TestParseModelResponse(t *testing.T) {
	raw := "some text\n{\"txn_id\":\"t1\",\"suggested\":true,\"category\":\"Food\",\"subcategory\":\"Groceries\"}\nmore"
	resp, err := ParseModelResponse("t1", raw)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if !resp.Suggested || resp.Category != "Food" || resp.Subcategory != "Groceries" {
		t.Fatalf("unexpected response: %+v", resp)
	}

	if _, err := ParseModelResponse("t1", "not json"); err == nil {
		t.Fatalf("expected error for invalid JSON")
	}
}

func TestAllowListValidation(t *testing.T) {
	allow := BuildAllowList([]CategoryAllowList{
		{Name: "Food", Subcategories: []string{"Groceries", "Dining"}},
	})
	if !allow.IsValid("food", "groceries") {
		t.Fatalf("expected allow list to accept case-insensitive match")
	}
	if allow.IsValid("Food", "Fuel") {
		t.Fatalf("expected allow list to reject unknown subcategory")
	}
}

func TestComputeConfidence(t *testing.T) {
	database, cleanup := openTestDB(t)
	defer cleanup()

	accountID := "acc-1"
	insertAccount(t, database, accountID)

	now := time.Date(2026, 2, 10, 12, 0, 0, 0, time.UTC)
	_, err := database.Exec(`
INSERT INTO transactions (txn_id, account_id, posted_date, amount, payee, memo, pending, fingerprint, category, subcategory, category_source, imported_at)
VALUES ('txn-prev', ?, '2026-02-01', -12.00, 'COFFEE SHOP', 'LATTE', 0, 'f1', 'Food', 'Dining', 'rule:test', ?);
`, accountID, now.Format(time.RFC3339))
	if err != nil {
		t.Fatalf("insert txn: %v", err)
	}

	orch, err := NewOrchestrator(database, Config{})
	if err != nil {
		t.Fatalf("orchestrator: %v", err)
	}
	orch.now = func() time.Time { return now }

	txn := models.Transaction{
		TxnID:     "txn-new",
		AccountID: accountID,
		Payee:     "COFFEE SHOP",
		Memo:      "TEST",
	}

	conf, reason, err := orch.computeConfidence(txn, "Food", "Dining")
	if err != nil {
		t.Fatalf("confidence: %v", err)
	}
	if conf < 0.79 || conf > 0.81 {
		t.Fatalf("unexpected confidence: %f", conf)
	}
	if reason != "payee_exact" {
		t.Fatalf("unexpected reason: %s", reason)
	}
}

func TestCacheKeyStability(t *testing.T) {
	txn := models.Transaction{
		Payee: "Coffee  Shop",
		Memo:  "Latte",
	}
	key1 := buildCacheKey(txn, "checking")

	txn.Payee = "coffee shop"
	key2 := buildCacheKey(txn, "checking")

	if key1 != key2 {
		t.Fatalf("expected stable cache key")
	}
}

func TestCacheVersionInvalidation(t *testing.T) {
	orch, err := NewOrchestrator(nil, Config{CacheTTL: 2 * time.Hour})
	if err != nil {
		t.Fatalf("orchestrator: %v", err)
	}
	orch.now = func() time.Time { return time.Date(2026, 2, 10, 12, 0, 0, 0, time.UTC) }

	entry := models.SuggestionCacheEntry{
		CacheKey:      "k",
		Status:        StatusSuggested,
		Category:      "Food",
		Subcategory:   "Dining",
		Confidence:    0.7,
		ModelID:       "m",
		SuggestedAt:   time.Date(2026, 2, 9, 9, 0, 0, 0, time.UTC).Format(time.RFC3339),
		PromptVersion: "old",
	}
	if orch.cacheValid(entry) {
		t.Fatalf("expected cache invalidation on prompt version mismatch")
	}
}

func openTestDB(t *testing.T) (*sql.DB, func()) {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "test.sqlite")
	if err := db.RunMigrations(dbPath, filepath.Join(projectRoot(t), "service", "migrations")); err != nil {
		t.Fatalf("migrations: %v", err)
	}
	database, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	return database, func() { database.Close() }
}

func insertAccount(t *testing.T, database *sql.DB, accountID string) {
	t.Helper()
	now := time.Now().UTC().Format(time.RFC3339)
	_, err := database.Exec(`INSERT INTO accounts (account_id, display_name, account_type, institution, connector_type, created_at, updated_at)
VALUES (?, 'Test', 'checking', 'TestBank', 'csv', ?, ?);`, accountID, now, now)
	if err != nil {
		t.Fatalf("insert account: %v", err)
	}
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
