# Dev Cheatsheet

## Login

- **Email:** admin@example.com
- **Password:** password123

## Server

```bash
bin/rails server                    # Start dev server (port 3000 by default)
bin/rails server -p 3030            # Start on port 3030
docker compose up -d                # Start via Docker (port 3030)
```

## Database

```bash
bin/rails db:create                 # Create dev + test databases
bin/rails db:migrate                # Run pending migrations
bin/rails db:seed                   # Seed categories + dev user
bin/rails db:reset                  # Drop, create, migrate, seed
RAILS_ENV=test bin/rails db:prepare # Prepare test database
```

## Testing

```bash
bundle exec rspec                   # Full suite
bundle exec rspec spec/models/      # Model specs
bundle exec rspec spec/services/    # Service specs
bundle exec rspec --format doc      # Verbose output
```

## Rails Console

```ruby
# Find user
User.first

# Account scoping
user = User.first
user.accounts
user.accounts.first.transactions

# Transaction scopes
Transaction.uncategorized
Transaction.for_month(Date.today)
Transaction.debits
Transaction.credits
Transaction.recent.limit(10)

# Categorization
Categorizer.new.apply_retroactive

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

## Key File Locations

| What | Where |
|------|-------|
| Models | `app/models/` |
| Controllers | `app/controllers/` |
| Services | `app/services/` |
| Import adapters | `app/services/importers/` |
| Factories | `spec/factories/` |
| Seeds | `db/seeds.rb` |
| Routes | `config/routes.rb` |
| Schema | `db/schema.rb` |
