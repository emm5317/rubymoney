# Finance Reconciler

Personal finance app for importing bank statements, categorizing transactions, tracking budgets, detecting recurring charges, and visualizing spending. Built with Rails 7.2, PostgreSQL, and Hotwire.

## Features

- **Import pipeline** — CSV and OFX/QFX file import with smart preview, deduplication, and auto-categorization
- **Categorization** — Priority-ordered rules engine with regex/contains/amount matching, inline editing, bulk operations
- **Recurring detection** — Auto-detect subscriptions and bills, track missed charges, manual marking
- **Dashboard** — Category spending, monthly trends, budget progress, income vs. expenses, net worth, top merchants, recurring charges
- **Budgets** — Per-category monthly budgets with progress bars and copy-from-previous
- **Tags** — Flexible transaction tagging with bulk operations and spending views
- **Transfer detection** — Auto-link inter-account transfers, exclude from spending totals
- **Search & sort** — Text search on descriptions, sortable columns, full filter set
- **CSV export** — Export filtered transactions to CSV

## Requirements

- Docker & Docker Compose (recommended)
- Or: Ruby 3.3+, PostgreSQL 16+

## Quick Start (Docker)

```bash
git clone <repo-url> && cd rubymoney
docker compose up -d --build
docker compose exec web bin/rails db:migrate db:seed
```

App runs at **http://localhost:3030**. See [docs/docker.md](docs/docker.md) for details.

**Dev login:** admin@example.com / password123

## Testing

```bash
# Full test suite (uses separate test Docker image):
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test

# Run specific specs:
docker compose -f docker-compose.yml -f docker-compose.test.yml run --rm test \
  bash -c "bundle exec rspec spec/requests/"
```

## Stack

| Layer | Choice |
|-------|--------|
| Framework | Rails 7.2 |
| Database | PostgreSQL 16 |
| Frontend | Hotwire (Turbo + Stimulus) |
| Styling | Tailwind CSS |
| Auth | Devise |
| Background Jobs | good_job (PostgreSQL-backed, no Redis) |
| Charts | Chart.js via Stimulus |
| Pagination | Pagy |
| Testing | RSpec + FactoryBot |

## Project Documentation

| Doc | Purpose |
|-----|---------|
| **CLAUDE.md** | Architecture, conventions, coding guidelines — the primary reference |
| **BUILD_PLAN.md** | Phased implementation roadmap with data model and design decisions |
| **SOUL.md** | Design philosophy, decision rationale, quality standards |
| **app/views/CLAUDE.md** | Frontend design system (Tailwind patterns, components) |
| **docs/** | Focused guides: Docker, import pipeline, security, edge cases, env vars |

## License

Private — not for redistribution.
