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
    [string]$ApiUrl  = "http://localhost:8080",
    [string]$Status  = "waiting-for-response"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Baseline Scenario ===" -ForegroundColor Yellow
Write-Host "Fetching tasks with status '$Status' from $ApiUrl ..."

# Fetch tasks via the API directly (the skill may or may not be installed)
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

Write-Host "Found $($tasks.Count) task(s). Commenting on each individually (baseline)..." -ForegroundColor Cyan

$start = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($task in $tasks) {
    Write-Host "  → add-comment $($task.id) ..." -NoNewline

    # Prefer the installed skill; fall back to direct API call
    $skillAvailable = Get-Command "task-api-helper" -ErrorAction SilentlyContinue
    if ($skillAvailable) {
        task-api-helper add-comment $task.id $Comment --api-url $ApiUrl 2>&1 | Out-Null
    } else {
        $body = @{ text = $Comment } | ConvertTo-Json
        Invoke-RestMethod "$ApiUrl/tasks/$($task.id)/comments" `
            -Method POST -ContentType "application/json" -Body $body | Out-Null
    }

    Write-Host " done" -ForegroundColor Green
}

$start.Stop()
$elapsed = [Math]::Round($start.Elapsed.TotalSeconds, 3)

Write-Host ""
Write-Host "=== Baseline complete ===" -ForegroundColor Yellow
Write-Host "Tasks processed : $($tasks.Count)"
Write-Host "Elapsed         : ${elapsed}s"
Write-Host ""
Write-Host "Tip: compare this with the experiment (Apply-LocalExperiment.ps1 + bulk-add-comment)."
