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

- Validate `csv_mappings.json` format.
- Confirm date formats align with the CSV export.
- Check amount convention and sign normalization.
- Ensure CSV headers match a mapping and the file is UTF-8 (no BOM).

## Diagnostics Endpoint Empty

- Ensure a sync has run.
- Confirm `/v1/diagnostics` is not redacting the entire payload.
