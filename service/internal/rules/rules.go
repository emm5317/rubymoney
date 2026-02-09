package rules

import (
	"regexp"
	"strings"

	"budgetexcel/service/internal/models"
)

type ApplyResult struct {
	MatchedRuleID string
	Category      string
	Subcategory   string
}

func ApplyRules(txn models.Transaction, rules []models.Rule) (ApplyResult, bool) {
	for _, rule := range rules {
		if !rule.Enabled {
			continue
		}
		if matches(rule, txn) {
			return ApplyResult{
				MatchedRuleID: rule.RuleID,
				Category:      rule.Category,
				Subcategory:   rule.Subcategory,
			}, true
		}
	}
	return ApplyResult{}, false
}

func matches(rule models.Rule, txn models.Transaction) bool {
	switch strings.ToLower(rule.MatchField) {
	case "payee":
		return matchValue(rule, txn.Payee)
	case "memo":
		return matchValue(rule, txn.Memo)
	case "account":
		return matchValue(rule, txn.AccountID)
	case "any":
		return matchValue(rule, txn.Payee) || matchValue(rule, txn.Memo) || matchValue(rule, txn.AccountID)
	default:
		return false
	}
}

func matchValue(rule models.Rule, value string) bool {
	target := strings.TrimSpace(value)
	pattern := strings.TrimSpace(rule.MatchValue)
	if target == "" || pattern == "" {
		return false
	}

	switch strings.ToLower(rule.MatchType) {
	case "equals":
		return strings.EqualFold(target, pattern)
	case "contains":
		return strings.Contains(strings.ToLower(target), strings.ToLower(pattern))
	case "regex":
		re, err := regexp.Compile("(?i)" + pattern)
		if err != nil {
			return false
		}
		return re.MatchString(target)
	default:
		return false
	}
}
