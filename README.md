# BudgetExcel

Windows-only, local-first budgeting system where Microsoft Excel is the primary UI and a local Go service handles sync/import, storage, categorization, and exports.

The Excel workbook (`excel/Budget.xlsm`) is the UI. A local Go service (`service/`) exposes a localhost-only HTTP API using Fiber and stores data in SQLite. CSV is the MVP import; OFX is optional (M2).

## Core Goals

- Excel-driven workflow with deterministic rules and manual overrides.
- Local-only service bound to 127.0.0.1; no remote access.
- Idempotent syncs (re-importing does not create duplicates).
- Manual category overrides persist across re-sync and re-categorize.
- Windows-native secrets storage using DPAPI (or Credential Manager).

## Repository Layout

- `excel/` Excel workbook + VBA modules.
- `service/` Go service (Fiber), SQLite, migrations, connectors.
- `installer/` WiX MSI packaging assets.
- `docs/` Architecture and build documentation.

## Documentation Index

- `docs/architecture.md`
- `docs/end-state.md`
- `docs/current-status.md`
- `docs/build-plan.md`
- `docs/build-plan-quick.md`
- `docs/api.md`
- `docs/db-schema.md`
- `docs/csv-mapping.md`
- `docs/vba.md`
- `docs/acceptance-tests.md`
- `docs/edge-cases.md`
- `docs/budget-dashboard.md`
- `docs/packaging.md`
- `docs/setup.md`
- `docs/security.md`
- `docs/troubleshooting.md`

## Non-Goals

- Cross-platform support.
- Cloud or remote access.
- VBA handling of secrets.
