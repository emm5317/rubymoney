# Security

## Authentication

- **Devise** handles user authentication with bcrypt password hashing.
- All controllers require `authenticate_user!` via `ApplicationController`.
- Session-based auth with Rails' encrypted cookie store.
- Single-user app — registration is via `db:seed` or Rails console, not a public sign-up form.

## Authorization & Data Scoping

- All account queries scoped via `current_user.accounts`.
- Transaction queries always join through accounts: `Transaction.joins(:account).where(accounts: { user_id: current_user.id })`.
- RecurringTransaction queries join through accounts: `RecurringTransaction.joins(:account).where(accounts: { user_id: current_user.id })`.
- Categories, rules, tags, and budgets are global (single-user design).

## Rails Security Defaults

- **CSRF protection** enabled via `protect_from_forgery` (Rails default).
- **Strong parameters** on all controllers — no mass assignment vulnerabilities.
- **Parameter filtering** — `password`, `password_confirmation`, and `reset_password_token` are filtered from logs (see `config/initializers/filter_parameter_logging.rb`).
- **Content Security Policy** — configurable in `config/initializers/content_security_policy.rb`.

## Secrets Management

- Credentials stored in `config/credentials.yml.enc`, decrypted with `RAILS_MASTER_KEY`.
- In Docker, `RAILS_MASTER_KEY` is passed as an environment variable.
- `config/master.key` is in `.gitignore` — never committed.

## Transport

- **Production:** `config.force_ssl` controlled by `FORCE_SSL` env var. Enable when behind a TLS-terminating proxy.
- **Development:** HTTP on localhost. No TLS required for local dev.

## Data at Rest

- PostgreSQL with OS-level file permissions.
- Monetary values stored as integer cents — no precision loss.
- Imported file contents are not stored permanently — only parsed transaction data is persisted.

## Dependencies

- Gems are locked via `Gemfile.lock`.
- Docker image uses slim Ruby base with minimal attack surface.
- No Redis or external message brokers — all background processing via PostgreSQL-backed good_job.
