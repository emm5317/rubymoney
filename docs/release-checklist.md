# Release Checklist

Use this checklist for a pre-release smoke of the BudgetExcel MVP.

## Build and Package

- [ ] Run tests with CGO enabled (MinGW in PATH):
  - `cd C:\dev\budgetexcel\service`
  - `$env:Path += ";C:\ProgramData\mingw64\mingw64\bin"`
  - `$env:CGO_ENABLED="1"; $env:CC="gcc"`
  - `go test ./...`
- [ ] Build MSI:
  - `powershell -ExecutionPolicy Bypass -File C:\dev\budgetexcel\installer\build.ps1`
- [ ] Verify MSI output:
  - `C:\dev\budgetexcel\installer\wix\output\BudgetApp.msi`

## Install Validation

- [ ] Install MSI on a clean machine or test VM (run from an elevated shell; per-machine install requires admin).
- [ ] Verify `budgetd.exe` installed at `C:\Program Files\BudgetApp\budgetd.exe`.
- [ ] Verify Start Menu shortcut `Budget Service` exists and launches the service.

## Service Smoke

- [ ] Launch `budgetd.exe` and confirm:
  - `GET http://127.0.0.1:8787/v1/health` returns version and DB path.
- [ ] Confirm DB file created at `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`.

## Excel Smoke

- [ ] Open `excel/Budget.xlsm`.
- [ ] Ensure `Config` table `settings` is populated (service_url, csv_import_folder, sync_since_days).
- [ ] Ensure `Accounts` table has at least one CSV account with `account_id` filled.
- [ ] Click `Sync` and confirm:
  - Service starts if not running.
  - Rules import succeeds.
  - CSV sync returns counts.
  - Transactions table populates.
  - Pivots refresh.

## Idempotency and Overrides

- [ ] Import the same CSV twice -> no duplicate rows.
- [ ] Edit categories for 5-10 rows -> Commit Overrides -> Re-apply rules -> overrides persist.

## Notes / Known Constraints

- CSV sync currently requires exactly one `account_id` in request.
- Raw CSV data is not stored in `raw_blobs` for MVP.
- Pending -> posted reconciliation uses exact normalized payee/memo equality.
