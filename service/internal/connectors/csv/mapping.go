package csv

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
)

type AmountConfig struct {
	Convention     string `json:"convention"`
	NegateIfColumn string `json:"negate_if_column,omitempty"`
}

type AmountColumns struct {
	Debit  string `json:"debit,omitempty"`
	Credit string `json:"credit,omitempty"`
}

type Mapping struct {
	Institution    string              `json:"institution"`
	InstitutionID  string              `json:"institution_id,omitempty"`
	AccountHint    string              `json:"account_hint,omitempty"`
	Currency       string              `json:"currency,omitempty"`
	HeaderRow      int                 `json:"header_row,omitempty"`
	SkipRows       []int               `json:"skip_rows,omitempty"`
	DateTimezone   string              `json:"date_timezone,omitempty"`
	PayeeFallback  []string            `json:"payee_fallback,omitempty"`
	StripPrefix    []string            `json:"strip_prefix,omitempty"`
	TrimQuotes     bool                `json:"trim_quotes,omitempty"`
	Headers        map[string][]string `json:"headers"`
	RequiredFields []string            `json:"required_fields"`
	DateFormats    []string            `json:"date_formats"`
	Amount         AmountConfig        `json:"amount"`
	AmountColumns  AmountColumns       `json:"amount_columns,omitempty"`
	Notes          string              `json:"notes,omitempty"`
}

type MappingFile struct {
	Mappings []Mapping `json:"mappings"`
}

func DefaultMappingPath() string {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		if home, err := os.UserHomeDir(); err == nil {
			localAppData = filepath.Join(home, "AppData", "Local")
		}
	}
	if localAppData == "" {
		return "csv_mappings.json"
	}
	return filepath.Join(localAppData, "BudgetApp", "config", "csv_mappings.json")
}

func LoadMappings(path string) (MappingFile, error) {
	if path == "" {
		path = DefaultMappingPath()
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return MappingFile{}, nil
		}
		return MappingFile{}, err
	}

	var file MappingFile
	if err := json.Unmarshal(data, &file); err == nil && len(file.Mappings) > 0 {
		return file, nil
	}

	var list []Mapping
	if err := json.Unmarshal(data, &list); err == nil {
		return MappingFile{Mappings: list}, nil
	}

	return MappingFile{}, errors.New("invalid csv_mappings.json")
}

func MatchMapping(headers []string, mappings []Mapping) (Mapping, bool) {
	if len(headers) == 0 || len(mappings) == 0 {
		return Mapping{}, false
	}

	normHeaders := map[string]struct{}{}
	for _, h := range headers {
		normHeaders[normalizeHeader(h)] = struct{}{}
	}

	for _, m := range mappings {
		if mappingMatches(normHeaders, m) {
			return m, true
		}
	}

	return Mapping{}, false
}

func mappingMatches(headers map[string]struct{}, m Mapping) bool {
	for _, field := range m.RequiredFields {
		candidates := m.Headers[field]
		if len(candidates) == 0 {
			return false
		}
		matched := false
		for _, c := range candidates {
			if _, ok := headers[normalizeHeader(c)]; ok {
				matched = true
				break
			}
		}
		if !matched {
			return false
		}
	}
	return true
}

func normalizeHeader(value string) string {
	value = strings.TrimSpace(value)
	value = strings.ToLower(value)
	value = strings.ReplaceAll(value, "_", " ")
	value = strings.ReplaceAll(value, "-", " ")
	value = strings.Join(strings.Fields(value), " ")
	return value
}
