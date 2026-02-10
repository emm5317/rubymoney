package models

type SuggestionAudit struct {
	ID           int64
	TxnID        string
	ModelID      string
	Status       string
	TopCategory  string
	Subcategory  string
	Confidence   float64
	LatencyMs    int
	PromptVersion string
	CreatedAt    string
}

type SuggestionJob struct {
	JobID         int64
	TxnID         string
	Status        string
	Attempts      int
	LastError     string
	CategoriesJSON string
	PromptVersion string
	CreatedAt     string
}

type SuggestionCacheEntry struct {
	CacheKey      string
	Status        string
	Category      string
	Subcategory   string
	Confidence    float64
	ModelID       string
	SuggestedAt   string
	PromptVersion string
}
