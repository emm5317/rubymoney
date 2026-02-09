# CSV Mapping

## Purpose

Support CSV imports from multiple institutions with variable headers, date formats, and amount conventions.

## Config File

Path: `%LOCALAPPDATA%\BudgetApp\config\csv_mappings.json`

The loader accepts either:

- A top-level object `{ "mappings": [ ... ] }` or
- A top-level array `[ ... ]`

If the file does not exist, the loader returns an empty list and the connector relies on auto-detect.

## Schema

Each mapping entry includes:

Required:

- `institution`
- `headers`
- `required_fields`
- `date_formats`
- `amount`

Optional:

- `institution_id`
- `account_hint`
- `currency`
- `header_row`
- `skip_rows`
- `amount_columns`
- `date_timezone`
- `payee_fallback`
- `strip_prefix`
- `trim_quotes`
- `notes`

### Field Rules

- Required logical fields: `date`, `amount`, `payee`, `memo`.
- `headers` maps logical fields to possible CSV column names.
- `date_formats` is an ordered list for parsing.
- `amount` defines sign convention and any column-level transforms.

### Optional Field Behavior

- `institution_id`: stable ID for the mapping (useful if name changes).
- `account_hint`: string to help map CSVs to a specific account.
- `currency`: default currency code (e.g., `USD`).
- `header_row`: 1-based row index containing headers (default 1).
- `skip_rows`: list of 1-based row indexes to skip.
- `amount_columns`: split columns for debit/credit (overrides `amount` sign convention if present).
- `date_timezone`: IANA timezone for interpreting dates.
- `payee_fallback`: list of fields to try if payee is empty.
- `strip_prefix`: list of prefixes to remove from payee/memo.
- `trim_quotes`: whether to trim surrounding quotes on values.

## Auto-Detect

- Normalize header names (case/whitespace/underscore/dash).
- A mapping matches if all `required_fields` are present in the CSV header row.
- First matching mapping is selected; if none match, import fails with a clear error.

## Example 1 (Bank A)

```json
{
  "institution": "Bank A",
  "institution_id": "bank_a_checking",
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
  "currency": "USD",
  "header_row": 1,
  "notes": "Standard checking export"
}
```

## Example 2 (Credit Card B)

```json
{
  "institution": "Credit Card B",
  "institution_id": "card_b_primary",
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
  "currency": "USD",
  "header_row": 1,
  "payee_fallback": ["memo"],
  "strip_prefix": ["POS ", "PURCHASE "],
  "notes": "Card exports charges as positive"
}
```

## Amount Normalization

- `expenses_negative`: expenses become negative, income positive.
- `expenses_positive`: expenses positive; normalize internally to negative.
- `amount_columns`: if present, debit/credit columns override `amount` convention.

## Validation

- Reject rows with missing required fields.
- Warn on unparseable dates.
- Cap row count and payload size to prevent oversized imports.
