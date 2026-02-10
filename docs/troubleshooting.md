# Troubleshooting

## Service Not Running

- Ensure `budgetd.exe` exists and is reachable by VBA.
- Check Windows Defender or AV exclusions.
- Verify port `8787` is not in use.

## Sync Fails

- Open Diagnostics in Excel to view last error.
- Verify `service_url` in Config sheet is `http://127.0.0.1:8787`.
- Check `GET /v1/health` for status.

## Duplicate Transactions

- Confirm CSV headers map correctly.
- Ensure external IDs are present when available.
- Check fingerprint inputs (amount, date, payee, memo) for normalization.

## Categories Not Persisting

- Ensure overrides are posted via Commit Overrides.
- Confirm `/v1/overrides/import` returns success.
- Verify rule apply logic skips transactions with overrides.

## CSV Import Errors

- Validate mapping files under `%LOCALAPPDATA%\BudgetApp\config\csv_mappings\` (or legacy `csv_mappings.json`) format.
- Confirm date formats align with the CSV export.
- Check amount convention and sign normalization.
- If using `file_name_hints` or `file_name_regex`, confirm the CSV filename matches.
- Ensure CSV headers match a mapping and the file is UTF-8 (no BOM).
- Bank of America statement CSVs include summary lines; ensure `header_row` and `skip_rows` are set (header is row 7).
- If sync fails with `FOREIGN KEY constraint failed`, the `account_id` in Excel does not exist in the service database. Ensure the Accounts sheet uses an existing `account_id`, or insert the account into the local `accounts` table.
- If transactions import succeeds but the Transactions table stays empty, the table headers may be collapsed into a single cell. Run the `FixTransactionsTableHeaders` macro (module `modTroubleshoot`) to restore the 20 expected headers and then re-run import.

## Diagnostics Endpoint Empty

- Ensure a sync has run.
- Confirm `/v1/diagnostics` is not redacting the entire payload.

## Suggestions Not Appearing

- Confirm `LLM_ENABLED=true` and `LLM_MODEL_PATH` points to a valid GGUF file.
- Ensure `llama-cli` (or `llama`) is available on `PATH`.
- Run `Refresh Suggestions` after `Suggest Categories (Blanks)` to pull suggested fields into Excel.
- If suggestions are queued but no updates appear, check `logs` for `suggestion job error` messages.
