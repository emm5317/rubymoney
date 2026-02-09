# Build Plan (Windows / PowerShell)

This plan matches the required repo layout and uses Windows-native tooling.

## Prereqs (one-time)

```powershell
go version
git --version
```

Install WiX:

```powershell
choco install -y wixtoolset
$env:Path += ";C:\Program Files (x86)\WiX Toolset v3.14\bin"
```

Install MinGW (for CGO):

```powershell
choco install -y mingw
```

Install golang-migrate (SQLite, CGO-enabled):

```powershell
$env:Path += ";C:\ProgramData\mingw64\mingw64\bin;$env:GOPATH\bin"
$env:CGO_ENABLED = "1"
$env:CC = "gcc"

go install -tags "sqlite3" "github.com/golang-migrate/migrate/v4/cmd/migrate@latest"
```

Verify tools:

```powershell
candle -?
light -?
migrate -version
```

## Repo Skeleton

```powershell
mkdir -Force budgetexcel\service\cmd\budgetd
mkdir -Force budgetexcel\service\internal\api
mkdir -Force budgetexcel\service\internal\db
mkdir -Force budgetexcel\service\internal\models
mkdir -Force budgetexcel\service\internal\rules
mkdir -Force budgetexcel\service\internal\connectors\csv
mkdir -Force budgetexcel\service\internal\connectors\ofx
mkdir -Force budgetexcel\service\internal\secrets
mkdir -Force budgetexcel\service\internal\sync
mkdir -Force budgetexcel\service\internal\logging
mkdir -Force budgetexcel\service\migrations
```

## Create Service Module

```powershell
cd budgetexcel\service

go mod init budgetexcel/service

go get github.com/gofiber/fiber/v2
go get github.com/gofiber/fiber/v2/middleware/logger
go get github.com/gofiber/fiber/v2/middleware/recover
go get github.com/mattn/go-sqlite3
go get github.com/golang-migrate/migrate/v4
go get github.com/golang-migrate/migrate/v4/database/sqlite3
go get github.com/golang-migrate/migrate/v4/source/file
go get github.com/google/uuid
```

## Migrations (create + run)

Create:

- `service/migrations/0001_init.up.sql`
- `service/migrations/0001_init.down.sql`

Run:

```powershell
migrate -path "C:/dev/budgetexcel/service/migrations" -database "sqlite3://C:/Users/Admin/AppData/Local/BudgetApp/data/budget.sqlite" up
```

## Run Service (later)

```powershell
cd C:\dev\budgetexcel\service
go run .\cmd\budgetd
```

## Build MSI (later)

```powershell
# to be added in installer/build.ps1
```
