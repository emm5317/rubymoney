# Setup

## Prerequisites

- Windows 10 or 11.
- Microsoft Excel (desktop) with macro support.
- Go toolchain installed.
- WiX Toolset installed for MSI builds.
- MinGW installed for CGO builds (SQLite migration tooling).

## Verified Tooling (Windows)

- Go: `go version`
- Git: `git --version`
- WiX v3.14: `candle -?`, `light -?`
- Migrate CLI: `migrate -version`

## Install Commands (PowerShell)

### WiX Toolset (v3.14)

```powershell
choco install -y wixtoolset
```

Ensure WiX bin is on PATH:

```powershell
$env:Path += ";C:\Program Files (x86)\WiX Toolset v3.14\bin"
```

### MinGW (for CGO builds)

```powershell
choco install -y mingw
```

### golang-migrate (SQLite)

```powershell
$env:Path += ";C:\ProgramData\mingw64\mingw64\bin;$env:GOPATH\bin"
$env:CGO_ENABLED = "1"
$env:CC = "gcc"

go install -tags "sqlite3" "github.com/golang-migrate/migrate/v4/cmd/migrate@latest"
```

Verify:

```powershell
migrate -version
```

## Default Paths

- App data: `%LOCALAPPDATA%\BudgetApp\`
- Database: `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`
- Config: `%LOCALAPPDATA%\BudgetApp\config\csv_mappings.json`
- Secrets: `%LOCALAPPDATA%\BudgetApp\secrets\`
- CSV import folder: `%USERPROFILE%\Downloads\BudgetImports`

## Configuration in Excel

- Edit `Config` sheet `settings` table:
- `service_url` default `http://127.0.0.1:8787`
- `db_path` default `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`
- `sync_since_days` default `180`
- `csv_import_folder` default `%USERPROFILE%\Downloads\BudgetImports`
- `amount_convention` `expenses_negative` or `expenses_positive`

## Service Bindings

- Service binds to `127.0.0.1` only.
- No remote listeners or exposure.
