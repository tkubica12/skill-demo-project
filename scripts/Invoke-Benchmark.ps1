<#
.SYNOPSIS
    Benchmarks the baseline loop vs. the bulk-add-comment experiment.

.DESCRIPTION
    Phase 'before': Times the per-task loop against all waiting-for-response tasks.
    Phase 'after' : Times the single bulk-add-comment call.
    Phase 'compare': Prints a side-by-side summary of both saved result files.

    Results are saved to benchmark-results-<phase>.json in the repo root.

.PARAMETER Phase
    'before', 'after', or 'compare'.

.PARAMETER ApiUrl
    Base URL of the Task API. Default: http://localhost:8080

.PARAMETER Status
    Task status to target. Default: waiting-for-response

.PARAMETER Comment
    Comment text used during timing. Default: "Benchmark ping"

.EXAMPLE
    .\Invoke-Benchmark.ps1 -Phase before
    .\Invoke-Benchmark.ps1 -Phase after
    .\Invoke-Benchmark.ps1 -Phase compare
#>
[CmdletBinding()]
param(
    [ValidateSet("before","after","compare")]
    [string]$Phase   = "before",
    [string]$ApiUrl  = "http://localhost:8080",
    [string]$Status  = "waiting-for-response",
    [string]$Comment = "Benchmark ping"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Measure-Baseline {
    param([array]$Tasks, [string]$ApiUrl, [string]$Comment)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($task in $Tasks) {
        $body = @{ text = $Comment } | ConvertTo-Json
        Invoke-RestMethod "$ApiUrl/tasks/$($task.id)/comments" `
            -Method POST -ContentType "application/json" -Body $body | Out-Null
    }
    $sw.Stop()
    return $sw.Elapsed.TotalSeconds
}

function Measure-BulkExperiment {
    param([array]$Tasks, [string]$ApiUrl, [string]$Comment, [string]$CliPath)
    $ids = $Tasks | ForEach-Object { $_.id }
    $sw  = [System.Diagnostics.Stopwatch]::StartNew()

    $pythonCmd = (Get-Command python -ErrorAction SilentlyContinue) `
               ?? (Get-Command python3 -ErrorAction SilentlyContinue)
    if (-not $pythonCmd) { throw "Python not found." }

    & $pythonCmd.Source $CliPath bulk-add-comment --ids @ids --comment $Comment --api-url $ApiUrl | Out-Null
    $sw.Stop()
    return $sw.Elapsed.TotalSeconds
}

if ($Phase -eq "compare") {
    $beforeFile = Join-Path $repoRoot "benchmark-results-before.json"
    $afterFile  = Join-Path $repoRoot "benchmark-results-after.json"
    if (-not (Test-Path $beforeFile) -or -not (Test-Path $afterFile)) {
        Write-Error "Run -Phase before and -Phase after first."
        exit 1
    }
    $before = Get-Content $beforeFile | ConvertFrom-Json
    $after  = Get-Content $afterFile  | ConvertFrom-Json
    $saving = [Math]::Round($before.elapsed_seconds - $after.elapsed_seconds, 3)
    $pct    = [Math]::Round(($saving / $before.elapsed_seconds) * 100, 1)

    Write-Host ""
    Write-Host "=== Benchmark Comparison ===" -ForegroundColor Cyan
    Write-Host ("Before (baseline loop) : {0,8}s  ({1} tasks)" -f $before.elapsed_seconds, $before.task_count)
    Write-Host ("After  (bulk-add-comment): {0,6}s  ({1} tasks)" -f $after.elapsed_seconds, $after.task_count)
    Write-Host ("Saved                  : {0,8}s  ({1}% faster)" -f $saving, $pct)
    Write-Host ""
    return
}

# Fetch tasks
try {
    $tasks = Invoke-RestMethod "$ApiUrl/tasks?status=$Status" -ErrorAction Stop
} catch {
    Write-Error "Cannot reach API at $ApiUrl. Start it: .\scripts\Start-MockApi.ps1"
    exit 1
}

Write-Host "=== Benchmark: Phase=$Phase, Tasks=$($tasks.Count) ===" -ForegroundColor Cyan

if ($Phase -eq "before") {
    Write-Host "Timing baseline loop (one CLI call per task) ..."
    $elapsed = Measure-Baseline -Tasks $tasks -ApiUrl $ApiUrl -Comment $Comment
} else {
    # Phase = after; experimental CLI must be active
    $cmd = Get-Command "task-api-helper" -ErrorAction SilentlyContinue
    $cliPath = if ($cmd) { $cmd.Source } else {
        Join-Path $repoRoot ".github\copilot\skills\task-api-helper\task_cli.py"
    }
    if (-not (Test-Path $cliPath)) {
        Write-Error "Experimental CLI not found at $cliPath. Run Apply-LocalExperiment.ps1 first."
        exit 1
    }
    Write-Host "Timing bulk-add-comment (single invocation) ..."
    $elapsed = Measure-BulkExperiment -Tasks $tasks -ApiUrl $ApiUrl -Comment $Comment -CliPath $cliPath
}

$result = [PSCustomObject]@{
    phase           = $Phase
    task_count      = $tasks.Count
    status_filter   = $Status
    elapsed_seconds = [Math]::Round($elapsed, 3)
    timestamp       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

$outFile = Join-Path $repoRoot "benchmark-results-${Phase}.json"
$result | ConvertTo-Json | Set-Content $outFile -Encoding UTF8

Write-Host "Elapsed: $($result.elapsed_seconds)s" -ForegroundColor Green
Write-Host "Results saved to: $outFile"
Write-Host ""
Write-Host "Next: run with -Phase $(if($Phase -eq 'before'){'after'}else{'compare'})"
