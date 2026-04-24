<#
.SYNOPSIS
    Removes a tracked skill enhancement entry from the tracker file.

.DESCRIPTION
    Use this script to clean up a tracked enhancement that was filed in error,
    is a duplicate, or has been resolved and you no longer want it in the active
    tracker (e.g., before a demo).

.PARAMETER IssueNumber
    The GitHub issue number to remove from the tracker (required).

.PARAMETER TrackerFile
    Path to the JSON tracker file. Default: skill-enhancement-tracker.json in repo root.

.EXAMPLE
    .\Remove-SkillEnhancement.ps1 -IssueNumber 42

#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [int]$IssueNumber,

    [string]$TrackerFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TrackerFile) {
    $TrackerFile = Join-Path $repoRoot "skill-enhancement-tracker.json"
}

$tracker = Get-Content $TrackerFile -Raw | ConvertFrom-Json

$before = $tracker.enhancements.Count
$tracker.enhancements = @($tracker.enhancements | Where-Object { $_.issue_number -ne $IssueNumber })
$after  = $tracker.enhancements.Count

if ($before -eq $after) {
    Write-Warning "Issue #$IssueNumber was not found in the tracker."
    exit 0
}

if ($PSCmdlet.ShouldProcess($TrackerFile, "Remove issue #$IssueNumber")) {
    $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerFile -Encoding UTF8
    Write-Host "Issue #$IssueNumber removed from tracker." -ForegroundColor Green
    Write-Host "Run: git add skill-enhancement-tracker.json && git commit -m 'chore: remove skill enhancement #$IssueNumber from tracker' && git push"
}
