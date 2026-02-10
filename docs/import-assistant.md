# Reminders and Import Assistant

## Setup

Run the macro `SetupRemindersAssistant` once. It creates two sheets:

- `Reminders` with table `reminders`
- `Import Assistant` with table `import_assistant`

## Reminders table

Table name: `reminders`

Columns:

- `account_id` (formula from `accounts` table)
- `display_name` (lookup from `accounts`)
- `institution` (lookup from `accounts`)
- `cadence` (data validation: weekly, monthly, quarterly)
- `last_import_date` (date of last import)
- `next_due_date` (formula)
- `days_overdue` (formula)
- `status` (formula: ok/due)

Use the "Check Reminders" button to show all accounts due for import.

Notes:

- Reminder and assistant rows are filled by VBA (values), not formulas. This avoids structured-reference formula errors on some Excel builds.

## Import Assistant table

Table name: `import_assistant`

Columns:

- `account_id` (formula from `accounts` table)
- `display_name` (lookup from `accounts`)
- `institution` (lookup from `accounts`)
- `expected_csv` (formula for a suggested filename)
- `last_imported_at` (timestamp)
- `last_file` (last imported filename)
- `file_path` (full path to a CSV)
- `import_status` (formula)

Buttons:

- `Pick CSV` updates `file_path` for the selected row.
- `Import Selected` runs a sync for that account and refreshes Excel.

## Sync behavior

- `SyncAll` uses `import_assistant[file_path]` if present; otherwise it falls back to the newest CSV in the default import folder.
- After an import, the assistant updates `last_imported_at`, `last_file`, and the reminders `last_import_date`.

## Notes

- Keep CSV files local; no secrets are stored in Excel.
- If a formula shows blanks, ensure the `accounts` table has `account_id`, `display_name`, and `institution` columns.
- Bank of America statement CSVs include summary rows before the transaction header; the mapping uses `header_row: 7` and will ignore those rows.
- Bank of America statement dates are `M/D/YYYY` and the first data row is a beginning balance with no amount; the mapping skips that row.

## LLM Suggestions (Local)

Macros (run once to add UI buttons on the Transactions sheet):

- `AddSuggestionButtons` adds buttons for suggesting, refreshing, applying, and rejecting.

Workflow:

- `Suggest Categories (Blanks)` queues local suggestions for uncategorized rows.
- `Refresh Suggestions` pulls suggested fields into the Transactions table.
- `Apply Suggestions` applies suggestions to selected rows (never overwrites non-empty categories).
- `Reject Suggestion` marks selected rows as rejected.

Suggestions are always local-only and never auto-applied.
