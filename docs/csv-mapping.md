# CSV Mapping

## Purpose

Support CSV imports from multiple institutions with variable headers, date formats, and amount conventions.

## Config File

Path: `%LOCALAPPDATA%\BudgetApp\config\csv_mappings.json`

## Schema

Each mapping entry includes:

- `institution`
- `headers`
- `required_fields`
- `date_formats`
- `amount`
- `notes`

### Field Rules

- Required logical fields: `date`, `amount`, `payee`, `memo`.
- `headers` maps logical fields to possible CSV column names.
- `date_formats` is an ordered list for parsing.
- `amount` defines sign convention and any column-level transforms.

## Auto-Detect

- Try to match known header patterns.
- Fallback: prompt or use default mapping if only one plausible match exists.

## Example 1 (Bank A)

```json
{
  "institution": "Bank A",
  "headers": {
    "date": ["Posting Date", "Date"],
    "amount": ["Amount"],
    "payee": ["Description", "Payee"],
    "memo": ["Memo", "Details"]
  },
  "required_fields": ["date", "amount", "payee", "memo"],
  "date_formats": ["2006-01-02", "01/02/2006"],
  "amount": {
    "convention": "expenses_negative",
    "negate_if_column": null
  },
  "notes": "Standard checking export"
}
```

## Example 2 (Credit Card B)

```json
{
  "institution": "Credit Card B",
  "headers": {
    "date": ["Transaction Date", "Date"],
    "amount": ["Charge Amount", "Amount"],
    "payee": ["Merchant", "Description"],
    "memo": ["Category", "Memo"]
  },
  "required_fields": ["date", "amount", "payee", "memo"],
  "date_formats": ["01/02/2006"],
  "amount": {
    "convention": "expenses_positive",
    "negate_if_column": "Credit"
  },
  "notes": "Card exports charges as positive"
}
```

## Amount Normalization

- `expenses_negative`: expenses become negative, income positive.
- `expenses_positive`: expenses positive; normalize internally to negative.

## Validation

- Reject rows with missing required fields.
- Warn on unparseable dates.
- Cap row count and payload size to prevent oversized imports.
