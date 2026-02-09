param(
    [string]$CsvPath = "$env:USERPROFILE\Downloads\BudgetImports\test-checking.csv"
)

$folder = Split-Path $CsvPath
New-Item -ItemType Directory -Force -Path $folder | Out-Null

$content = @"
Date,Amount,Payee,Memo
2026-01-01,-45.67,Starbucks,Coffee
2026-01-03,-120.00,Whole Foods,Grocery
2026-01-05,2500.00,Employer,Salary
2026-01-10,-60.25,Shell,Gas
2026-01-15,-15.00,Spotify,Subscription
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($CsvPath, $content, $utf8NoBom)

Write-Host "Created test CSV at $CsvPath"
