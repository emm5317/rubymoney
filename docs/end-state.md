# End State

## Product Definition of Done

- User opens `Budget.xlsm` and clicks Sync.
- Workbook ensures `budgetd.exe` is running.
- Transactions are imported and shown in `Transactions` table.
- Rules categorize deterministically.
- Dashboard pivots and charts refresh.
- Repeated syncs produce no duplicates (idempotent).
- Manual category edits in Excel can be committed and persist.
- CSV import works for MVP.
- OFX connector is stubbed or optional (M2).

## Functional Requirements

- Excel UI tables use fixed ListObject names and columns.
- Sync and rule workflows work end to end.
- Overrides protect manual edits on re-categorize.
- Diagnostics show last sync summary with redacted errors.
- Local-only: service binds to 127.0.0.1 only.

## Technical Requirements

- Go service using Fiber.
- SQLite with migrations.
- WiX MSI packaging for Windows.
- Secrets stored using DPAPI or Credential Manager.
- Logs are redacted and never include secrets.

## Quality Requirements

- Idempotency for all imports.
- Pending->posted reconciliation to avoid duplicates.
- Deterministic rule application order.
- Clear error envelope for all API failures.

## Deliverables

- Excel workbook with VBA modules and UI tables.
- Go service binary.
- SQLite schema and migrations.
- WiX MSI build scripts.
- Documentation covering architecture, API, DB schema, CSV mapping, VBA, security, troubleshooting.
