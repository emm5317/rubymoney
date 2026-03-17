# Finance Reconciler — SOUL.md

This document captures the *why* behind decisions. Consult it when making architectural choices to stay consistent with the project's intent.

## Core Philosophy

**This is a personal finance tool, not a SaaS product.** Every decision optimizes for a single user who wants to understand their money — not for scale, not for team collaboration, not for monetization. Simplicity and reliability beat features.

**The user already has the data.** Bank statements exist as files. This app's job is to ingest them faithfully, categorize them intelligently, and surface patterns clearly. It is not a data entry app — manual transactions exist as a fallback, not the primary workflow.

**Rails does the heavy lifting.** We chose Rails because it's boring, productive, and well-understood. We don't fight the framework. Convention over configuration is the default. When Rails has an opinion, we follow it unless there's a concrete reason not to.

## Design Decisions and Their Rationale

### Why integer cents instead of decimals?

Floating-point arithmetic introduces rounding errors that compound across thousands of transactions. `$10.10 + $10.20` can produce `$20.299999...` in float math. Integer cents (`1010 + 1020 = 2030`) are exact. PostgreSQL `decimal` would also work, but integer cents are simpler to reason about, faster to index, and impossible to accidentally divide into sub-cent precision. The `amount`/`balance` virtual accessors handle conversion at the boundary.

### Why good_job instead of Sidekiq?

Sidekiq requires Redis — a separate process to install, configure, monitor, and back up. good_job uses PostgreSQL, which we already have. For a single-user app that processes statement imports, PostgreSQL's job queue is more than sufficient. One fewer dependency means one fewer thing that can fail at 2 AM.

### Why Hotwire instead of React/Vue?

This app is a series of forms and tables. Turbo Frames handle partial page updates (categorize a transaction without full reload). Stimulus handles the few interactive bits (chart rendering, form enhancements). There's no complex client-side state, no real-time collaboration, no offline mode. A JavaScript SPA would add a build pipeline, API serialization, state management, and testing complexity — all for no user-facing benefit.

### Why the adapter pattern for imports?

Bank statements come in wildly different formats. Chase CSVs look nothing like Schwab OFX files. The adapter pattern isolates format-specific parsing behind a common interface: every adapter takes raw file data and produces an array of canonical transaction hashes. Adding a new bank format means writing one new adapter class — no changes to the import controller, preview UI, or deduplication logic.

### Why ImportProfile learning?

Every bank formats CSVs differently. Column order, date format, description conventions — they vary. Rather than forcing the user to configure a parser for each bank, the import preview step lets them correct mistakes, and those corrections are saved to an ImportProfile. Next import from the same account auto-applies the learned mappings. The app gets smarter without explicit configuration.

### Why SHA256 fingerprints for deduplication?

Users will re-import overlapping date ranges. Without deduplication, they'd get duplicate transactions. Hashing key fields (date, amount, description) into a fingerprint and enforcing a unique index per account prevents this silently. OFX/QFX files include a FITID (Financial Transaction ID) which serves the same purpose natively.

### Why transfer detection?

A $500 transfer from checking to savings appears as a -$500 debit AND a +$500 credit. Without transfer awareness, dashboards show $500 of "income" and $500 of "expense" — both phantom. Linking transfer pairs and excluding them from spending/income totals gives accurate financial summaries.

### Why per-month budgets in a separate table?

Originally budgets were a column on categories. But users want different budget amounts month to month (holiday spending in December, travel budgets in summer). A dedicated `budgets` table with `[category_id, month, year]` allows per-month flexibility while keeping categories clean. It also enables "copy last month's budget" as a simple query.

### Why Tailwind instead of custom CSS?

Utility-first CSS eliminates naming bikeshedding, prevents specificity wars, and keeps styles colocated with markup. For a solo developer building a tool for personal use, Tailwind's trade-off (verbose HTML, minimal CSS files) is ideal. The app will never need a "design system" — it needs consistent, readable UI that's fast to build.

### Why Devise for a single-user app?

Even a single-user app needs authentication (it runs on a server). Devise provides battle-tested auth with zero custom security code. It handles password hashing, session management, CSRF protection, and remember-me tokens. Writing custom auth for "simplicity" is a false economy — the simplest auth is the one someone else debugged.

### Why no multi-tenancy?

The app is designed for one person. Adding user scoping to categories, rules, and tags adds complexity to every query for no benefit. Accounts and transactions are user-scoped because a future second user is plausible. Categories and rules are global because they represent a single user's financial taxonomy. If multi-user becomes a requirement, it's a known migration — add `user_id` to the global models and scope their queries.

## Quality Standards

### What "done" means for a feature
1. The happy path works end-to-end
2. Edge cases are handled (empty states, nil values, zero amounts)
3. Model validations prevent bad data from reaching the database
4. The UI is usable without reading documentation
5. At minimum, model specs cover validations, scopes, and key methods
6. Controller and system specs cover primary user flows

### What "done" does NOT mean
- 100% code coverage
- Pixel-perfect design
- Performance optimization (premature optimization is the root of all evil in a single-user app)
- Internationalization (English only, USD primary)

## Patterns to Follow

### Adding a new model
1. Generate migration with integer cents for any money column
2. Add model with validations, associations, scopes
3. Add factory in `spec/factories/`
4. Add model spec in `spec/models/`
5. If user-facing: add controller, views, routes
6. Update CLAUDE.md file map

### Adding a new import adapter
1. Create `app/services/importers/<format>_adapter.rb`
2. Inherit from `BaseAdapter`
3. Implement `#parse` returning array of transaction hashes
4. Add format to Import `file_type` enum if needed
5. Add spec in `spec/services/importers/`

### Adding a new dashboard widget
1. Create Stimulus controller in `app/javascript/controllers/`
2. Render Chart.js canvas in view with `data-controller` attribute
3. Pass data via `data-*` attributes or inline JSON
4. Never use Chartkick — Chart.js via Stimulus only

## Anti-Patterns to Avoid

- **God services.** Keep services focused. `Categorizer` categorizes. `TransferMatcher` matches transfers. Don't combine them.
- **N+1 queries.** Always use `.includes()` when iterating associations in views. Move complex queries to controllers.
- **Fat controllers.** If a controller action exceeds ~15 lines of business logic, extract a service object.
- **Magic strings.** Use enums for status fields. Use constants for configuration values.
- **Premature abstraction.** Three similar lines of code is fine. Don't create a helper for something used once.
- **View-layer queries.** Never call `Model.all` or `Model.where(...)` in views. Set instance variables in controllers.
