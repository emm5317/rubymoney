# Current Status

## Repo State (as of 2026-02-09)

- Folder structure created.
- Excel workbook initialized and VBA modules updated for JSON-safe payloads and diagnostics output.
- WiX MSI build fixed for 64-bit Program Files installs and Start Menu shortcut targeting.
- Documentation exists for architecture, API, DB schema, CSV mapping, VBA outline, acceptance tests, packaging, setup, security, troubleshooting, and build plans.
- Initial SQLite migrations created and applied.

## Implemented

- `service/migrations/0001_init.up.sql`
- `service/migrations/0001_init.down.sql`
- Go service skeleton with Fiber in `service/cmd/budgetd/main.go`.
- DB open + migrations runner in `service/internal/db/db.go`.
- Core API endpoints including rules apply in `service/internal/api/api.go`.
- CSV mapping loader and parser in `service/internal/connectors/csv/`.
- CSV sync persistence with idempotent upsert and pending->posted reconciliation.
- Rules engine implementation in `service/internal/rules/rules.go`.
- VBA modules in `excel/vba/`.
- WiX packaging assets + build script in `installer/`.
- Helper scripts in `scripts/` for CSV fixture generation and health checks.
- Automated tests for CSV importer, rules, idempotent upsert, and overrides.
- Minimal redaction helper in `service/internal/logging/logging.go`.
- Core model structs in `service/internal/models/`.
- DB repo helpers in `service/internal/db/repo.go`.
- Local SQLite database initialized at `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`.
- Budget dashboard VBA module (`modBudget.bas`) with plan, envelopes, reallocations, and dashboard tables.

## Tooling Verified

- Go installed (`go version` works).
- Git installed (`git --version` works).
- WiX Toolset v3.14 installed (`candle` / `light` work).
- `golang-migrate` CLI installed with CGO enabled.
- MinGW installed for CGO builds.

## Tests

- `go test ./...` passes when run with:
  - `CGO_ENABLED=1`
  - `CC=gcc`
  - MinGW in PATH (`C:\ProgramData\mingw64\mingw64\bin`)

## Not Implemented Yet

- None of the core MVP components remain.

## Next Build Milestones

- Optional: add WiX startup task toggle.
- Optional: add seeded CSV mapping fixtures for test imports.
