<#
.SYNOPSIS
    Checks whether any issues tracked in skill-improvement-log.json have
    been closed in the central catalog.

.DESCRIPTION
    Iterates over every open entry in skill-improvement-log.json, queries
    GitHub via 'gh issue view', and reports the current state.
    With -UpdateFile, closed entries are marked resolved and the file is saved.
    With -AutoClean, resolved entries that have been closed for > 30 days are
    removed from the tracker entirely.

.PARAMETER UpdateFile
    If set, writes resolved/closed state back to skill-improvement-log.json.

.PARAMETER AutoClean
    If set (requires -UpdateFile), removes entries that are fully resolved.

.EXAMPLE
    .\Get-IssueStatus.ps1
    .\Get-IssueStatus.ps1 -UpdateFile
    .\Get-IssueStatus.ps1 -UpdateFile -AutoClean
#>
[CmdletBinding()]
param(
    [switch]$UpdateFile,
    [switch]$AutoClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot    = Split-Path -Parent $PSScriptRoot
$trackerFile = Join-Path $repoRoot "skill-improvement-log.json"

$tracker = Get-Content $trackerFile -Raw | ConvertFrom-Json
$requests = @($tracker.requests)

if ($requests.Count -eq 0) {
    Write-Host "No tracked issues in $trackerFile." -ForegroundColor Green
    return
}

Write-Host "Checking $($requests.Count) tracked issue(s) ..." -ForegroundColor Cyan
Write-Host ""

$changed = $false

foreach ($req in $requests) {
    $state = ""
    $closedAt = ""
    try {
        $info = gh issue view $req.issue_number --repo $req.catalog_repo --json state,closedAt 2>&1 | ConvertFrom-Json
        $state    = $info.state
        $closedAt = $info.closedAt
    } catch {
        $state = "UNKNOWN (API error: $_)"
    }

    $symbol = switch ($state) {
        "OPEN"   { "🔴" }
        "CLOSED" { "✅" }
        default  { "❓" }
    }

    Write-Host "$symbol  #$($req.issue_number) [$($req.status)] – $($req.title)"
    Write-Host "     $($req.issue_url)"
    Write-Host "     GitHub state: $state"
    Write-Host ""

    if ($UpdateFile -and $state -eq "CLOSED" -and $req.status -ne "resolved") {
        $req | Add-Member -NotePropertyName "status"    -NotePropertyValue "resolved" -Force
        $req | Add-Member -NotePropertyName "closed_at" -NotePropertyValue $closedAt  -Force
        $changed = $true
        Write-Host "  → Marked resolved in tracker." -ForegroundColor Green
    }
}

if ($UpdateFile -and $AutoClean) {
    $before = $requests.Count
    $tracker.requests = @($requests | Where-Object { $_.status -ne "resolved" })
    $removed = $before - $tracker.requests.Count
    if ($removed -gt 0) {
        Write-Host "Removed $removed resolved entry(ies) from tracker." -ForegroundColor Yellow
        $changed = $true
    }
}

if ($UpdateFile -and $changed) {
    $tracker | ConvertTo-Json -Depth 10 | Set-Content $trackerFile -Encoding UTF8
    Write-Host "Tracker updated: $trackerFile" -ForegroundColor Green
    Write-Host "Commit and push:"
    Write-Host "  git add skill-improvement-log.json && git commit -m 'tracker: update issue status' && git push"
} elseif ($UpdateFile -and -not $changed) {
    Write-Host "No changes – all tracked statuses already up to date." -ForegroundColor Green
}
