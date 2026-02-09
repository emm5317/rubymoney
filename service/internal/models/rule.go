package models

type Rule struct {
	RuleID     string `json:"rule_id"`
	Priority   int    `json:"priority"`
	Enabled    bool   `json:"enabled"`
	MatchField string `json:"match_field"`
	MatchType  string `json:"match_type"`
	MatchValue string `json:"match_value"`
	Category   string `json:"category"`
	Subcategory string `json:"subcategory"`
	Notes      string `json:"notes,omitempty"`
}
