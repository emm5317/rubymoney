# Security

## Local-Only Operation

- Service binds to `127.0.0.1` only.
- No remote listeners or network exposure.

## Secrets Handling

- Secrets are never handled by Excel or VBA.
- Secrets are stored using Windows DPAPI or Credential Manager.
- Encrypted blobs stored under `%LOCALAPPDATA%\BudgetApp\secrets\`.
- Logs and API responses must never include secrets.

## Redaction

- Log entries redact tokens, account credentials, and sensitive payloads.
- Diagnostics endpoint returns redacted summaries only.

## Data at Rest

- SQLite stored in user profile directory with OS-level file permissions.
- Raw payload blobs are optional and size-capped.

## Transport

- HTTP on localhost only.
- No TLS required for loopback.
