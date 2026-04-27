# run_web.ps1 - starts Flutter web on a stable OAuth origin
# Usage:
#   .\scripts\run_web.ps1
#   .\scripts\run_web.ps1 -Port 7358
param(
    [int]$Port = 7357,
    [string]$Hostname = "localhost"
)

Set-Location $PSScriptRoot\..

$origin = "http://${Hostname}:$Port"
Write-Host "Starting Kviz DBase web on $origin" -ForegroundColor Cyan
Write-Host "Google Cloud OAuth Authorized JavaScript origins must include: $origin" -ForegroundColor Yellow

flutter run -d chrome --web-hostname $Hostname --web-port $Port
