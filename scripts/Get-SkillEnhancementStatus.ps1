<#
.SYNOPSIS
    Checks the status of all tracked skill enhancement requests against the
    central catalog and reports which ones have been resolved (closed).

.DESCRIPTION
    Reads skill-enhancement-tracker.json, queries GitHub for the current state
    of each tracked issue, and prints a summary. For closed issues it also
    scans catalog releases to identify which release likely contains the fix
    (by searching release notes for the issue number).
    Optionally updates the status field in the tracker file to reflect resolved items.

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

# Fetch catalog releases once (best-effort; skip if gh fails or repo has none)
$catalogReleases = @()
try {
    $tagList = gh release list --repo $CatalogRepo --json "tagName,publishedAt" --limit 50 2>&1
    if ($LASTEXITCODE -eq 0) {
        $tags = $tagList | ConvertFrom-Json
        foreach ($t in $tags) {
            $viewJson = gh release view $t.tagName --repo $CatalogRepo --json "tagName,name,body,publishedAt" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $catalogReleases += ($viewJson | ConvertFrom-Json)
            }
        }
    }
} catch {
    # Non-fatal: release scanning is best-effort
}

function Find-ReleaseForIssue {
    param([int]$IssueNumber, [array]$Releases)
    # Search release notes (body) and name for a reference to the issue number
    $patterns = @("#$IssueNumber", "/$IssueNumber")
    foreach ($rel in ($Releases | Sort-Object publishedAt)) {
        $haystack = "$($rel.name) $($rel.body)"
        foreach ($p in $patterns) {
            if ($haystack -match [regex]::Escape($p)) {
                return $rel
            }
        }
    }
    return $null
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

    $color = if ($state -eq "CLOSED") { "Green" } else { "Yellow" }
    Write-Host "`n  Issue #$($entry.issue_number): $($entry.title)" -ForegroundColor $color
    Write-Host "  State  : $state"
    Write-Host "  URL    : $($entry.issue_url)"

    if ($state -eq "CLOSED") {
        Write-Host "  Closed : $closedAt"

        # Try to identify which catalog release contains the fix
        $fixRelease = Find-ReleaseForIssue -IssueNumber $entry.issue_number -Releases $catalogReleases
        if ($fixRelease) {
            Write-Host "  Fixed in release: $($fixRelease.tagName) – $($fixRelease.name) (published $($fixRelease.publishedAt))" -ForegroundColor Green
        } else {
            Write-Host "  Fixed in release: not detected in release notes" -ForegroundColor DarkYellow
        }

        if ($UpdateFile -and $entry.status -ne "resolved") {
            $entry.status = "resolved"
            # Add-Member handles both new and existing NoteProperties safely
            $entry | Add-Member -NotePropertyName "closed_at"       -NotePropertyValue $closedAt          -Force
            if ($fixRelease) {
                $entry | Add-Member -NotePropertyName "fixed_in_release" -NotePropertyValue $fixRelease.tagName -Force
            }
            $anyChanges = $true
        }
    }
}

Write-Host ""

if ($UpdateFile -and $anyChanges) {
    $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerFile -Encoding UTF8
    Write-Host "Tracker file updated with resolved statuses." -ForegroundColor Green
    Write-Host "Run: git add skill-enhancement-tracker.json && git commit -m 'chore: update skill enhancement statuses' && git push"
}
