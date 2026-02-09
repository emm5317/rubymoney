# Current Status

## Repo State (as of 2026-02-09)

- Folder structure created.
- Stub files present for Excel, VBA modules, Go service, WiX, and docs.
- Documentation exists for architecture, API, DB schema, CSV mapping, VBA outline, acceptance tests, packaging, setup, security, troubleshooting.
- Initial SQLite migrations created and applied.

## Implemented

- `service/migrations/0001_init.up.sql`
- `service/migrations/0001_init.down.sql`
- Local SQLite database initialized at:
- `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`

## Tooling Verified

- Go installed (`go version` works).
- Git installed (`git --version` works).
- WiX Toolset v3.14 installed (`candle` / `light` work).
- `golang-migrate` CLI installed with CGO enabled.
- MinGW installed for CGO builds.

## Not Implemented Yet

- Go service source code.
- CSV connector implementation.
- Rules engine implementation.
- VBA module code in Excel.
- WiX build and MSI packaging scripts.
- Automated tests.

## Issues / Observations

- A duplicate nested path exists: `C:\dev\budgetexcel\budgetexcel\service\...`.
- Confirm whether this folder is needed or should be removed.

## Next Build Milestones

- Implement Go service skeleton and API endpoints.
- Add SQLite data access layer and migrations wiring.
- Implement CSV connector and mapping config.
- Implement VBA macros and Excel table schema.
- Add WiX packaging and build script.
- Add tests (CSV import, rules, idempotency, overrides).
