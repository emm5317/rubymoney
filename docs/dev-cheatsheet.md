# Dev Cheatsheet

## Login

- **Email:** admin@example.com
- **Password:** password123

## Server (Docker — primary workflow)

```bash
docker compose up -d --build              # Start app (port 3030)
docker compose down                       # Stop all services
docker compose logs -f web                # Tail app logs
docker compose exec web bin/rails console # Rails console
docker compose exec web bin/rails db:seed # Seed categories + dev user
docker compose exec web bin/rails db:migrate # Run pending migrations
```

## Testing (Docker)

```bash
# Full test suite:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test

# Specific specs:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/models/"

# Rebuild test image after Gemfile changes:
docker compose -f docker-compose.yml -f docker-compose.test.yml build test
```

## Rails Console Quick Reference

```ruby
# Users & accounts
user = User.first
user.accounts
user.accounts.first.transactions.count

# Transaction scopes
Transaction.uncategorized
Transaction.for_month(Date.today)
Transaction.debits.sum(:amount_cents)
Transaction.credits.sum(:amount_cents)
Transaction.recent.limit(10)

# Categorization
Categorizer.new.apply_retroactive

# Recurring detection
RecurringDetector.new(User.first).detect_all

# Import processor
processor = ImportProcessor.new(account: account, file: file)
processor.parse    # Returns preview data
processor.confirm  # Persists + auto-categorizes
```

## Useful URLs (Development)

| URL | Description |
|-----|-------------|
| http://localhost:3030 | App home |
| http://localhost:3030/good_job | Background job dashboard |
| http://localhost:3030/recurring_transactions | Recurring charges management |

## Key File Locations

| What | Where |
|------|-------|
| Models | `app/models/` (13 models) |
| Controllers | `app/controllers/` (11 controllers) |
| Services | `app/services/` (Categorizer, RecurringDetector, TransferMatcher, ImportProcessor) |
| Import adapters | `app/services/importers/` (BaseAdapter, CsvAdapter, OfxAdapter) |
| Stimulus JS | `app/javascript/controllers/` |
| Factories | `spec/factories/` (11 factories) |
| Seeds | `db/seeds.rb` |
| Routes | `config/routes.rb` |
| Schema | `db/schema.rb` |
| Cron jobs | `config/application.rb` (good_job.cron) |
| Design system | `app/views/CLAUDE.md` |

## Background Jobs (good_job)

| Job | Schedule | Purpose |
|-----|----------|---------|
| `BalanceSnapshotJob` | Daily 2 AM | Record account balance snapshots |
| `RecurringDetectionJob` | Daily 3 AM | Detect recurring transaction patterns |
| `ImportProcessJob` | On demand | Process file imports |

## Database

```bash
# Connect to Docker PostgreSQL from host:
psql -h localhost -p 5437 -U rubymoney rubymoney_development

# Full reset (WARNING: destroys data):
docker compose exec web bin/rails db:reset
```
