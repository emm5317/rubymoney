# API Spec

## Error Envelope

All errors return:

```json
{
  "error": {
    "code": "...",
    "message": "...",
    "details": {}
  }
}
```

## GET /v1/health

Response:

```json
{
  "version": "0.1.0",
  "uptime_seconds": 1234,
  "db_path": "C:\\Users\\...\\budget.sqlite",
  "last_sync": "2026-02-09T12:34:56Z"
}
```

## POST /v1/rules/import

Request:

```json
{
  "rules": [
    {
      "rule_id": "uuid",
      "priority": 10,
      "enabled": true,
      "match_field": "payee",
      "match_type": "contains",
      "match_value": "GROCERY",
      "category": "Food",
      "subcategory": "Groceries",
      "notes": ""
    }
  ]
}
```

Response:

```json
{
  "upserted": 12,
  "disabled": 3
}
```

## POST /v1/rules/apply

Request:

```json
{
  "scope": "uncategorized",
  "force": false
}
```

Response:

```json
{
  "updated": 120,
  "skipped_overrides": 15
}
```

## POST /v1/sync

Request:

```json
{
  "since": "2025-08-01",
  "account_ids": ["uuid1", "uuid2"],
  "connector_options": {
    "csv": {
      "path": "C:\\Users\\...\\Downloads\\BudgetImports"
    }
  }
}
```

Response:

```json
{
  "sync_run_id": "uuid",
  "status": "ok",
  "imported": 450,
  "updated": 15,
  "skipped": 3
}
```

## GET /v1/transactions?since=YYYY-MM-DD

Response:

```json
{
  "transactions": [
    {
      "txn_id": "uuid",
      "external_txn_id": "bank-123",
      "account_id": "uuid",
      "posted_date": "2025-08-11",
      "amount": -45.67,
      "payee": "GROCERY MART",
      "memo": "",
      "category": "Food",
      "subcategory": "Groceries",
      "category_source": "rule:uuid",
      "pending": false,
      "fingerprint": "sha256...",
      "imported_at": "2025-08-11T12:00:00Z",
      "raw_ref": "raw-uuid"
    }
  ]
}
```

## POST /v1/overrides/import

Request:

```json
{
  "overrides": [
    {
      "txn_id": "uuid",
      "category": "Dining",
      "subcategory": "Restaurants"
    }
  ]
}
```

Response:

```json
{
  "upserted": 10
}
```

## GET /v1/diagnostics

Response:

```json
{
  "last_sync": {
    "sync_run_id": "uuid",
    "started_at": "2026-02-09T12:34:56Z",
    "ended_at": "2026-02-09T12:35:20Z",
    "status": "ok",
    "summary": {
      "accounts": 2,
      "imported": 450,
      "updated": 15,
      "skipped": 3
    }
  },
  "last_error": null
}
```

## GET /v1/logs?tail=200

Response:

```json
{
  "lines": [
    "2026-02-09T12:34:56Z INFO sync started account=...",
    "2026-02-09T12:35:20Z INFO sync finished imported=..."
  ]
}
```

## POST /v1/import/csv

Request (file path):

```json
{
  "path": "C:\\Users\\...\\Downloads\\BudgetImports\\bank.csv",
  "institution": "Bank A"
}
```

Response:

```json
{
  "imported": 120,
  "updated": 5,
  "skipped": 0
}
```
