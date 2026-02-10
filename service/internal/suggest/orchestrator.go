package suggest

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"budgetexcel/service/internal/db"
	"budgetexcel/service/internal/models"
	syncer "budgetexcel/service/internal/sync"
)

const (
	StatusSuggested = "suggested"
	StatusAbstained = "abstained"
	StatusInvalid   = "invalid"
	StatusError     = "error"
	StatusNone      = "none"
)

type Orchestrator struct {
	db      *sql.DB
	adapter Adapter
	cfg     Config
	now     func() time.Time
}

func NewOrchestrator(database *sql.DB, cfg Config) (*Orchestrator, error) {
	var adapter Adapter
	if cfg.Enabled {
		if strings.ToLower(cfg.Runtime) != "llama_cpp" {
			return nil, fmt.Errorf("unsupported LLM runtime: %s", cfg.Runtime)
		}
		adapter = NewLlamaAdapter(cfg)
	}

	return &Orchestrator{
		db:      database,
		adapter: adapter,
		cfg:     cfg,
		now:     time.Now,
	}, nil
}

func (o *Orchestrator) Config() Config {
	return o.cfg
}

func (o *Orchestrator) Enqueue(txnIDs []string, categories []CategoryAllowList) (int, error) {
	if len(txnIDs) == 0 {
		return 0, nil
	}
	categoriesJSON, err := json.Marshal(categories)
	if err != nil {
		return 0, err
	}
	return db.EnqueueSuggestionJobs(o.db, txnIDs, string(categoriesJSON), PromptVersion)
}

func (o *Orchestrator) SuggestSync(ctx context.Context, txnIDs []string, categories []CategoryAllowList) ([]SuggestionResult, error) {
	results := make([]SuggestionResult, 0, len(txnIDs))
	allowList := BuildAllowList(categories)
	for _, txnID := range txnIDs {
		ctxData, ok, err := db.GetSuggestionContext(o.db, txnID)
		if err != nil {
			return nil, err
		}
		if !ok {
			continue
		}
		result, err := o.SuggestForTransaction(ctx, ctxData, allowList)
		if err != nil {
			return nil, err
		}
		results = append(results, result)
	}
	return results, nil
}

func (o *Orchestrator) StartPoller(ctx context.Context) {
	if o.cfg.MaxConcurrency <= 0 {
		return
	}
	ticker := time.NewTicker(o.cfg.PollInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := o.processNextJob(ctx); err != nil {
				log.Printf("suggestion job error: %v", err)
			}
		}
	}
}

func (o *Orchestrator) processNextJob(ctx context.Context) error {
	job, ok, err := db.ClaimNextSuggestionJob(o.db)
	if err != nil {
		return err
	}
	if !ok {
		return nil
	}

	attempts := job.Attempts + 1
	var categories []CategoryAllowList
	if err := json.Unmarshal([]byte(job.CategoriesJSON), &categories); err != nil {
		_ = db.UpdateSuggestionJob(o.db, job.JobID, "failed", attempts, "invalid categories_json")
		return err
	}

	ctxData, found, err := db.GetSuggestionContext(o.db, job.TxnID)
	if err != nil {
		_ = db.UpdateSuggestionJob(o.db, job.JobID, "failed", attempts, err.Error())
		return err
	}
	if !found {
		_ = db.UpdateSuggestionJob(o.db, job.JobID, "done", attempts, "")
		return nil
	}

	allowList := BuildAllowList(categories)
	_, err := o.SuggestForTransaction(ctx, ctxData, allowList)
	if err != nil {
		if attempts <= o.cfg.RetryMax {
			_ = db.UpdateSuggestionJob(o.db, job.JobID, "queued", attempts, err.Error())
		} else {
			_ = db.UpdateSuggestionJob(o.db, job.JobID, "failed", attempts, err.Error())
			_ = db.UpdateTransactionSuggestion(o.db, job.TxnID, "", "", StatusError, "", "", 0)
		}
		return err
	}

	if err := db.UpdateSuggestionJob(o.db, job.JobID, "done", attempts, ""); err != nil {
		return err
	}
	return nil
}

func (o *Orchestrator) SuggestForTransaction(ctx context.Context, ctxData db.SuggestionContext, allowList AllowList) (SuggestionResult, error) {
	txn := ctxData.Transaction
	if strings.TrimSpace(txn.Category) != "" || strings.TrimSpace(txn.Subcategory) != "" {
		return SuggestionResult{
			TxnID:   txn.TxnID,
			Status: StatusNone,
		}, nil
	}

	cacheKey := buildCacheKey(txn, ctxData.AccountType)
	if cacheKey != "" {
		if cached, ok, err := db.GetSuggestionCacheEntry(o.db, cacheKey); err == nil && ok {
			if o.cacheValid(cached) {
				if cached.Status == StatusSuggested && allowList.IsValid(cached.Category, cached.Subcategory) {
					result := SuggestionResult{
						TxnID:        txn.TxnID,
						CacheKey:     cacheKey,
						Status:       cached.Status,
						Category:     cached.Category,
						Subcategory:  cached.Subcategory,
						Confidence:   cached.Confidence,
						ModelID:      cached.ModelID,
						ReasonCode:   "",
						LatencyMs:    0,
						PromptVersion: cached.PromptVersion,
					}
					return o.persistResult(txn.TxnID, result)
				}
				if cached.Status == StatusAbstained {
					result := SuggestionResult{
						TxnID:        txn.TxnID,
						CacheKey:     cacheKey,
						Status:       cached.Status,
						Category:     "",
						Subcategory:  "",
						Confidence:   0,
						ModelID:      cached.ModelID,
						ReasonCode:   "",
						LatencyMs:    0,
						PromptVersion: cached.PromptVersion,
					}
					return o.persistResult(txn.TxnID, result)
				}
			}
		}
	}

	if suggestion, ok, err := o.rulesSuggestion(txn, allowList); err != nil {
		return SuggestionResult{}, err
	} else if ok {
		result := suggestion
		result.TxnID = txn.TxnID
		result.CacheKey = cacheKey
		return o.persistResult(txn.TxnID, result)
	}

	if !o.cfg.Enabled || o.adapter == nil {
		result := SuggestionResult{
			TxnID:        txn.TxnID,
			CacheKey:     cacheKey,
			Status:       StatusAbstained,
			Confidence:   0,
			ModelID:      "",
			ReasonCode:   "llm_disabled",
			PromptVersion: PromptVersion,
		}
		return o.persistResult(txn.TxnID, result)
	}

	prompt, err := BuildPrompt(PromptInput{
		TxnID:       txn.TxnID,
		Categories:  allowListToSlice(allowList),
		Payee:       txn.Payee,
		Memo:        txn.Memo,
		Amount:      txn.Amount,
		PostedDate:  txn.PostedDate,
		AccountType: ctxData.AccountType,
	})
	if err != nil {
		return SuggestionResult{}, err
	}

	raw, latency, err := o.adapter.SuggestCategory(ctx, prompt)
	if err != nil {
		return SuggestionResult{}, err
	}

	parsed, err := ParseModelResponse(txn.TxnID, raw)
	if err != nil {
		result := SuggestionResult{
			TxnID:        txn.TxnID,
			CacheKey:     cacheKey,
			Status:       StatusInvalid,
			Confidence:   0,
			ModelID:      o.adapter.ModelID(),
			ReasonCode:   "invalid_json",
			LatencyMs:    int(latency.Milliseconds()),
			PromptVersion: PromptVersion,
		}
		return o.persistResult(txn.TxnID, result)
	}

	if !parsed.Suggested {
		result := SuggestionResult{
			TxnID:        txn.TxnID,
			CacheKey:     cacheKey,
			Status:       StatusAbstained,
			Confidence:   0,
			ModelID:      o.adapter.ModelID(),
			ReasonCode:   "insufficient_signal",
			LatencyMs:    int(latency.Milliseconds()),
			PromptVersion: PromptVersion,
		}
		return o.persistResult(txn.TxnID, result)
	}

	if !allowList.IsValid(parsed.Category, parsed.Subcategory) {
		result := SuggestionResult{
			TxnID:        txn.TxnID,
			CacheKey:     cacheKey,
			Status:       StatusInvalid,
			Confidence:   0,
			ModelID:      o.adapter.ModelID(),
			ReasonCode:   "allow_list_reject",
			LatencyMs:    int(latency.Milliseconds()),
			PromptVersion: PromptVersion,
		}
		return o.persistResult(txn.TxnID, result)
	}
	canonicalCategory, canonicalSub, _ := allowList.Canonical(parsed.Category, parsed.Subcategory)

	confidence, reasonCode, err := o.computeConfidence(txn, canonicalCategory, canonicalSub)
	if err != nil {
		return SuggestionResult{}, err
	}

	result := SuggestionResult{
		TxnID:        txn.TxnID,
		CacheKey:     cacheKey,
		Status:       StatusSuggested,
		Category:     canonicalCategory,
		Subcategory:  canonicalSub,
		Confidence:   confidence,
		ModelID:      o.adapter.ModelID(),
		ReasonCode:   reasonCode,
		LatencyMs:    int(latency.Milliseconds()),
		PromptVersion: PromptVersion,
	}
	return o.persistResult(txn.TxnID, result)
}

func (o *Orchestrator) persistResult(txnID string, result SuggestionResult) (SuggestionResult, error) {
	if result.PromptVersion == "" {
		result.PromptVersion = PromptVersion
	}
	audit := models.SuggestionAudit{
		TxnID:        txnID,
		ModelID:      result.ModelID,
		Status:       result.Status,
		TopCategory:  result.Category,
		Subcategory:  result.Subcategory,
		Confidence:   result.Confidence,
		LatencyMs:    result.LatencyMs,
		PromptVersion: result.PromptVersion,
		CreatedAt:    o.now().UTC().Format(time.RFC3339),
	}
	_ = db.InsertSuggestionAudit(o.db, audit)

	if err := db.UpdateTransactionSuggestion(o.db, txnID, result.Category, result.Subcategory, result.Status, result.ModelID, result.ReasonCode, result.Confidence); err != nil {
		return SuggestionResult{}, err
	}

	if err := o.maybeCache(result); err != nil {
		return SuggestionResult{}, err
	}

	return result, nil
}

func (o *Orchestrator) maybeCache(result SuggestionResult) error {
	if result.Status != StatusSuggested && result.Status != StatusAbstained {
		return nil
	}
	if result.CacheKey == "" {
		return nil
	}
	entry := models.SuggestionCacheEntry{
		CacheKey:      result.CacheKey,
		Status:        result.Status,
		Category:      result.Category,
		Subcategory:   result.Subcategory,
		Confidence:    result.Confidence,
		ModelID:       result.ModelID,
		SuggestedAt:   o.now().UTC().Format(time.RFC3339),
		PromptVersion: result.PromptVersion,
	}
	return db.UpsertSuggestionCacheEntry(o.db, entry)
}

func (o *Orchestrator) cacheValid(entry models.SuggestionCacheEntry) bool {
	if entry.PromptVersion != PromptVersion {
		return false
	}
	if entry.SuggestedAt == "" {
		return false
	}
	t, err := time.Parse(time.RFC3339, entry.SuggestedAt)
	if err != nil {
		return false
	}
	return o.now().Sub(t) <= o.cfg.CacheTTL
}

func (o *Orchestrator) rulesSuggestion(txn models.Transaction, allowList AllowList) (SuggestionResult, bool, error) {
	payeeKey := strings.ToLower(strings.TrimSpace(txn.Payee))
	if payeeKey != "" {
		category, subcategory, ok, err := db.FindLatestCategoryForPayee(o.db, txn.AccountID, payeeKey)
		if err != nil {
			return SuggestionResult{}, false, err
		}
		if ok && allowList.IsValid(category, subcategory) {
			cat, sub, _ := allowList.Canonical(category, subcategory)
			confidence, reasonCode, err := o.computeConfidence(txn, category, subcategory)
			if err != nil {
				return SuggestionResult{}, false, err
			}
			return SuggestionResult{
				Status:       StatusSuggested,
				Category:     cat,
				Subcategory:  sub,
				Confidence:   confidence,
				ModelID:      "rules:payee_exact",
				ReasonCode:   reasonCode,
				PromptVersion: PromptVersion,
			}, true, nil
		}
	}

	if cat, sub, ok := keywordSuggestion(txn.Payee, txn.Memo, allowList); ok {
		confidence, reasonCode, err := o.computeConfidence(txn, cat, sub)
		if err != nil {
			return SuggestionResult{}, false, err
		}
		return SuggestionResult{
			Status:       StatusSuggested,
			Category:     cat,
			Subcategory:  sub,
			Confidence:   confidence,
			ModelID:      "rules:keyword",
			ReasonCode:   reasonCode,
			PromptVersion: PromptVersion,
		}, true, nil
	}

	return SuggestionResult{}, false, nil
}

func (o *Orchestrator) computeConfidence(txn models.Transaction, category, subcategory string) (float64, string, error) {
	if category == "" {
		return 0, "", nil
	}
	confidence := 0.50
	reasonCode := "model_only"

	payeeKey := strings.ToLower(strings.TrimSpace(txn.Payee))
	if payeeKey != "" {
		if cat, sub, ok, err := db.FindLatestCategoryForPayee(o.db, txn.AccountID, payeeKey); err != nil {
			return 0, "", err
		} else if ok && strings.EqualFold(cat, category) && strings.EqualFold(sub, subcategory) {
			confidence += 0.20
			reasonCode = "payee_exact"
		}

		if count, err := db.CountRecentCategoryForPayee(o.db, txn.AccountID, payeeKey, category, subcategory, 10); err != nil {
			return 0, "", err
		} else if count > 0 {
			confidence += 0.10
			if reasonCode == "model_only" {
				reasonCode = "recent_payee"
			}
		}
	}

	if keywordMatch(txn.Payee, txn.Memo, category, subcategory) {
		confidence += 0.10
		if reasonCode == "model_only" {
			reasonCode = "keyword_match"
		}
	}

	if confidence > 1 {
		confidence = 1
	}
	if confidence < 0 {
		confidence = 0
	}
	return confidence, reasonCode, nil
}

func buildCacheKey(txn models.Transaction, accountType string) string {
	payee := syncer.NormalizeString(txn.Payee)
	memo := syncer.NormalizeString(txn.Memo)
	if payee == "" && memo == "" {
		return ""
	}
	return strings.Join([]string{payee, memo, strings.TrimSpace(accountType), PromptVersion}, "|")
}

func allowListToSlice(list AllowList) []CategoryAllowList {
	out := make([]CategoryAllowList, 0, len(list.categories))
	for _, entry := range list.categories {
		subList := make([]string, 0, len(entry.subcategories))
		for _, sub := range entry.subcategories {
			subList = append(subList, sub)
		}
		out = append(out, CategoryAllowList{Name: entry.name, Subcategories: subList})
	}
	return out
}

func keywordSuggestion(payee, memo string, allowList AllowList) (string, string, bool) {
	text := strings.ToLower(payee + " " + memo)
	bestCat := ""
	bestSub := ""
	bestLen := 0

	for _, entry := range allowList.categories {
		for _, sub := range entry.subcategories {
			subLower := strings.ToLower(sub)
			if subLower == "" {
				continue
			}
			if strings.Contains(text, subLower) {
				if len(subLower) > bestLen {
					bestLen = len(subLower)
					bestCat = entry.name
					bestSub = sub
				}
			}
		}
	}

	if bestCat != "" {
		return bestCat, bestSub, true
	}
	return "", "", false
}

func keywordMatch(payee, memo, category, subcategory string) bool {
	text := strings.ToLower(payee + " " + memo)
	if subcategory != "" && strings.Contains(text, strings.ToLower(subcategory)) {
		return true
	}
	if category != "" && strings.Contains(text, strings.ToLower(category)) {
		return true
	}
	return false
}
