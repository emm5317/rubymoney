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
10. **Rule preview:** Fill in rule criteria on the rule form and click "Test Rule". Matching transactions should appear in a Turbo Frame preview.

## Accounts & Transactions

11. **Balance tracking:** Create an account with a starting balance. Import transactions. Account balance should reflect starting balance + sum of transaction amounts.
12. **User data isolation:** Verify that `current_user.accounts` scoping prevents any cross-user data access.
13. **Transaction search:** Enter "STARBUCKS" in the search box. Only transactions with matching description/normalized_desc should appear.
14. **Column sorting:** Click the "Amount" header. Transactions should sort by amount. Click again to reverse.
15. **CSV export:** Apply filters, click "Export CSV". Downloaded file should contain only the filtered transactions.

## Budgets

16. **Monthly budget tracking:** Set a budget for "Groceries" at $500/month. Import grocery transactions totaling $350. Budget view should show $150 remaining.
17. **Budget uniqueness:** Attempting to create two budgets for the same category + month + year should fail validation.
18. **Copy from previous month:** Set budgets for January. Navigate to February and click "Copy Previous". February should get the same budget amounts.

## Recurring Transactions

19. **Auto-detection:** Import 4+ months of statements containing a monthly Netflix charge. Run "Detect Now". A RecurringTransaction should be created with frequency "monthly" and confidence > 0.7.
20. **Missed charge detection:** After detection, if the expected next date passes without a matching transaction appearing, the status should change to "missed" on the next detection run.
21. **User confirm:** Click "Confirm" on an auto-detected recurring transaction. `user_confirmed` should be set to true.
22. **User dismiss:** Click "Dismiss" on a false positive. The record should be hidden from the main list. Re-detection should not resurface it.
23. **Manual marking:** From the Suggestions section, click "Track" on a transaction group. A RecurringTransaction should be created with `user_confirmed: true`.
24. **Amount change detection:** If a recurring charge increases by >15%, the "changed" badge should appear next to the amount.
25. **Dashboard integration:** The dashboard should show a "Recurring Charges" section with total monthly cost and count of missed charges.

## Dashboard

26. **Period navigation:** Click "Prev"/"Next" month buttons. All dashboard data should update to the selected month.
27. **Category drilldown:** Click a category in the spending chart. A table of matching transactions should appear below.
28. **Transfer exclusion:** Import a transfer between two accounts. Dashboard income/expense totals should not include the transfer amounts.

## Running Tests

```bash
# Full test suite (Docker):
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test

# Model specs only:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/models/"

# Service specs only:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/services/"

# Request specs only:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/requests/"
```

## Test Data

- Factory definitions in `spec/factories/` for all 11 models.
- `db/seeds.rb` provides 15 default categories and a dev user.
- Sample CSV/OFX files for import testing should be placed in `spec/fixtures/files/`.
