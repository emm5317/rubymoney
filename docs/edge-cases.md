# Edge Cases

## Pending -> Posted Reconciliation

- If a posted txn arrives that matches a pending txn:
- Same account
- Same amount
- Payee or memo similarity
- Date within +/- 7 days
- Update pending row to posted rather than insert new.

## Dedupe Strategy

- If `external_txn_id` exists: upsert by `(account_id, external_txn_id)`.
- Else: compute `fingerprint = sha256(account_id|date|amount|normalized_payee|normalized_memo)` and upsert by `(account_id, fingerprint)`.

## Amount Sign Conventions

- Support `expenses_negative` and `expenses_positive`.
- Normalize to internal standard before hashing.

## Date Parsing

- Use mapping-defined date format list in order.
- Reject or quarantine rows with unparseable dates.

## Overrides Protection

- When applying rules, skip any txn with an override row.
- Never overwrite `category` and `subcategory` for overridden txns.

## CSV Quirks

- Handle quoted commas.
- Trim whitespace in headers.
- Normalize payee and memo for fingerprinting.
