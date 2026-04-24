<#
.SYNOPSIS
    Creates an enhancement request issue in the central skill catalog and records
    the issue link in this project's tracker file.

.DESCRIPTION
    When a Copilot agent (or a developer) identifies a gap in the shared
    'release-readiness-check' skill, they call this script to:
      1. Open a GitHub issue in the central catalog repo.
      2. Append the issue number, URL, title, and date to skill-enhancement-tracker.json
         so every future Copilot session and every teammate can see what was requested.

.PARAMETER Title
    The issue title (required).

.PARAMETER Body
    The issue body / description. Markdown is supported.

.PARAMETER CatalogRepo
    Central catalog repository in 'owner/repo' format.
    Default: tkubica12/skills-demo-catalog

.PARAMETER SkillName
    Name of the skill the enhancement targets.
    Default: release-readiness-check

.PARAMETER TrackerFile
    Path to the JSON tracker file relative to this script's parent directory.
    Default: skill-enhancement-tracker.json in the repo root.

.EXAMPLE
    .\New-SkillEnhancement.ps1 `
        -Title "Add LICENSE file check to release-readiness-check" `
        -Body  "Currently the skill does not verify that a LICENSE file is present..."

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Title,

    [string]$Body        = "",
    [string]$CatalogRepo = "tkubica12/skills-demo-catalog",
    [string]$SkillName   = "release-readiness-check",
    [string]$TrackerFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve tracker file path
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TrackerFile) {
    $TrackerFile = Join-Path $repoRoot "skill-enhancement-tracker.json"
}

# Compose issue body with project context
$fullBody = @"
**Requesting project:** tkubica12/skill-demo-project
**Skill:** $SkillName

$Body
"@

Write-Host "Creating enhancement issue in '$CatalogRepo' ..." -ForegroundColor Cyan

$issueUrl = gh issue create `
    --repo  $CatalogRepo `
    --title $Title `
    --body  $fullBody `
    --label "enhancement" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create GitHub issue: $issueUrl"
    exit $LASTEXITCODE
}

# Parse issue number from URL (format: https://github.com/owner/repo/issues/NNN)
$issueNumber = ($issueUrl -split "/")[-1]

Write-Host "Issue created: $issueUrl" -ForegroundColor Green

# Load existing tracker
$tracker = Get-Content $TrackerFile -Raw | ConvertFrom-Json

# Append new entry
$entry = [PSCustomObject]@{
    issue_number = [int]$issueNumber
    issue_url    = $issueUrl.Trim()
    title        = $Title
    skill        = $SkillName
    catalog_repo = $CatalogRepo
    created_at   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    status       = "open"
}

$tracker.enhancements += $entry

# Write back
$tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerFile -Encoding UTF8

Write-Host "Tracked in $TrackerFile (issue #$issueNumber)." -ForegroundColor Green
Write-Host "Commit and push the tracker file so teammates see it:"
Write-Host "  git add skill-enhancement-tracker.json && git commit -m 'track: skill enhancement #$issueNumber' && git push"
