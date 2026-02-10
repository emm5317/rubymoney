# VBA Outline

## Modules

- `modService` ensure service running, health check
- `modSync` sync flow and transactions refresh
- `modRules` import rules and apply rules
- `modOverrides` detect manual changes and push overrides
- `modDiagnostics` show last sync summary and errors
- `modAssistant` reminders and import assistant helpers

## Shared Helpers

- `HttpPostJson(url, body)` returns response JSON
- `HttpGetJson(url)` returns response JSON
- `ReadSettings()` reads Config table into a dictionary
- `WriteTable(listObjectName, rows)` bulk writes to Excel table

## modService

- `EnsureServiceRunning()`
- Checks service exe path and starts if not running.
- Polls `GET /v1/health` until ready.

## modSync

- `SyncAll()`
- Read settings and accounts table.
- POST `/v1/rules/import` with Rules table.
- POST `/v1/sync` with `since` and account list.
- GET `/v1/transactions?since=...`
- Replace Transactions table rows.
- Refresh pivots and charts.

## modRules

- `ImportRules()` posts rules.
- `ApplyRules(force)` posts `/v1/rules/apply`.

## modOverrides

- `CommitOverrides()`
- Compare current table to snapshot.
- POST `/v1/overrides/import` with changes.
- Update snapshot.

## modDiagnostics

- `ShowDiagnostics()`
- GET `/v1/diagnostics` and display summary.
- Optionally GET `/v1/logs?tail=200` for quick tail.

## Required HTTP Calls

- `GET /v1/health`
- `POST /v1/rules/import`
- `POST /v1/sync`
- `GET /v1/transactions?since=...`
- `POST /v1/overrides/import`
- `POST /v1/rules/apply`
- `GET /v1/diagnostics`
- `GET /v1/logs?tail=200`

## Notes

- VBA must not handle secrets.
- Store a hidden snapshot sheet or hash per row to detect changes.
- Use bulk table writes to avoid slow per-cell updates.
- Reminder/assistant sheets are populated by VBA (values) to avoid Excel structured-reference issues.
