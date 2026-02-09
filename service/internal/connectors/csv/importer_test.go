package csv

import (
	"os"
	"path/filepath"
	"testing"
)

func TestImportFile_WithMapping(t *testing.T) {
	tempDir := t.TempDir()
	csvPath := filepath.Join(tempDir, "sample.csv")
	mappingPath := filepath.Join(tempDir, "csv_mappings.json")

	csvContent := "Posting Date,Amount,Description,Memo\n" +
		"2026-02-01,12.34,COFFEE SHOP,Latte\n" +
		"2026-02-02,-5.00,GROCERY,Food\n"

	if err := os.WriteFile(csvPath, []byte(csvContent), 0o600); err != nil {
		t.Fatalf("write csv: %v", err)
	}

	mapping := `[
  {
    "institution": "Bank A",
    "headers": {
      "date": ["Posting Date"],
      "amount": ["Amount"],
      "payee": ["Description"],
      "memo": ["Memo"]
    },
    "required_fields": ["date", "amount", "payee", "memo"],
    "date_formats": ["2006-01-02"],
    "amount": { "convention": "expenses_negative" }
  }
]`

	if err := os.WriteFile(mappingPath, []byte(mapping), 0o600); err != nil {
		t.Fatalf("write mapping: %v", err)
	}

	result, err := ImportFile(csvPath, ImportOptions{MappingPath: mappingPath})
	if err != nil {
		t.Fatalf("import: %v", err)
	}
	if len(result.Rows) != 2 {
		t.Fatalf("expected 2 rows, got %d", len(result.Rows))
	}
	if result.Rows[0].Date != "2026-02-01" {
		t.Fatalf("unexpected date: %s", result.Rows[0].Date)
	}
	if result.Rows[0].Amount != 12.34 {
		t.Fatalf("unexpected amount: %f", result.Rows[0].Amount)
	}
}

func TestImportFile_ExpensesPositive(t *testing.T) {
	tempDir := t.TempDir()
	csvPath := filepath.Join(tempDir, "sample.csv")
	mappingPath := filepath.Join(tempDir, "csv_mappings.json")

	csvContent := "Date,Amount,Payee,Memo\n" +
		"2026-02-01,12.34,COFFEE SHOP,Latte\n"

	if err := os.WriteFile(csvPath, []byte(csvContent), 0o600); err != nil {
		t.Fatalf("write csv: %v", err)
	}

	mapping := `[
  {
    "institution": "Card",
    "headers": {
      "date": ["Date"],
      "amount": ["Amount"],
      "payee": ["Payee"],
      "memo": ["Memo"]
    },
    "required_fields": ["date", "amount", "payee", "memo"],
    "date_formats": ["2006-01-02"],
    "amount": { "convention": "expenses_positive" }
  }
]`

	if err := os.WriteFile(mappingPath, []byte(mapping), 0o600); err != nil {
		t.Fatalf("write mapping: %v", err)
	}

	result, err := ImportFile(csvPath, ImportOptions{MappingPath: mappingPath})
	if err != nil {
		t.Fatalf("import: %v", err)
	}
	if len(result.Rows) != 1 {
		t.Fatalf("expected 1 row, got %d", len(result.Rows))
	}
	if result.Rows[0].Amount != -12.34 {
		t.Fatalf("expected normalized negative amount, got %f", result.Rows[0].Amount)
	}
}
