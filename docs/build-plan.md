# Build Plan (Windows / PowerShell)

This is a comprehensive, step-by-step plan to implement the full BudgetExcel system.

## Phase 0 - Prereqs and Tooling

Verify:

```powershell
go version
git --version
```

Install WiX (v3):

```powershell
choco install -y wixtoolset
$env:Path += ";C:\Program Files (x86)\WiX Toolset v3.14\bin"
```

Install MinGW (for CGO builds):

```powershell
choco install -y mingw
```

Install golang-migrate (SQLite, CGO-enabled):

```powershell
$env:Path += ";C:\ProgramData\mingw64\mingw64\bin;$env:GOPATH\bin"
$env:CGO_ENABLED = "1"
$env:CC = "gcc"

go install -tags "sqlite3" "github.com/golang-migrate/migrate/v4/cmd/migrate@latest"
```

Verify tools:

```powershell
candle -?
light -?
migrate -version
```

## Phase 1 - Go Service Skeleton

Create the module (if not already created):

```powershell
cd C:\dev\budgetexcel\service

go mod init budgetexcel/service

go get github.com/gofiber/fiber/v2
go get github.com/gofiber/fiber/v2/middleware/logger
go get github.com/gofiber/fiber/v2/middleware/recover
go get github.com/mattn/go-sqlite3
go get github.com/golang-migrate/migrate/v4
go get github.com/golang-migrate/migrate/v4/database/sqlite3
go get github.com/golang-migrate/migrate/v4/source/file
go get github.com/google/uuid
```

Implement `budgetd`:

- `cmd/budgetd/main.go`: config, logging, Fiber setup, route registration.
- `internal/logging`: structured logging + redaction helpers.
- `internal/api`: handlers and request/response structs.

## Phase 2 - Database Wiring

- `internal/db`: open SQLite, migrations runner, query helpers.
- Ensure `PRAGMA foreign_keys = ON` and WAL mode.

Run migrations:

```powershell
migrate -path "C:/dev/budgetexcel/service/migrations" -database "sqlite3://C:/Users/Admin/AppData/Local/BudgetApp/data/budget.sqlite" up
```

## Phase 3 - Models and Repos

- `internal/models`: typed models for accounts, transactions, rules, overrides, sync_runs.
- `internal/db`: repo functions for CRUD and upserts.
- Implement idempotent upsert logic (external id or fingerprint).

## Phase 4 - Rules Engine

- `internal/rules`: deterministic matching and apply.
- Respect overrides: if override exists, do not overwrite category/subcategory.
- Add `apply rules` modes: uncategorized (default) and force.

## Phase 5 - CSV Connector (MVP)

- `internal/connectors/csv`: mapping, parsing, normalization, and import pipeline.
- Load mapping config from `%LOCALAPPDATA%\BudgetApp\config\csv_mappings.json`.
- Auto-detect headers fallback for common banks.
- Implement file-path import for MVP.

## Phase 6 - Sync Pipeline

- `internal/sync`: orchestrate import, dedupe, pending->posted reconciliation.
- Implement per-account sync runs with summary stored in `sync_runs`.

## Phase 7 - HTTP API (Fiber)

Implement endpoints:

- `GET /v1/health`
- `POST /v1/rules/import`
- `POST /v1/rules/apply`
- `POST /v1/sync`
- `GET /v1/transactions?since=YYYY-MM-DD`
- `POST /v1/overrides/import`
- `GET /v1/diagnostics`
- `GET /v1/logs?tail=200`

Add consistent JSON error envelope:

```json
{ "error": { "code": "...", "message": "...", "details": ... } }
```

## Phase 8 - Excel + VBA

Implement VBA modules:

- `modService`: start/check service
- `modSync`: push rules, sync, pull transactions, refresh pivots
- `modRules`: push rules, apply rules
- `modOverrides`: detect edits, push overrides
- `modDiagnostics`: show last sync summary/errors

Use table names exactly as specified in `docs/vba.md` and `docs/db-schema.md`.

## Phase 9 - Packaging (WiX)

- Implement WiX project `installer/wix/BudgetApp.wxs`.
- Create `installer/build.ps1` to build `budgetd.exe`, then candle/light the MSI.

## Phase 10 - Tests

Manual acceptance tests (see `docs/acceptance-tests.md`).

Add automated tests:

- CSV import idempotency
- Rules application and override protection
- Pending->posted reconciliation
- Error envelope contract

## Run Targets

Local dev run:

```powershell
cd C:\dev\budgetexcel\service
go run .\cmd\budgetd
```

Build MSI (after WiX project added):

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\budgetexcel\installer\build.ps1
```
