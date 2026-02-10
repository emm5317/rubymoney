package models

type Transaction struct {
	TxnID               string  `json:"txn_id"`
	ExternalTxnID       string  `json:"external_txn_id,omitempty"`
	AccountID           string  `json:"account_id"`
	PostedDate          string  `json:"posted_date"`
	Amount              float64 `json:"amount"`
	Payee               string  `json:"payee"`
	Memo                string  `json:"memo"`
	Category            string  `json:"category,omitempty"`
	Subcategory         string  `json:"subcategory,omitempty"`
	CategorySource      string  `json:"category_source"`
	SuggestedCategory   string  `json:"suggested_category,omitempty"`
	SuggestedSubcategory string `json:"suggested_subcategory,omitempty"`
	SuggestedConfidence float64 `json:"suggested_confidence,omitempty"`
	SuggestedModelID    string  `json:"suggested_model_id,omitempty"`
	SuggestedStatus     string  `json:"suggested_status,omitempty"`
	SuggestedReasonCode string  `json:"suggested_reason_code,omitempty"`
	Pending             bool    `json:"pending"`
	Fingerprint         string  `json:"fingerprint"`
	RawRef              string  `json:"raw_ref,omitempty"`
	ImportedAt          string  `json:"imported_at"`
}
