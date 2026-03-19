# Edge Cases

## Pending → Posted Reconciliation

- If a posted transaction arrives that matches a pending one:
  - Same account
  - Same amount
  - Payee/description similarity
  - Date within +/- 7 days
- Update the pending row to posted rather than inserting a new record.
- Not yet implemented — planned for a future phase.

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

## Recurring Detection

- **Minimum occurrences:** Groups with fewer than 3 transactions in 12 months are not considered.
- **Minimum confidence:** Groups with confidence < 0.4 are filtered out to reduce false positives.
- **Transfer exclusion:** Transfers are excluded from recurring detection (they're not subscriptions).
- **Interval tolerance:** Each frequency has a range (e.g., monthly = 25-35 days) to handle slight date variations.
- **Amount variance:** `amount_changed_significantly?` flags >15% deviation from average — catches price increases.
- **Dismissed patterns:** Once a user dismisses a pattern, re-running detection does NOT re-surface it.
- **Grace period for missed:** Status changes to "missed" only when overdue by >1.5x the expected interval. This avoids false "missed" alerts for charges that are just a few days late.
- **Similar descriptions:** "NETFLIX.COM" and "NETFLIX COM" may appear as separate groups because normalization only strips card numbers and collapses whitespace. Future merchant normalization (Phase 6) will improve this.

## Budget Edge Cases

- Budgets are per-category per-month. A category with no budget has no progress bar.
- Budget amounts are stored as positive cents even though spending is negative cents.
- "Copy from previous month" skips categories that already have a budget for the target month.

## Transaction Search

- Uses PostgreSQL `ILIKE` for case-insensitive matching.
- Searches both `description` and `normalized_desc` fields.
- Search terms are sanitized via `sanitize_sql_like` to prevent SQL injection with `%` and `_` characters.
- Search works alongside all other filters (account, category, type, date range).
