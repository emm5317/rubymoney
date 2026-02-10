package csv

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"sort"
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
	FileNameHints  []string            `json:"file_name_hints,omitempty"`
	FileNameRegex  string              `json:"file_name_regex,omitempty"`
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
	if dir := DefaultMappingsDir(); dir != "" {
		return dir
	}
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

func DefaultMappingsDir() string {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		if home, err := os.UserHomeDir(); err == nil {
			localAppData = filepath.Join(home, "AppData", "Local")
		}
	}
	if localAppData == "" {
		return ""
	}
	return filepath.Join(localAppData, "BudgetApp", "config", "csv_mappings")
}

func LoadMappings(path string) (MappingFile, error) {
	if path == "" {
		path = DefaultMappingPath()
	}
	info, err := os.Stat(path)
	if err == nil && info.IsDir() {
		return loadMappingsDir(path)
	}
	if errors.Is(err, os.ErrNotExist) {
		return MappingFile{}, nil
	}
	if err != nil {
		return MappingFile{}, err
	}
	return loadMappingsFile(path)
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

func mappingMatchesWithFile(headers map[string]struct{}, m Mapping, fileName string) bool {
	if !mappingMatches(headers, m) {
		return false
	}
	if len(m.FileNameHints) == 0 && m.FileNameRegex == "" {
		return true
	}
	if fileName == "" {
		return false
	}
	name := strings.ToLower(fileName)
	for _, hint := range m.FileNameHints {
		if hint == "" {
			continue
		}
		if strings.Contains(name, strings.ToLower(hint)) {
			return true
		}
	}
	if m.FileNameRegex != "" {
		if re, err := regexp.Compile(m.FileNameRegex); err == nil {
			return re.MatchString(fileName)
		}
	}
	return false
}

func normalizeHeader(value string) string {
	value = strings.TrimSpace(value)
	value = strings.ToLower(value)
	value = strings.ReplaceAll(value, "_", " ")
	value = strings.ReplaceAll(value, "-", " ")
	value = strings.Join(strings.Fields(value), " ")
	return value
}

func loadMappingsDir(dir string) (MappingFile, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return MappingFile{}, nil
		}
		return MappingFile{}, err
	}

	var names []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.ToLower(filepath.Ext(entry.Name())) != ".json" {
			continue
		}
		names = append(names, entry.Name())
	}
	sort.Strings(names)

	var out MappingFile
	for _, name := range names {
		path := filepath.Join(dir, name)
		file, err := loadMappingsFile(path)
		if err != nil {
			return MappingFile{}, err
		}
		out.Mappings = append(out.Mappings, file.Mappings...)
	}
	return out, nil
}

func loadMappingsFile(path string) (MappingFile, error) {
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
