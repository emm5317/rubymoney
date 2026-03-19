# Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | (none) | Full PostgreSQL connection URL. Overrides `database.yml` settings when set. |
| `RAILS_ENV` | `development` | Rails environment: `development`, `test`, or `production`. |
| `RAILS_MASTER_KEY` | (none) | Decryption key for `config/credentials.yml.enc`. Required in production. Alternatively, place in `config/master.key`. |
| `RAILS_SERVE_STATIC_FILES` | `false` | Set to `true` in Docker/production to serve assets from Rails (no Nginx). |
| `RAILS_LOG_TO_STDOUT` | `false` | Set to `true` to log to stdout (useful for Docker). |
| `RAILS_LOG_LEVEL` | `info` (prod) | Log level: `debug`, `info`, `warn`, `error`, `fatal`. |
| `RAILS_MAX_THREADS` | `5` | Database connection pool size and Puma thread count. |
| `PORT` | `3000` | Port for the Rails server. Docker Compose sets this to `3030`. |
| `FORCE_SSL` | `false` | Set to `true` to enable HTTPS redirect and secure cookies in production. |
| `RUBYMONEY_DATABASE_PASSWORD` | (none) | PostgreSQL password for production (used in `database.yml`). Not needed if `DATABASE_URL` is set. |

**Note:** No Redis is used anywhere. good_job uses PostgreSQL for background jobs. Action Cable uses the async adapter in development.

## Docker Compose Defaults

The `docker-compose.yml` sets these for the `web` service:

```yaml
RAILS_ENV: production
DATABASE_URL: postgres://rubymoney:rubymoney@db:5432/rubymoney_development
RAILS_MASTER_KEY: <from master.key>
RAILS_SERVE_STATIC_FILES: "true"
RAILS_LOG_TO_STDOUT: "true"
PORT: "3030"
```
