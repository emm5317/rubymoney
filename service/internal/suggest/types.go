package suggest

type CategoryAllowList struct {
	Name         string   `json:"name"`
	Subcategories []string `json:"subcategories"`
}

type PromptInput struct {
	TxnID       string              `json:"txn_id"`
	Categories  []CategoryAllowList `json:"categories"`
	Payee       string              `json:"payee"`
	Memo        string              `json:"memo"`
	Amount      float64             `json:"amount"`
	PostedDate  string              `json:"posted_date"`
	AccountType string              `json:"account_type"`
}

type ModelResponse struct {
	TxnID       string `json:"txn_id"`
	Suggested   bool   `json:"suggested"`
	Category    string `json:"category"`
	Subcategory string `json:"subcategory"`
	ReasonCode  string `json:"reason_code"`
	Reason      string `json:"reason"`
}

type SuggestionResult struct {
	TxnID        string
	CacheKey     string
	Status       string
	Category     string
	Subcategory  string
	Confidence   float64
	ModelID      string
	ReasonCode   string
	LatencyMs    int
	PromptVersion string
}
