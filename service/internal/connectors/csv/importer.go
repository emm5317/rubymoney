package csv

import (
	"bufio"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

type ImportOptions struct {
	MappingPath string
	MaxRows     int
}

type ParsedRow struct {
	Date   string
	Amount float64
	Payee  string
	Memo   string
}

type ImportResult struct {
	Rows       []ParsedRow
	Mapping    Mapping
	Skipped    int
	BadRows    int
	BadRowInfo []string
}

func ImportFile(path string, opts ImportOptions) (ImportResult, error) {
	file, err := os.Open(path)
	if err != nil {
		return ImportResult{}, err
	}
	defer file.Close()

	reader := csv.NewReader(bufio.NewReader(file))
	reader.FieldsPerRecord = -1
	reader.LazyQuotes = true

	mappingsFile, err := LoadMappings(opts.MappingPath)
	if err != nil {
		return ImportResult{}, fmt.Errorf("load mappings: %w", err)
	}

	var header []string
	var mapping Mapping
	matched := false
	rowIndex := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return ImportResult{}, fmt.Errorf("read csv: %w", err)
		}
		rowIndex++

		if header == nil {
			if len(mappingsFile.Mappings) > 0 {
				for _, candidate := range mappingsFile.Mappings {
					if candidate.HeaderRow > 0 && candidate.HeaderRow != rowIndex {
						continue
					}
					if mappingMatches(normalizeHeaderRow(record), candidate) {
						header = record
						mapping = candidate
						matched = true
						break
					}
				}
			}
			if matched {
				if mapping.HeaderRow == 0 {
					mapping.HeaderRow = rowIndex
				}
				break
			}
		}
	}

	if header == nil {
		return ImportResult{}, errors.New("CSV header not found")
	}

	colIndex := buildColumnIndex(header, mapping)
	if err := validateMappingColumns(mapping, colIndex); err != nil {
		return ImportResult{}, err
	}

	result := ImportResult{Mapping: mapping}

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return result, fmt.Errorf("read csv: %w", err)
		}
		rowIndex++

		if shouldSkipRow(rowIndex, mapping) {
			result.Skipped++
			continue
		}

		parsed, err := parseRow(record, colIndex, mapping)
		if err != nil {
			result.BadRows++
			result.BadRowInfo = append(result.BadRowInfo, fmt.Sprintf("row %d: %v", rowIndex, err))
			continue
		}

		result.Rows = append(result.Rows, parsed)
		if opts.MaxRows > 0 && len(result.Rows) >= opts.MaxRows {
			break
		}
	}

	return result, nil
}

func shouldSkipRow(rowIndex int, mapping Mapping) bool {
	for _, r := range mapping.SkipRows {
		if rowIndex == r {
			return true
		}
	}
	return false
}

func normalizeHeaderRow(header []string) map[string]struct{} {
	norm := map[string]struct{}{}
	for _, h := range header {
		norm[normalizeHeader(h)] = struct{}{}
	}
	return norm
}

func buildColumnIndex(header []string, mapping Mapping) map[string]int {
	index := map[string]int{}
	for logical, names := range mapping.Headers {
		for _, name := range names {
			for i, h := range header {
				if normalizeHeader(h) == normalizeHeader(name) {
					index[logical] = i
					break
				}
				if _, ok := index[logical]; ok {
					break
				}
			}
		}
	}

	if mapping.AmountColumns.Debit != "" {
		for i, h := range header {
			if normalizeHeader(h) == normalizeHeader(mapping.AmountColumns.Debit) {
				index["amount_debit"] = i
				break
			}
		}
	}
	if mapping.AmountColumns.Credit != "" {
		for i, h := range header {
			if normalizeHeader(h) == normalizeHeader(mapping.AmountColumns.Credit) {
				index["amount_credit"] = i
				break
			}
		}
	}
	if mapping.Amount.NegateIfColumn != "" {
		for i, h := range header {
			if normalizeHeader(h) == normalizeHeader(mapping.Amount.NegateIfColumn) {
				index["amount_negate_if"] = i
				break
			}
		}
	}

	return index
}

func validateMappingColumns(mapping Mapping, colIndex map[string]int) error {
	for _, field := range mapping.RequiredFields {
		if _, ok := colIndex[field]; !ok {
			return fmt.Errorf("missing required column for '%s'", field)
		}
	}
	return nil
}

func parseRow(record []string, colIndex map[string]int, mapping Mapping) (ParsedRow, error) {
	get := func(field string) string {
		idx, ok := colIndex[field]
		if !ok || idx >= len(record) {
			return ""
		}
		value := record[idx]
		if mapping.TrimQuotes {
			value = strings.Trim(value, "\"")
		}
		return strings.TrimSpace(value)
	}

	dateStr := get("date")
	payee := get("payee")
	memo := get("memo")

	for _, prefix := range mapping.StripPrefix {
		if strings.HasPrefix(payee, prefix) {
			payee = strings.TrimPrefix(payee, prefix)
		}
		if strings.HasPrefix(memo, prefix) {
			memo = strings.TrimPrefix(memo, prefix)
		}
	}

	if payee == "" {
		for _, field := range mapping.PayeeFallback {
			value := get(field)
			if value != "" {
				payee = value
				break
			}
		}
	}

	parsedDate, err := parseDate(dateStr, mapping.DateFormats, mapping.DateTimezone)
	if err != nil {
		return ParsedRow{}, err
	}

	amount, err := parseAmount(record, colIndex, mapping)
	if err != nil {
		return ParsedRow{}, err
	}

	return ParsedRow{
		Date:   parsedDate,
		Amount: amount,
		Payee:  payee,
		Memo:   memo,
	}, nil
}

func parseAmount(record []string, colIndex map[string]int, mapping Mapping) (float64, error) {
	getByIndex := func(key string) string {
		idx, ok := colIndex[key]
		if !ok || idx >= len(record) {
			return ""
		}
		value := record[idx]
		if mapping.TrimQuotes {
			value = strings.Trim(value, "\"")
		}
		return strings.TrimSpace(value)
	}

	if mapping.AmountColumns.Debit != "" || mapping.AmountColumns.Credit != "" {
		debitRaw := getByIndex("amount_debit")
		creditRaw := getByIndex("amount_credit")

		debit, err := parseOptionalAmount(debitRaw)
		if err != nil {
			return 0, fmt.Errorf("invalid debit amount: %s", debitRaw)
		}
		credit, err := parseOptionalAmount(creditRaw)
		if err != nil {
			return 0, fmt.Errorf("invalid credit amount: %s", creditRaw)
		}

		if debit > 0 && credit > 0 {
			return 0, errors.New("both debit and credit present")
		}
		if debit > 0 {
			return -debit, nil
		}
		if credit > 0 {
			return credit, nil
		}
		return 0, errors.New("amount is empty")
	}

	value := getByIndex("amount")
	if value == "" {
		return 0, errors.New("amount is empty")
	}

	amount, err := parseOptionalAmount(value)
	if err != nil {
		return 0, fmt.Errorf("invalid amount: %s", value)
	}

	if negateFlag := getByIndex("amount_negate_if"); negateFlag != "" {
		amount = -amount
	}

	switch mapping.Amount.Convention {
	case "expenses_positive":
		if amount > 0 {
			amount = -amount
		}
	case "expenses_negative":
		// already normalized
	default:
		// unknown convention: no-op
	}

	return amount, nil
}

func parseOptionalAmount(value string) (float64, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return 0, nil
	}
	cleaned := strings.ReplaceAll(value, ",", "")
	return strconv.ParseFloat(cleaned, 64)
}

func parseDate(value string, formats []string, tz string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", errors.New("date is empty")
	}

	var loc *time.Location
	if tz != "" {
		loaded, err := time.LoadLocation(tz)
		if err != nil {
			return "", fmt.Errorf("invalid timezone: %s", tz)
		}
		loc = loaded
	}

	for _, f := range formats {
		if f == "" {
			continue
		}
		if loc != nil {
			if t, err := time.ParseInLocation(f, value, loc); err == nil {
				return t.Format("2006-01-02"), nil
			}
		} else if t, err := time.Parse(f, value); err == nil {
			return t.Format("2006-01-02"), nil
		}
	}
	if t, err := time.Parse("2006-01-02", value); err == nil {
		return t.Format("2006-01-02"), nil
	}
	return "", fmt.Errorf("unparseable date: %s", value)
}
