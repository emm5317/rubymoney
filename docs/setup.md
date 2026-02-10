# Setup

## Prerequisites

- Windows 10 or 11.
- Microsoft Excel (desktop) with macro support.
- Go toolchain installed.
- WiX Toolset installed for MSI builds.
- MinGW installed for CGO builds (SQLite migration tooling).
- llama.cpp CLI installed for local LLM suggestions (optional).

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
- Config (preferred): `%LOCALAPPDATA%\BudgetApp\config\csv_mappings\`
- Config (legacy): `%LOCALAPPDATA%\BudgetApp\config\csv_mappings.json`
- Secrets: `%LOCALAPPDATA%\BudgetApp\secrets\`
- CSV import folder: `%USERPROFILE%\Downloads\BudgetImports`

## Local LLM Suggestions (Optional)

BudgetExcel uses the `llama.cpp` CLI for local category suggestions. The service does not bundle the runtime or model.

### Install llama.cpp CLI (Windows)

1. Download a prebuilt `llama.cpp` release for Windows.
2. Extract it and add the folder containing `llama-cli.exe` to your `PATH`.

### Provide a GGUF Model

Download or place a quantized GGUF model locally (for example, `C:\Models\budget.gguf`).

### Required Environment Variables

Set these before starting `budgetd`:

- `LLM_ENABLED=true`
- `LLM_RUNTIME=llama_cpp`
- `LLM_MODEL_PATH=C:\Models\budget.gguf`

### Optional Environment Variables

- `LLM_TIMEOUT_MS=2000`
- `LLM_MAX_CONCURRENCY=1`
- `LLM_TEMPERATURE=0.0`
- `LLM_CACHE_TTL_HOURS=720`
- `LLM_MIN_CONFIDENCE=0.70`
- `LLM_SYNC_MAX=20`
- `LLM_RETRY_MAX=2`
- `LLM_POLL_INTERVAL_MS=1500`

### PowerShell Example

```powershell
$env:LLM_ENABLED = "true"
$env:LLM_RUNTIME = "llama_cpp"
$env:LLM_MODEL_PATH = "C:\Models\budget.gguf"
$env:PATH = "$env:PATH;C:\Tools\llama.cpp"
```

Restart `budgetd` after setting environment variables.

## CSV Mapping Templates

Per-bank template mappings live in `config/csv_mappings/`. Copy the needed files to:

`%LOCALAPPDATA%\BudgetApp\config\csv_mappings\`

## Configuration in Excel

- Edit `Config` sheet `settings` table:
- `service_url` default `http://127.0.0.1:8787`
- `db_path` default `%LOCALAPPDATA%\BudgetApp\data\budget.sqlite`
- `sync_since_days` default `180`
- `csv_import_folder` default `%USERPROFILE%\Downloads\BudgetImports`
- `amount_convention` `expenses_negative` or `expenses_positive`
- Optional (reference only, not consumed automatically):
- `llm_enabled` set `true` or `false`
- `llm_model_path` full path to GGUF model
- `llm_runtime` default `llama_cpp`
- `llm_timeout_ms` default `2000`
- `llm_max_concurrency` default `1`
- `llm_temperature` default `0.0`
- `llm_cache_ttl_hours` default `720`
- `llm_min_confidence` default `0.70`

## Service Bindings

- Service binds to `127.0.0.1` only.
- No remote listeners or exposure.
