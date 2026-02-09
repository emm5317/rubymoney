# Build Plan - Quick View

This is the short, at-a-glance plan. See `docs/build-plan.md` for commands and details.

## Milestones

- Tooling and migrations verified
- Go service skeleton (done)
- DB wiring + repos (done)
- Core API endpoints (done)
- CSV connector MVP (parsing + mapping done)
- CSV sync persistence (done)
- Rules engine (done)
- Sync pipeline refinements (pending->posted done)
- Excel/VBA integration (done)
- WiX packaging (done)
- Acceptance tests (done)

## Current Focus

- Run tests and perform manual smoke checks.

## Next Three Steps

1. Run `go test ./...` in `C:\dev\budgetexcel\service`.
2. Smoke test Excel Sync flow.
3. Build MSI and install test.
