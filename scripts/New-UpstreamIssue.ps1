<#
.SYNOPSIS
    Files a detailed enhancement issue in the central catalog and records it
    in skill-improvement-log.json.

.DESCRIPTION
    Composes an issue body that includes:
      - Motivation and scenario description
      - Benchmark data (before/after elapsed times)
      - Link to the experimental implementation in this repo
      - Proposed API / UX for the new command
    Then creates the issue via 'gh issue create' and appends the result to
    skill-improvement-log.json.

.PARAMETER Title
    Issue title. Required.

.PARAMETER BenchmarkBefore
    Path to benchmark-results-before.json. Optional but recommended.

.PARAMETER BenchmarkAfter
    Path to benchmark-results-after.json. Optional but recommended.

.PARAMETER CatalogRepo
    Central catalog repo. Default: tkubica12/skills-demo-catalog

.PARAMETER SkillName
    Skill name. Default: task-api-helper

.EXAMPLE
    .\New-UpstreamIssue.ps1 `
        -Title "Add bulk-add-comment command to task-api-helper" `
        -BenchmarkBefore ..\benchmark-results-before.json `
        -BenchmarkAfter  ..\benchmark-results-after.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Title,

    [string]$BenchmarkBefore = "",
    [string]$BenchmarkAfter  = "",
    [string]$CatalogRepo     = "tkubica12/skills-demo-catalog",
    [string]$SkillName       = "task-api-helper"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot    = Split-Path -Parent $PSScriptRoot
$trackerFile = Join-Path $repoRoot "skill-improvement-log.json"

# ------------------------------------------------------------------
# Build benchmark section
# ------------------------------------------------------------------
$benchSection = ""
if ($BenchmarkBefore -and (Test-Path $BenchmarkBefore) -and
    $BenchmarkAfter  -and (Test-Path $BenchmarkAfter)) {
    $before = Get-Content $BenchmarkBefore | ConvertFrom-Json
    $after  = Get-Content $BenchmarkAfter  | ConvertFrom-Json
    $saving = [Math]::Round($before.elapsed_seconds - $after.elapsed_seconds, 3)
    $pct    = [Math]::Round(($saving / $before.elapsed_seconds) * 100, 1)
    $benchSection = @"

## Benchmark Results

Measured against $($before.task_count) tasks with status \`waiting-for-response\`.

| Approach | Elapsed (s) |
|---|---|
| Baseline (per-task loop) | $($before.elapsed_seconds) |
| Experiment (bulk-add-comment) | $($after.elapsed_seconds) |
| **Savings** | **${saving}s (${pct}% faster)** |

Benchmark run on $($before.timestamp).
"@
}

$cliRelPath = ".agents\skills\task-api-helper\scripts\task_cli.py"

# ------------------------------------------------------------------
# Compose issue body
# ------------------------------------------------------------------
$body = @"
## Summary

The \`$SkillName\` skill currently provides \`add-comment <id> --message <text>\`
which operates on a single task per invocation.

A common real-world need is: **post the same comment on every task in a given
status** (e.g., \`waiting-for-response\`).  The only current approach is a loop
that spawns a new Python process for every task:

\`\`\`powershell
# Invoke the installed skill CLI once per task (slow path)
\$cliPath = "$cliRelPath"
foreach (\$task in (Invoke-RestMethod "http://localhost:8080/tasks?status=waiting-for-response")) {
    python "\$cliPath" add-comment \$task.id --message "Following up."
}
\`\`\`

Each iteration carries the full process-startup and connection overhead.

## Proposed Enhancement

Add a \`bulk-add-comment\` sub-command:

\`\`\`
python task_cli.py bulk-add-comment (--ids <id>... | --status <status>) --message <text>
\`\`\`

This opens a single process, resolves the task list once, and posts all
comments in a single session – dramatically reducing latency.
$benchSection
## Experimental Implementation

A proof-of-concept CLI (fully backward-compatible) is available in the
requesting project:

[tkubica12/skill-demo-project – experiments/bulk_add_comment/task_cli_experimental.py](https://github.com/tkubica12/skill-demo-project/blob/main/experiments/bulk_add_comment/task_cli_experimental.py)

The experimental file adds \`bulk-add-comment\` while preserving all existing
commands.

## Requesting Project

**Repository:** tkubica12/skill-demo-project
**Skill installed:** \`$SkillName\` from \`$CatalogRepo\`
**Skill CLI path (post-install):** \`$cliRelPath\`
"@

# ------------------------------------------------------------------
# Create the issue
# ------------------------------------------------------------------
Write-Host "Creating issue in '$CatalogRepo' ..." -ForegroundColor Cyan

$issueUrl = gh issue create `
    --repo  $CatalogRepo `
    --title $Title `
    --body  $body `
    --label "skill-enhancement" `
    --label "needs-triage" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create issue: $issueUrl"
    exit $LASTEXITCODE
}

$issueNumber = ($issueUrl.Trim() -split "/")[-1]
Write-Host "Issue created: $issueUrl" -ForegroundColor Green

# ------------------------------------------------------------------
# Update tracker
# ------------------------------------------------------------------
$tracker = Get-Content $trackerFile -Raw | ConvertFrom-Json

$entry = [PSCustomObject]@{
    issue_number   = [int]$issueNumber
    issue_url      = $issueUrl.Trim()
    title          = $Title
    skill          = $SkillName
    catalog_repo   = $CatalogRepo
    enhancement    = "bulk-add-comment"
    created_at     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    status         = "open"
}

$tracker.requests += $entry
$tracker | ConvertTo-Json -Depth 10 | Set-Content $trackerFile -Encoding UTF8

Write-Host "Recorded in $trackerFile (issue #$issueNumber)." -ForegroundColor Green
Write-Host ""
Write-Host "Commit and push the tracker:"
Write-Host "  git add skill-improvement-log.json"
Write-Host "  git commit -m `"track: upstream issue #$issueNumber – $Title`""
Write-Host "  git push"
