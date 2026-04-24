<#
.SYNOPSIS
    Starts the mock Task REST API as a background job.

.DESCRIPTION
    Launches api/server.py in the background using Python.
    The API listens on http://localhost:8080 by default.

.PARAMETER Port
    TCP port for the API. Default: 8080

.PARAMETER Host
    Bind address. Default: 127.0.0.1

.PARAMETER Foreground
    If set, runs the server in the foreground (blocking).

.EXAMPLE
    .\Start-MockApi.ps1
    .\Start-MockApi.ps1 -Port 9090
    .\Start-MockApi.ps1 -Foreground
#>
[CmdletBinding()]
param(
    [int]   $Port       = 8080,
    [string]$ApiHost    = "127.0.0.1",
    [switch]$Foreground
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot  = Split-Path -Parent $PSScriptRoot
$serverPy  = Join-Path $repoRoot "api\server.py"

if (-not (Test-Path $serverPy)) {
    Write-Error "Cannot find api\server.py at $serverPy"
    exit 1
}

$pythonCmd = (Get-Command python -ErrorAction SilentlyContinue) `
           ?? (Get-Command python3 -ErrorAction SilentlyContinue)
if (-not $pythonCmd) {
    Write-Error "Python not found. Install Python 3.9+ and ensure it is on PATH."
    exit 1
}

$args = @($serverPy, "--port", $Port, "--host", $ApiHost)

if ($Foreground) {
    Write-Host "Starting Mock Task API on http://$ApiHost:$Port (foreground) ..." -ForegroundColor Cyan
    & $pythonCmd.Source @args
} else {
    Write-Host "Starting Mock Task API on http://$ApiHost:$Port (background job) ..." -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock {
        param($py, $sArgs)
        & $py @sArgs
    } -ArgumentList $pythonCmd.Source, $args

    # Wait briefly and check the API is responsive
    Start-Sleep -Seconds 2
    try {
        $resp = Invoke-RestMethod "http://$ApiHost:$Port/health" -ErrorAction Stop
        Write-Host "API is up: $($resp | ConvertTo-Json -Compress)" -ForegroundColor Green
    } catch {
        Write-Warning "API did not respond within 2 s. Check job output:"
        Receive-Job $job
    }

    Write-Host "Background job ID: $($job.Id)"
    Write-Host "Stop with: Stop-Job $($job.Id) ; Remove-Job $($job.Id)"
    return $job
}
