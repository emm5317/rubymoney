$url = 'http://127.0.0.1:8787/v1/health'

try {
  Invoke-RestMethod -Uri $url -UseBasicParsing | ConvertTo-Json -Depth 4
} catch {
  Write-Error "Health check failed: $($_.Exception.Message)"
}
