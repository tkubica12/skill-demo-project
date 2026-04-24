<#
.SYNOPSIS
    Runs the painful baseline scenario: add a comment to every
    'waiting-for-response' task using one CLI call per task.

.DESCRIPTION
    This is the SLOW path that motivates the bulk-add-comment enhancement.
    Each iteration spawns a new process, which adds overhead proportional
    to the number of tasks.

.PARAMETER Comment
    The comment text to post on each task.
    Default: "Following up – please provide a status update."

.PARAMETER ApiUrl
    Base URL of the Task API.
    Default: http://localhost:8080

.PARAMETER Status
    Task status to target.
    Default: waiting-for-response

.EXAMPLE
    .\Invoke-BaselineScenario.ps1
    .\Invoke-BaselineScenario.ps1 -Comment "Ping – any update?"
#>
[CmdletBinding()]
param(
    [string]$Comment = "Following up – please provide a status update.",
    [string]$ApiUrl  = "",
    [string]$Status  = "waiting-for-response"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve API URL: explicit param → TASK_API_URL env → local mock fallback
if (-not $ApiUrl) {
    $ApiUrl = & (Join-Path $PSScriptRoot "Get-TaskApiUrl.ps1")
}

Write-Host "=== Baseline Scenario ===" -ForegroundColor Yellow
Write-Host "Fetching tasks with status '$Status' from $ApiUrl ..."

# Require the installed skill CLI
$cliPath = & (Join-Path $PSScriptRoot "Get-SkillCliPath.ps1")
if (-not $cliPath) { exit 1 }

# Resolve Python interpreter
$pythonCmd = (Get-Command python -ErrorAction SilentlyContinue) `
           ?? (Get-Command python3 -ErrorAction SilentlyContinue)
if (-not $pythonCmd) {
    Write-Error "Python not found. Install Python 3.9+ and ensure it is on PATH."
    exit 1
}

# Fetch task list via direct REST (CLI list-tasks is for Copilot use; the
# baseline loop itself exercises add-comment via the installed CLI)
try {
    $tasks = Invoke-RestMethod "$ApiUrl/tasks?status=$Status" -ErrorAction Stop
} catch {
    Write-Error "Cannot reach the API at $ApiUrl. Start it first: .\scripts\Start-MockApi.ps1"
    exit 1
}

if ($tasks.Count -eq 0) {
    Write-Host "No tasks with status '$Status'. Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($tasks.Count) task(s). Commenting on each via the installed CLI (baseline – one process per task)..." -ForegroundColor Cyan

$start = [System.Diagnostics.Stopwatch]::StartNew()

$env:TASK_API_URL = $ApiUrl
foreach ($task in $tasks) {
    Write-Host "  → python task_cli.py add-comment $($task.id) ..." -NoNewline
    & $pythonCmd.Source $cliPath add-comment $task.id $Comment 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host " FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
    } else {
        Write-Host " done" -ForegroundColor Green
    }
}

$start.Stop()
$elapsed = [Math]::Round($start.Elapsed.TotalSeconds, 3)

Write-Host ""
Write-Host "=== Baseline complete ===" -ForegroundColor Yellow
Write-Host "Tasks processed : $($tasks.Count)"
Write-Host "Elapsed         : ${elapsed}s"
Write-Host ""
Write-Host "Tip: compare this with the experiment (Apply-LocalExperiment.ps1 + bulk-add-comment)."
