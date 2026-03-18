# Finance Reconciler

Personal finance app for importing bank statements, categorizing transactions, tracking budgets, and visualizing spending. Built with Rails 7.2, PostgreSQL, and Hotwire.

## Requirements

- Docker & Docker Compose (recommended)
- Or: Ruby 3.3+, PostgreSQL 16+

## Quick Start (Docker)

```bash
git clone <repo-url> && cd rubymoney
docker compose up -d --build
docker compose exec web bin/rails db:seed
```

App runs at **http://localhost:3030**. See [docs/docker.md](docs/docker.md) for details.

## Setup (Local)

```bash
git clone <repo-url> && cd rubymoney
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

## Development

```bash
bin/rails server          # Rails + good_job (inline in dev)
bundle exec rspec         # Run test suite
bin/rails db:seed         # Seed categories + dev user
```

**Dev login:** admin@example.com / password123

**Job dashboard:** http://localhost:3030/good_job

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
