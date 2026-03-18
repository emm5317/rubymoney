# Docker Setup

## Architecture

Docker Compose runs two services:

| Service | Container | Port | Description |
|---------|-----------|------|-------------|
| `db` | rubymoney-db | 5437 → 5432 | PostgreSQL 16 (Alpine) |
| `web` | rubymoney-web | 3030 → 3030 | Rails app (production mode) |

## Quick Start

```bash
docker compose up -d --build
docker compose exec web bin/rails db:migrate db:seed
```

App is available at **http://localhost:3030**.

## Common Commands

```bash
# Start/stop
docker compose up -d
docker compose down

# Rebuild after Gemfile or Dockerfile changes
docker compose up -d --build

# View logs
docker compose logs -f web
docker compose logs -f db

# Rails console
docker compose exec web bin/rails console

# Run migrations
docker compose exec web bin/rails db:migrate

# Run tests (requires test db setup)
docker compose exec web bash -c "RAILS_ENV=test bin/rails db:prepare && bundle exec rspec"

# Database shell
docker compose exec db psql -U rubymoney rubymoney_development
```

## Port Assignments

- **3030** — Web app (mapped from container port 3030)
- **5437** — PostgreSQL (mapped from container port 5432, avoids conflict with local PostgreSQL on 5432)

## Master Key

The `RAILS_MASTER_KEY` environment variable is set in `docker-compose.yml`. This key decrypts `config/credentials.yml.enc`. For production deployments, pass it via a secrets manager instead of committing it.

## Data Persistence

PostgreSQL data is stored in the `rubymoney-pgdata` Docker volume. Data survives `docker compose down` but is removed by `docker compose down -v`.

## Connecting to Docker PostgreSQL from Host

```bash
psql -h localhost -p 5437 -U rubymoney rubymoney_development
```
