package api

import (
	"database/sql"
	"fmt"
	"path/filepath"
	"time"

	"budgetexcel/service/internal/connectors/csv"
	"budgetexcel/service/internal/db"
	"budgetexcel/service/internal/logging"
	"budgetexcel/service/internal/models"
	"budgetexcel/service/internal/rules"
	syncer "budgetexcel/service/internal/sync"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type API struct {
	DB      *sql.DB
	Started time.Time
	Version string
	DBPath  string
}

func RegisterRoutes(app *fiber.App, api *API) {
	app.Get("/v1/health", api.health)
	app.Get("/v1/diagnostics", api.diagnostics)
	app.Post("/v1/rules/import", api.rulesImport)
	app.Post("/v1/rules/apply", api.rulesApply)
	app.Post("/v1/overrides/import", api.overridesImport)
	app.Get("/v1/transactions", api.transactions)
	app.Post("/v1/sync", api.sync)
}

type errorEnvelope struct {
	Error errorBody `json:"error"`
}

type errorBody struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

func writeError(c *fiber.Ctx, status int, code, message string, details interface{}) error {
	return c.Status(status).JSON(errorEnvelope{
		Error: errorBody{Code: code, Message: message, Details: details},
	})
}

func (a *API) health(c *fiber.Ctx) error {
	lastSyncAt, _ := a.lastSyncTime()

	resp := fiber.Map{
		"version":    a.Version,
		"uptime_sec": int(time.Since(a.Started).Seconds()),
		"db_path":    a.DBPath,
		"last_sync":  lastSyncAt,
	}
	return c.JSON(resp)
}

type diagnosticsResponse struct {
	LastSyncAt string `json:"last_sync_at,omitempty"`
	Status     string `json:"status,omitempty"`
	Summary    string `json:"summary_json,omitempty"`
}

func (a *API) diagnostics(c *fiber.Ctx) error {
	const q = `SELECT ended_at, status, summary_json FROM sync_runs ORDER BY ended_at DESC LIMIT 1`
	row := a.DB.QueryRow(q)

	var endedAt, status, summary sql.NullString
	if err := row.Scan(&endedAt, &status, &summary); err != nil {
		if err == sql.ErrNoRows {
			return c.JSON(diagnosticsResponse{})
		}
		return writeError(c, fiber.StatusInternalServerError, "diagnostics_failed", "failed to load diagnostics", err.Error())
	}

	resp := diagnosticsResponse{}
	if endedAt.Valid {
		resp.LastSyncAt = endedAt.String
	}
	if status.Valid {
		resp.Status = status.String
	}
	if summary.Valid {
		resp.Summary = logging.RedactString(summary.String)
	}

	return c.JSON(resp)
}

type rulesImportRequest struct {
	Rules []models.Rule `json:"rules"`
}

func (a *API) rulesImport(c *fiber.Ctx) error {
	var req rulesImportRequest
	if err := c.BodyParser(&req); err != nil {
		return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
	}
	if len(req.Rules) == 0 {
		return writeError(c, fiber.StatusBadRequest, "empty_rules", "rules list is empty", nil)
	}

	if err := db.UpsertRules(a.DB, req.Rules); err != nil {
		return writeError(c, fiber.StatusInternalServerError, "rules_upsert_failed", "failed to upsert rules", err.Error())
	}

	return c.JSON(fiber.Map{"status": "ok", "count": len(req.Rules)})
}

type rulesApplyRequest struct {
	Force bool `json:"force"`
}

type rulesApplyResponse struct {
	Status  string `json:"status"`
	Applied int    `json:"applied"`
	Cleared int    `json:"cleared"`
	Total   int    `json:"total"`
}

func (a *API) rulesApply(c *fiber.Ctx) error {
	var req rulesApplyRequest
	if len(c.Body()) > 0 {
		if err := c.BodyParser(&req); err != nil {
			return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
		}
	}

	allRules, err := db.ListRules(a.DB)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "rules_load_failed", "failed to load rules", err.Error())
	}

	txns, err := db.ListTransactionsForRules(a.DB, req.Force)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "transactions_load_failed", "failed to load transactions", err.Error())
	}

	overrideIDs, err := db.ListOverrideTxnIDs(a.DB)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "overrides_load_failed", "failed to load overrides", err.Error())
	}

	applied := 0
	cleared := 0

	for _, txn := range txns {
		if _, ok := overrideIDs[txn.TxnID]; ok {
			continue
		}

		result, matched := rules.ApplyRules(txn, allRules)
		if matched {
			if err := db.UpdateTransactionCategory(a.DB, txn.TxnID, result.Category, result.Subcategory, "rule:"+result.MatchedRuleID); err != nil {
				return writeError(c, fiber.StatusInternalServerError, "rules_apply_failed", "failed to update transaction", err.Error())
			}
			applied++
			continue
		}

		if req.Force {
			if err := db.UpdateTransactionCategory(a.DB, txn.TxnID, "", "", "uncategorized"); err != nil {
				return writeError(c, fiber.StatusInternalServerError, "rules_clear_failed", "failed to clear category", err.Error())
			}
			cleared++
		}
	}

	return c.JSON(rulesApplyResponse{
		Status:  "ok",
		Applied: applied,
		Cleared: cleared,
		Total:   len(txns),
	})
}

type overridesImportRequest struct {
	Overrides []models.Override `json:"overrides"`
}

func (a *API) overridesImport(c *fiber.Ctx) error {
	var req overridesImportRequest
	if err := c.BodyParser(&req); err != nil {
		return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
	}
	if len(req.Overrides) == 0 {
		return writeError(c, fiber.StatusBadRequest, "empty_overrides", "overrides list is empty", nil)
	}

	now := time.Now().UTC().Format(time.RFC3339)
	for i := range req.Overrides {
		if req.Overrides[i].UpdatedAt == "" {
			req.Overrides[i].UpdatedAt = now
		}
	}

	if err := db.UpsertOverrides(a.DB, req.Overrides); err != nil {
		return writeError(c, fiber.StatusInternalServerError, "overrides_upsert_failed", "failed to upsert overrides", err.Error())
	}

	return c.JSON(fiber.Map{"status": "ok", "count": len(req.Overrides)})
}

func (a *API) transactions(c *fiber.Ctx) error {
	since := c.Query("since")
	if since == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_since", "query parameter 'since' is required", nil)
	}

	txns, err := db.ListTransactionsSince(a.DB, since)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "transactions_failed", "failed to load transactions", err.Error())
	}

	return c.JSON(fiber.Map{"transactions": txns})
}

type syncRequest struct {
	Since            string                 `json:"since"`
	AccountIDs       []string               `json:"account_ids,omitempty"`
	ConnectorOptions map[string]interface{} `json:"connector_options,omitempty"`
}

type syncResponse struct {
	Status     string   `json:"status"`
	Imported   int      `json:"imported"`
	Updated    int      `json:"updated"`
	Matched    int      `json:"matched_pending"`
	Skipped    int      `json:"skipped"`
	BadRows    int      `json:"bad_rows"`
	BadRowInfo []string `json:"bad_row_info,omitempty"`
}

func (a *API) sync(c *fiber.Ctx) error {
	var req syncRequest
	if err := c.BodyParser(&req); err != nil {
		return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
	}
	if req.Since == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_since", "field 'since' is required", nil)
	}

	if len(req.AccountIDs) == 0 {
		return writeError(c, fiber.StatusBadRequest, "missing_account_id", "account_ids must include exactly one account_id for CSV sync", nil)
	}
	if len(req.AccountIDs) != 1 {
		return writeError(c, fiber.StatusBadRequest, "multiple_account_ids", "CSV sync supports exactly one account_id", nil)
	}

	csvPath, err := csvPathFromOptions(req.ConnectorOptions)
	if err != nil {
		return writeError(c, fiber.StatusBadRequest, "invalid_connector_options", err.Error(), nil)
	}
	if csvPath == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_csv_path", "connector_options.csv_path is required for CSV sync", nil)
	}

	result, err := csv.ImportFile(csvPath, csv.ImportOptions{})
	if err != nil {
		return writeError(c, fiber.StatusBadRequest, "csv_import_failed", err.Error(), nil)
	}

	accountID := req.AccountIDs[0]
	now := time.Now().UTC().Format(time.RFC3339)

	imported := 0
	updated := 0
	matchedPending := 0

	for _, row := range result.Rows {
		txn := models.Transaction{
			TxnID:          uuid.NewString(),
			AccountID:      accountID,
			PostedDate:     row.Date,
			Amount:         row.Amount,
			Payee:          row.Payee,
			Memo:           row.Memo,
			CategorySource: "uncategorized",
			Pending:        false,
			ImportedAt:     now,
		}

		txn.Fingerprint = syncer.Fingerprint(accountID, txn.PostedDate, txn.Amount, txn.Payee, txn.Memo)

		if matchID, ok, err := db.FindPendingMatch(a.DB, accountID, txn.PostedDate, txn.Amount, txn.Payee, txn.Memo); err != nil {
			return writeError(c, fiber.StatusInternalServerError, "pending_match_failed", "failed pending match query", err.Error())
		} else if ok {
			if err := db.UpdatePendingToPosted(a.DB, matchID, txn); err != nil {
				return writeError(c, fiber.StatusInternalServerError, "pending_update_failed", "failed pending update", err.Error())
			}
			matchedPending++
			continue
		}

		created, updatedRow, err := db.UpsertTransaction(a.DB, txn)
		if err != nil {
			return writeError(c, fiber.StatusInternalServerError, "txn_upsert_failed", "failed to upsert transaction", err.Error())
		}
		if created {
			imported++
		} else if updatedRow {
			updated++
		}
	}

	resp := syncResponse{
		Status:     "imported",
		Imported:   imported,
		Updated:    updated,
		Matched:    matchedPending,
		Skipped:    result.Skipped,
		BadRows:    result.BadRows,
		BadRowInfo: result.BadRowInfo,
	}

	return c.JSON(resp)
}

func csvPathFromOptions(options map[string]interface{}) (string, error) {
	if options == nil {
		return "", nil
	}
	raw, ok := options["csv_path"]
	if !ok {
		return "", nil
	}
	path, ok := raw.(string)
	if !ok {
		return "", fmt.Errorf("connector_options.csv_path must be a string")
	}
	path = filepath.Clean(path)
	return path, nil
}

func (a *API) lastSyncTime() (string, error) {
	const q = `SELECT ended_at FROM sync_runs ORDER BY ended_at DESC LIMIT 1`
	row := a.DB.QueryRow(q)

	var endedAt sql.NullString
	if err := row.Scan(&endedAt); err != nil {
		if err == sql.ErrNoRows {
			return "", nil
		}
		return "", err
	}
	if !endedAt.Valid {
		return "", nil
	}
	return endedAt.String, nil
}
