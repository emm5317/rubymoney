param(
    [string]$Configuration = "Release"
)

$root = Split-Path -Parent $PSScriptRoot
$serviceDir = Join-Path $root "service"
$wixDir = Join-Path $PSScriptRoot "wix"
$binDir = Join-Path $wixDir "bin"
$objDir = Join-Path $wixDir "obj"
$outDir = Join-Path $wixDir "output"

New-Item -ItemType Directory -Force -Path $binDir | Out-Null
New-Item -ItemType Directory -Force -Path $objDir | Out-Null
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Building budgetd.exe..."
Push-Location $serviceDir
& go build -o (Join-Path $binDir "budgetd.exe") (Join-Path $serviceDir "cmd\budgetd")
Pop-Location

$wxs = Join-Path $wixDir "BudgetApp.wxs"
$wixobj = Join-Path $objDir "BudgetApp.wixobj"
$msi = Join-Path $outDir "BudgetApp.msi"

Write-Host "Building MSI..."
Push-Location $wixDir
& candle.exe -nologo -out $wixobj $wxs
if ($LASTEXITCODE -ne 0) { throw "candle.exe failed" }
& light.exe -nologo -out $msi $wixobj
if ($LASTEXITCODE -ne 0) { throw "light.exe failed" }
Pop-Location

Write-Host "MSI created at: $msi"
