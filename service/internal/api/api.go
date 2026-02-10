package api

import (
	"context"
	"database/sql"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"budgetexcel/service/internal/connectors/csv"
	"budgetexcel/service/internal/db"
	"budgetexcel/service/internal/logging"
	"budgetexcel/service/internal/models"
	"budgetexcel/service/internal/rules"
	"budgetexcel/service/internal/suggest"
	syncer "budgetexcel/service/internal/sync"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type API struct {
	DB          *sql.DB
	Started     time.Time
	Version     string
	DBPath      string
	Suggestions *suggest.Orchestrator
}

func RegisterRoutes(app *fiber.App, api *API) {
	app.Get("/v1/health", api.health)
	app.Get("/v1/diagnostics", api.diagnostics)
	app.Post("/v1/rules/import", api.rulesImport)
	app.Post("/v1/rules/apply", api.rulesApply)
	app.Post("/v1/overrides/import", api.overridesImport)
	app.Get("/v1/transactions", api.transactions)
	app.Post("/v1/categories/suggest", api.suggestCategories)
	app.Post("/v1/transactions/:id/suggestion/accept", api.suggestionAccept)
	app.Post("/v1/transactions/:id/suggestion/reject", api.suggestionReject)
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
	includeSuggestions := strings.ToLower(c.Query("include_suggestions")) == "true"

	txns, err := db.ListTransactionsSince(a.DB, since, includeSuggestions)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "transactions_failed", "failed to load transactions", err.Error())
	}

	return c.JSON(fiber.Map{"transactions": txns})
}

type suggestCategoriesRequest struct {
	TxnIDs    []string                   `json:"txn_ids"`
	Mode      string                     `json:"mode"`
	Categories []suggest.CategoryAllowList `json:"categories"`
}

type suggestCategoriesResponse struct {
	Status      string                       `json:"status"`
	Mode        string                       `json:"mode"`
	Enqueued    int                          `json:"enqueued,omitempty"`
	Suggestions []suggestResponse            `json:"suggestions,omitempty"`
}

type suggestResponse struct {
	TxnID       string  `json:"txn_id"`
	Status      string  `json:"status"`
	Category    string  `json:"category,omitempty"`
	Subcategory string  `json:"subcategory,omitempty"`
	Confidence  float64 `json:"confidence,omitempty"`
	ModelID     string  `json:"model_id,omitempty"`
	ReasonCode  string  `json:"reason_code,omitempty"`
}

func (a *API) suggestCategories(c *fiber.Ctx) error {
	if a.Suggestions == nil {
		return writeError(c, fiber.StatusServiceUnavailable, "suggestions_unavailable", "suggestions are not configured", nil)
	}

	var req suggestCategoriesRequest
	if err := c.BodyParser(&req); err != nil {
		return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
	}
	if len(req.TxnIDs) == 0 {
		return writeError(c, fiber.StatusBadRequest, "empty_txn_ids", "txn_ids is required", nil)
	}
	if len(req.Categories) == 0 {
		return writeError(c, fiber.StatusBadRequest, "missing_categories", "categories allow-list is required", nil)
	}
	mode := strings.ToLower(strings.TrimSpace(req.Mode))
	if mode == "" {
		mode = "async"
	}

	if mode == "sync" {
		cfg := a.Suggestions
		if len(req.TxnIDs) > cfg.Config().SyncMaxCount {
			return writeError(c, fiber.StatusBadRequest, "too_many_txns", "sync mode is limited to a small batch", nil)
		}
		results, err := a.Suggestions.SuggestSync(context.Background(), req.TxnIDs, req.Categories)
		if err != nil {
			return writeError(c, fiber.StatusInternalServerError, "suggest_sync_failed", "failed to generate suggestions", err.Error())
		}
		resp := suggestCategoriesResponse{
			Status:      "ok",
			Mode:        "sync",
			Suggestions: mapSuggestResults(results),
		}
		return c.JSON(resp)
	}

	if mode != "async" {
		return writeError(c, fiber.StatusBadRequest, "invalid_mode", "mode must be async or sync", nil)
	}

	count, err := a.Suggestions.Enqueue(req.TxnIDs, req.Categories)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "suggest_enqueue_failed", "failed to enqueue suggestions", err.Error())
	}
	return c.JSON(suggestCategoriesResponse{Status: "ok", Mode: "async", Enqueued: count})
}

type suggestionAcceptRequest struct {
	Category    string `json:"category"`
	Subcategory string `json:"subcategory"`
}

func (a *API) suggestionAccept(c *fiber.Ctx) error {
	txnID := c.Params("id")
	if txnID == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_txn_id", "transaction id is required", nil)
	}

	var req suggestionAcceptRequest
	if len(c.Body()) > 0 {
		if err := c.BodyParser(&req); err != nil {
			return writeError(c, fiber.StatusBadRequest, "invalid_body", "invalid JSON body", err.Error())
		}
	}

	ctxData, ok, err := db.GetSuggestionContext(a.DB, txnID)
	if err != nil {
		return writeError(c, fiber.StatusInternalServerError, "suggestion_load_failed", "failed to load transaction", err.Error())
	}
	if !ok {
		return writeError(c, fiber.StatusNotFound, "txn_not_found", "transaction not found", nil)
	}

	if strings.TrimSpace(ctxData.Transaction.Category) != "" || strings.TrimSpace(ctxData.Transaction.Subcategory) != "" {
		return writeError(c, fiber.StatusConflict, "category_present", "transaction already categorized", nil)
	}

	category := strings.TrimSpace(req.Category)
	subcategory := strings.TrimSpace(req.Subcategory)
	if category == "" {
		category = ctxData.Transaction.SuggestedCategory
	}
	if subcategory == "" {
		subcategory = ctxData.Transaction.SuggestedSubcategory
	}
	if category == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_category", "no suggestion available to accept", nil)
	}

	if err := db.UpdateTransactionCategory(a.DB, txnID, category, subcategory, "suggested"); err != nil {
		return writeError(c, fiber.StatusInternalServerError, "suggestion_apply_failed", "failed to apply suggestion", err.Error())
	}
	_ = db.UpdateSuggestionStatus(a.DB, txnID, "accepted")

	return c.JSON(fiber.Map{"status": "ok"})
}

func (a *API) suggestionReject(c *fiber.Ctx) error {
	txnID := c.Params("id")
	if txnID == "" {
		return writeError(c, fiber.StatusBadRequest, "missing_txn_id", "transaction id is required", nil)
	}

	if err := db.UpdateSuggestionStatus(a.DB, txnID, "rejected"); err != nil {
		return writeError(c, fiber.StatusInternalServerError, "suggestion_reject_failed", "failed to reject suggestion", err.Error())
	}
	return c.JSON(fiber.Map{"status": "ok"})
}

func mapSuggestResults(results []suggest.SuggestionResult) []suggestResponse {
	out := make([]suggestResponse, 0, len(results))
	for _, r := range results {
		out = append(out, suggestResponse{
			TxnID:       r.TxnID,
			Status:      r.Status,
			Category:    r.Category,
			Subcategory: r.Subcategory,
			Confidence:  r.Confidence,
			ModelID:     r.ModelID,
			ReasonCode:  r.ReasonCode,
		})
	}
	return out
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
