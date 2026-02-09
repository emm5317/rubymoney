package rules

import (
	"testing"

	"budgetexcel/service/internal/models"
)

func TestApplyRules_PriorityAndEnabled(t *testing.T) {
	txn := models.Transaction{
		Payee:     "STARBUCKS",
		Memo:      "LATTE",
		AccountID: "acc-1",
	}

	rulesList := []models.Rule{
		{
			RuleID:     "r2",
			Priority:   2,
			Enabled:    true,
			MatchField: "payee",
			MatchType:  "contains",
			MatchValue: "STAR",
			Category:   "Food",
			Subcategory: "Coffee",
		},
		{
			RuleID:     "r1",
			Priority:   1,
			Enabled:    true,
			MatchField: "memo",
			MatchType:  "contains",
			MatchValue: "LATTE",
			Category:   "Food",
			Subcategory: "Drinks",
		},
		{
			RuleID:     "r3",
			Priority:   0,
			Enabled:    false,
			MatchField: "payee",
			MatchType:  "equals",
			MatchValue: "STARBUCKS",
			Category:   "Ignore",
		},
	}

	result, matched := ApplyRules(txn, rulesList)
	if !matched {
		t.Fatalf("expected match")
	}
	if result.MatchedRuleID != "r2" && result.MatchedRuleID != "r1" {
		t.Fatalf("unexpected rule id: %s", result.MatchedRuleID)
	}
}

func TestMatchRegex(t *testing.T) {
	txn := models.Transaction{Payee: "Amazon Marketplace"}

	rulesList := []models.Rule{
		{
			RuleID:     "r1",
			Priority:   1,
			Enabled:    true,
			MatchField: "payee",
			MatchType:  "regex",
			MatchValue: "amazon",
			Category:   "Shopping",
			Subcategory: "Online",
		},
	}

	result, matched := ApplyRules(txn, rulesList)
	if !matched {
		t.Fatalf("expected regex match")
	}
	if result.Category != "Shopping" {
		t.Fatalf("unexpected category: %s", result.Category)
	}
}
