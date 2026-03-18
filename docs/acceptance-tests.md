# Acceptance Tests

## Import Pipeline

1. **CSV import — no duplicates:** Import the same CSV file twice for the same account. Second import should flag all rows as duplicates in the preview step. Confirming should insert zero new transactions.
2. **OFX import — FITID dedup:** Import an OFX file, then import it again. FITID-based deduplication should prevent any duplicates.
3. **CSV column auto-detection:** Import a CSV with non-standard headers (e.g., "Trans Date", "Debit", "Credit"). `CsvAdapter` should auto-detect column mappings.
4. **Import profile learning:** Import from the same account twice with the same CSV format. Second import should reuse learned column mappings from `ImportProfile`.
5. **Auto-categorization after import:** Create a rule matching "GROCERY" → "Groceries" category. Import a CSV containing a transaction with "GROCERY STORE" in the description. After confirming, the transaction should be auto-categorized.

## Categorization

6. **Rule priority order:** Create two rules matching the same description with different categories. The higher-priority rule should win.
7. **Manual override preserved:** Manually set a category on a transaction. Run `Categorizer#apply_retroactive`. The manual category should not be overwritten.
8. **Retroactive categorization:** Add a new rule. Run `Categorizer#apply_retroactive`. Previously uncategorized transactions matching the rule should now be categorized.
9. **Regex rule matching:** Create a rule with `match_type: regex` and pattern `^AMZ.*MKTP`. Import transactions with "AMZN MKTP US" — should match.

## Accounts & Transactions

10. **Balance tracking:** Create an account with a starting balance. Import transactions. Account balance should reflect starting balance + sum of transaction amounts.
11. **User data isolation:** Verify that `current_user.accounts` scoping prevents any cross-user data access (relevant if multi-user is added).

## Budgets

12. **Monthly budget tracking:** Set a budget for "Groceries" at $500/month. Import grocery transactions totaling $350. Budget view should show $150 remaining.
13. **Budget uniqueness:** Attempting to create two budgets for the same category + month + year should fail validation.

## Running Tests

```bash
# Full test suite
bundle exec rspec

# Model specs only
bundle exec rspec spec/models/

# Service specs only
bundle exec rspec spec/services/

# Specific spec file
bundle exec rspec spec/services/categorizer_spec.rb
```

## Test Data Fixtures

- Factory definitions in `spec/factories/` for all 10 models.
- `db/seeds.rb` provides 15 default categories and a dev user.
- Sample CSV/OFX files for import testing should be placed in `spec/fixtures/files/`.
