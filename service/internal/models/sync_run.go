package models

type SyncRun struct {
	SyncRunID  string `json:"sync_run_id"`
	StartedAt  string `json:"started_at"`
	EndedAt    string `json:"ended_at,omitempty"`
	Since      string `json:"since"`
	Status     string `json:"status"`
	SummaryJSON string `json:"summary_json"`
}
