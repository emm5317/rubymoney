# API Specification

All endpoints are local-only and served from `http://127.0.0.1:8787` by default.

## Error Envelope (all endpoints)

```json
{ "error": { "code": "...", "message": "...", "details": ... } }
```

## GET /v1/health

Response:

```json
{
  "version": "0.1.0",
  "uptime_sec": 42,
  "db_path": "C:/Users/Admin/AppData/Local/BudgetApp/data/budget.sqlite",
  "last_sync": "2026-02-09T22:10:00Z"
}
```

## GET /v1/diagnostics

Response (example):

```json
{
  "last_sync_at": "2026-02-09T22:10:00Z",
  "status": "success",
  "summary_json": "{...redacted summary...}"
}
```

## POST /v1/rules/import

Request:

```json
{
  "rules": [
    {
      "rule_id": "uuid",
      "priority": 1,
      "enabled": true,
      "match_field": "payee",
      "match_type": "contains",
      "match_value": "STARBUCKS",
      "category": "Food",
      "subcategory": "Coffee",
      "notes": "optional"
    }
  ]
}
```

Response:

```json
{ "status": "ok", "count": 1 }
```

## POST /v1/rules/apply

Request (default applies to uncategorized only):

```json
{ "force": false }
```

Response:

```json
{ "status": "ok", "applied": 12, "cleared": 3, "total": 120 }
```

## POST /v1/overrides/import

Request:

```json
{
  "overrides": [
    {
      "txn_id": "uuid",
      "category": "Food",
      "subcategory": "Coffee",
      "updated_at": "2026-02-09T22:12:00Z"
    }
  ]
}
```

Response:

```json
{ "status": "ok", "count": 1 }
```

## GET /v1/transactions?since=YYYY-MM-DD

Response:

```json
{
  "transactions": [
    {
      "txn_id": "uuid",
      "external_txn_id": "ext-1",
      "account_id": "acc-1",
      "posted_date": "2026-02-08",
      "amount": -5.25,
      "payee": "STARBUCKS",
      "memo": "LATTE",
      "category": "Food",
      "subcategory": "Coffee",
      "category_source": "rule:uuid",
      "pending": false,
      "fingerprint": "hash",
      "raw_ref": "raw-1",
      "imported_at": "2026-02-09T22:12:00Z"
    }
  ]
}
```

## POST /v1/sync

CSV path sync request (MVP). Requires exactly one `account_id` in `account_ids`:

```json
{
  "since": "2026-01-01",
  "account_ids": ["acc-1"],
  "connector_options": {
    "csv_path": "C:/Users/Admin/Downloads/BudgetImports/sample.csv"
  }
}
```

Response:

```json
{
  "status": "imported",
  "imported": 120,
  "updated": 4,
  "matched_pending": 2,
  "skipped": 2,
  "bad_rows": 1,
  "bad_row_info": ["row 42: unparseable date: 13/99/2025"]
}
```
