# Finance Reconciler

Personal finance app for importing bank statements, categorizing transactions, tracking budgets, and visualizing spending. Built with Rails 7.2, PostgreSQL, and Hotwire.

## Requirements

- Ruby 3.3+
- PostgreSQL 16+
- Node.js (for Tailwind CSS builds)

## Setup

```bash
# Clone and install dependencies
git clone <repo-url> && cd budgetexcel
bundle install

# Create and seed database
bin/rails db:create db:migrate db:seed

# Start the dev server
bin/dev
# Or without Procfile: bin/rails server
```

## Development

```bash
bin/rails server          # Rails + good_job (inline in dev)
bundle exec rspec         # Run test suite
bin/rails db:seed         # Seed categories + dev user
```

**Dev login:** admin@example.com / password123

**Job dashboard:** http://localhost:3000/good_job

## Stack

| Layer | Choice |
|-------|--------|
| Framework | Rails 7.2 |
| Database | PostgreSQL 16 |
| Frontend | Hotwire (Turbo + Stimulus) |
| Styling | Tailwind CSS |
| Auth | Devise |
| Background Jobs | good_job (PostgreSQL-backed) |
| Charts | Chart.js via Stimulus |
| Pagination | Pagy |
| Testing | RSpec + FactoryBot |

## Project Documentation

- **CLAUDE.md** — Architecture, conventions, and coding guidelines for AI-assisted development
- **SOUL.md** — Design philosophy, decision rationale, and quality standards
- **BUILD_PLAN.md** — Detailed phased implementation roadmap

## License

Private — not for redistribution.
