# Budget Dashboard (Envelope + Yearly Plan)

This doc describes the Master/Dashboard flow for envelope budgeting and yearly planning in `excel/Budget.xlsm`.

## Setup

1. Import the new VBA module `modBudget.bas` into the workbook.
2. Run the macro `SetupBudgetDashboard`.
3. Populate the `plan_annual` table on the `Plan` sheet.
4. Run `RebuildEnvelopesForYear` (optional year argument). This creates 12 months of envelopes per plan row.
5. Run `SyncAll` to refresh transactions, envelopes, pivots, and dashboard.

## Sheets and Tables

### Plan sheet
Table: `plan_annual`

Columns:
- `category` (text)
- `subcategory` (text)
- `type` (text: `expense` or `income`)
- `rollover` (text: `yes` or `no`)
- `jan`..`dec` (monthly targets)
- `annual_total` (formula: `=SUM([@[jan]]:[@[dec]])`)
- `notes`
- `key` (formula: `=[@category]&"|"&[@subcategory]`)

### Envelopes sheet
Table: `envelopes`

Columns:
- `month` (date, first day of month)
- `category`
- `subcategory`
- `budgeted` (from `plan_annual` based on month)
- `realloc_in` (from `reallocations`)
- `realloc_out` (from `reallocations`)
- `spent` (from `transactions`)
- `rollover_in` (previous month `rollover_out`)
- `available` (= budgeted + realloc_in - realloc_out + rollover_in)
- `remaining` (= available - spent)
- `rollover_out` (if `plan_annual[rollover]="yes"`, positive remainder)

### Reallocations sheet
Table: `reallocations`

Columns:
- `date`
- `month` (formula: `=DATE(YEAR([@date]),MONTH([@date]),1)`)
- `from_category`
- `from_subcategory`
- `to_category`
- `to_subcategory`
- `amount`
- `note`

### Dashboard sheet
Tables:
- `dashboard_params` (keys: `current_month`, `current_year`)
- `dashboard_summary` (current month totals, envelope remaining, YTD net)
- `dashboard_overspent` (top 5 envelopes with negative remaining)
- `dashboard_ytd` (budgeted vs spent YTD by category/subcategory)

## How It Works

- `plan_annual` defines monthly targets and rollover rules.
- `RebuildEnvelopesForYear` generates month/category rows.
- `envelopes` formulas pull `budgeted` from the plan and `spent` from `transactions`.
- `reallocations` moves funds between envelopes within a month.
- The dashboard uses table formulas (no per-cell loops) and refreshes on `SyncAll`.

## Notes

- Amounts assume expenses are negative in `transactions`. The `spent` formula uses `-SUMIFS(...)` to convert to positive outflow.
- Seasonal categories are supported by placing amounts in specific months in `plan_annual`.
- For income planning, set `plan_annual[type]` to `income` and those rows will be skipped by `RebuildEnvelopesForYear`.
- Dashboard formulas use `XLOOKUP`, `FILTER`, `SORTBY`, and `LET` (Excel 365/2021+).
- If automation fails or tables do not persist, close all Excel/VBA windows and reopen the workbook so it is not read-only, then re-run `SetupBudgetDashboard` or `SetupDashboardOnly`.
