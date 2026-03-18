# Edge Cases

## Pending → Posted Reconciliation

- If a posted transaction arrives that matches a pending one:
  - Same account
  - Same amount
  - Payee/description similarity
  - Date within +/- 7 days
- Update the pending row to posted rather than inserting a new record.
- Not yet implemented — planned for Phase 4 (transfer matching service).

## Deduplication Strategy

- **OFX/QFX imports:** Use the FITID (Financial Transaction ID) from the file as `source_fingerprint`. Handled by `Importers::OfxAdapter`.
- **CSV imports:** Compute `source_fingerprint = SHA256(account_id|date|amount_cents|normalized_description)`. Handled by `Importers::CsvAdapter`.
- Unique index on `[account_id, source_fingerprint]` prevents duplicates at the database level.
- During import preview, duplicates are flagged before confirmation so the user can review.

## Amount Sign Conventions

- Support both `expenses_negative` and `expenses_positive` conventions.
- `CsvAdapter` auto-detects: parentheses `(100.00)` treated as negative, currency symbols stripped.
- Separate debit/credit columns are merged into a single `amount_cents` (debits negative, credits positive).
- Amounts are normalized to cents before fingerprinting.

## Date Parsing

- `ImportProfile` stores the learned date format per account+institution.
- `CsvAdapter` tries common formats in order: `%m/%d/%Y`, `%Y-%m-%d`, `%d/%m/%Y`, etc.
- Rows with unparseable dates are rejected and reported in the preview step.

## Categorization Overrides

- When applying rules via `Categorizer`, transactions with a manually-set category are skipped by default.
- `Rule` records are applied in priority order (highest priority wins).
- `#apply_retroactive` only touches uncategorized transactions.

## CSV Quirks

- Quoted commas handled by Ruby's `CSV` stdlib.
- Leading/trailing whitespace in headers is stripped during column mapping.
- Description and memo fields are normalized (whitespace collapsed, stripped) before fingerprinting.
- Empty rows and header-only files are gracefully skipped.
