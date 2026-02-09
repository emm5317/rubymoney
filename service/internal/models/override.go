package models

type Override struct {
	TxnID       string `json:"txn_id"`
	Category    string `json:"category"`
	Subcategory string `json:"subcategory"`
	UpdatedAt   string `json:"updated_at"`
}
