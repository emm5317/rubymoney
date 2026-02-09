package models

type Account struct {
	AccountID    string `json:"account_id"`
	DisplayName  string `json:"display_name"`
	AccountType  string `json:"account_type"`
	Institution  string `json:"institution"`
	ConnectorType string `json:"connector_type"`
	ExternalID   string `json:"external_id,omitempty"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
	LastSyncAt   string `json:"last_sync_at,omitempty"`
	SyncStatus   string `json:"sync_status,omitempty"`
}
