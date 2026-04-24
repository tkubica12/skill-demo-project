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
    [string]$ApiUrl  = "",
    [string]$Status  = "waiting-for-response",
    [string]$Comment = "Benchmark ping"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

# Resolve API URL: explicit param → TASK_API_URL env → local mock fallback
if (-not $ApiUrl -and $Phase -ne "compare") {
    $ApiUrl = & (Join-Path $PSScriptRoot "Get-TaskApiUrl.ps1")
}

# ------------------------------------------------------------------
# Shared helpers
# ------------------------------------------------------------------

function Get-Python {
    $cmd = (Get-Command python -ErrorAction SilentlyContinue) `
         ?? (Get-Command python3 -ErrorAction SilentlyContinue)
    if (-not $cmd) { throw "Python not found. Install Python 3.9+ and add it to PATH." }
    return $cmd.Source
}

function Measure-Baseline {
    <#
    Times the painful per-task loop: one 'python task_cli.py add-comment' invocation
    per task. This is the real baseline cost – each call spawns a new Python process,
    pays connection overhead, and shuts down.
    #>
    param(
        [array]  $Tasks,
        [string] $ApiUrl,
        [string] $Comment,
        [string] $CliPath,
        [string] $PythonExe
    )
    $env:TASK_API_URL = $ApiUrl
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($task in $Tasks) {
        & $PythonExe $CliPath add-comment $task.id $Comment | Out-Null
    }
    $sw.Stop()
    return $sw.Elapsed.TotalSeconds
}

function Measure-BulkExperiment {
    <#
    Times the experimental bulk-add-comment: a single Python process invocation
    that resolves the task list and posts all comments in one session.
    Requires Apply-LocalExperiment.ps1 to have been run first.
    The experimental CLI uses --api-url (not --base-url).
    #>
    param(
        [string] $ApiUrl,
        [string] $Status,
        [string] $Comment,
        [string] $CliPath,
        [string] $PythonExe
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $PythonExe $CliPath bulk-add-comment --status $Status --comment $Comment --api-url $ApiUrl | Out-Null
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
    Write-Host "Timing baseline loop (one CLI process per task) ..."
    $pyExe   = Get-Python
    $cliPath = & (Join-Path $PSScriptRoot "Get-SkillCliPath.ps1")
    if (-not $cliPath) {
        Write-Error "Cannot locate installed skill CLI. Run Install-SharedSkill.ps1 first."
        exit 1
    }
    $elapsed = Measure-Baseline -Tasks $tasks -ApiUrl $ApiUrl -Comment $Comment `
                                -CliPath $cliPath -PythonExe $pyExe
} else {
    # Phase = after; experimental CLI must be active (Apply-LocalExperiment.ps1 run first)
    $cliPath = & (Join-Path $PSScriptRoot "Get-SkillCliPath.ps1")
    if (-not $cliPath) {
        Write-Error "Cannot locate skill CLI. Run Install-SharedSkill.ps1 then Apply-LocalExperiment.ps1."
        exit 1
    }
    $pyExe = Get-Python
    # Verify bulk-add-comment is available (i.e. experiment has been applied)
    $helpOutput = (& $pyExe $cliPath bulk-add-comment --help 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or ($helpOutput -notmatch "bulk-add-comment")) {
        Write-Error @"
bulk-add-comment not found in the installed CLI.
Apply the local experiment first:  .\scripts\Apply-LocalExperiment.ps1
"@
        exit 1
    }
    Write-Host "Timing bulk-add-comment (single invocation) ..."
    $elapsed = Measure-BulkExperiment -ApiUrl $ApiUrl -Status $Status -Comment $Comment `
                                       -CliPath $cliPath -PythonExe $pyExe
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
