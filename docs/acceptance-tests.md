# Acceptance Tests

## Manual Tests

1. Import same CSV twice -> zero duplicates.
2. Edit categories for 10 transactions -> Commit Overrides -> categories persist after Re-categorize.
3. Disable a rule -> Re-categorize -> affected transactions revert to uncategorized unless overridden.
4. Service binds to localhost only -> `netstat -ano` shows `127.0.0.1:8787` only.
5. Diagnostics endpoint shows last sync counts with no secrets.
6. Pending->posted reconciliation updates pending instead of inserting new.

## Automated Tests

- CSV parser unit tests for header mapping, date parsing, and amount normalization.
- Idempotency tests for external ID dedupe and fingerprint dedupe.
- Rules engine tests for priority order and override protection.
- Override API tests for upsert and persistence across re-apply.
- Diagnostics redaction tests.

## Required Data Fixtures

- Sample CSVs for at least two institutions.
- A CSV that includes pending rows and later posted rows.
- A CSV with duplicate rows to validate idempotency.
