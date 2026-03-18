# Import Pipeline

## Overview

The import system parses bank/credit card statement files, deduplicates transactions, and auto-categorizes them. It supports CSV and OFX/QFX formats via an adapter pattern.

## Flow

```
Upload file → Adapter parses → Preview (with duplicate detection) → User confirms → Persist → Auto-categorize
```

1. **Upload:** User selects an account and uploads a file via `ImportsController`.
2. **Parse:** `ImportProcessor` selects the appropriate adapter based on file extension.
3. **Preview:** Parsed transactions are shown in a table. Duplicates (matching `source_fingerprint`) are flagged.
4. **Confirm:** User reviews and confirms. Transactions are persisted to the database.
5. **Categorize:** `Categorizer` runs against new transactions, applying matching `Rule` records.

## Adapters

### Base Interface (`app/services/importers/base_adapter.rb`)

All adapters implement:
- `#parse` — returns an array of transaction hashes with standardized keys.

### CSV Adapter (`app/services/importers/csv_adapter.rb`)

- Auto-detects column mappings (date, description, amount, or separate debit/credit).
- Handles currency symbols (`$`), parentheses for negatives `(100.00)`, and whitespace.
- Computes `source_fingerprint` as `SHA256(account_id|date|amount_cents|normalized_description)`.
- Learns column mappings via `ImportProfile` for repeat imports from the same institution.

### OFX Adapter (`app/services/importers/ofx_adapter.rb`)

- Parses OFX/QFX files using the `ofx` gem.
- Uses the FITID (Financial Transaction ID) as `source_fingerprint`.
- Extracts date, amount, description, and transaction type.

## Deduplication

- **Database-level:** Unique index on `[account_id, source_fingerprint]` prevents duplicates.
- **Preview-level:** Before confirmation, existing fingerprints are checked and duplicates are flagged in the UI.

## Import Profiles (`ImportProfile` model)

- Keyed by `[account_id, institution]`.
- Stores learned column mappings, date formats, and description corrections.
- Applied automatically on subsequent imports from the same account+institution.

## Auto-Categorization

After import confirmation, `Categorizer#categorize_batch` runs on all new transactions:
- Rules are applied in priority order (highest first).
- Match types: `contains`, `exact`, `starts_with`, `regex`, `gt`, `lt`, `between`.
- Match fields: `description`, `normalized_desc`, `amount_field`.

## Adding a New Adapter

1. Create `app/services/importers/your_adapter.rb` inheriting from `Importers::BaseAdapter`.
2. Implement `#parse` returning standardized transaction hashes.
3. Register the file extension in `ImportProcessor`.
