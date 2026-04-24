<#
.SYNOPSIS
    Checks the status of all tracked skill enhancement requests against the
    central catalog and reports which ones have been resolved (closed).

.DESCRIPTION
    Reads skill-enhancement-tracker.json, queries GitHub for the current status
    of each tracked issue, and prints a summary. Optionally updates the status
    field in the tracker file to reflect resolved items.

.PARAMETER CatalogRepo
    Central catalog repository. Default: tkubica12/skills-demo-catalog

.PARAMETER TrackerFile
    Path to the JSON tracker file. Default: skill-enhancement-tracker.json in repo root.

.PARAMETER UpdateFile
    If specified, writes resolved statuses back to the tracker file.

.EXAMPLE
    .\Get-SkillEnhancementStatus.ps1
    .\Get-SkillEnhancementStatus.ps1 -UpdateFile

#>
[CmdletBinding()]
param(
    [string]$CatalogRepo = "tkubica12/skills-demo-catalog",
    [string]$TrackerFile = "",
    [switch]$UpdateFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TrackerFile) {
    $TrackerFile = Join-Path $repoRoot "skill-enhancement-tracker.json"
}

$tracker = Get-Content $TrackerFile -Raw | ConvertFrom-Json

if ($tracker.enhancements.Count -eq 0) {
    Write-Host "No skill enhancement requests are currently tracked." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nSkill Enhancement Request Status" -ForegroundColor Cyan
Write-Host ("=" * 60)

$anyChanges = $false

foreach ($entry in $tracker.enhancements) {
    $issueData = gh issue view $entry.issue_number `
        --repo $entry.catalog_repo `
        --json "state,title,closedAt,url" 2>&1 | ConvertFrom-Json

    $state    = $issueData.state      # OPEN or CLOSED
    $closedAt = $issueData.closedAt

    $statusDisplay = if ($state -eq "CLOSED") {
        "RESOLVED (closed $closedAt)"
    } else {
        "OPEN"
    }

    $color = if ($state -eq "CLOSED") { "Green" } else { "Yellow" }
    Write-Host "`n  Issue #$($entry.issue_number): $($entry.title)" -ForegroundColor $color
    Write-Host "  Status : $statusDisplay"
    Write-Host "  URL    : $($entry.issue_url)"

    if ($UpdateFile -and $state -eq "CLOSED" -and $entry.status -ne "resolved") {
        $entry.status    = "resolved"
        $entry.closed_at = $closedAt
        $anyChanges      = $true
    }
}

Write-Host ""

if ($UpdateFile -and $anyChanges) {
    $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerFile -Encoding UTF8
    Write-Host "Tracker file updated with resolved statuses." -ForegroundColor Green
    Write-Host "Run: git add skill-enhancement-tracker.json && git commit -m 'chore: update skill enhancement statuses' && git push"
}
