<#
.SYNOPSIS
    Restores the installed skill to its original state from the snapshot.

.DESCRIPTION
    Reads snapshots/latest_snapshot.txt to find the original entry-point path
    and snapshot path, then copies the snapshot back.
    If no snapshot exists, re-runs Install-SharedSkill.ps1 as a fallback.

.EXAMPLE
    .\Reset-LocalSkill.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot    = Split-Path -Parent $PSScriptRoot
$snapDir     = Join-Path $repoRoot "snapshots"
$pointerFile = Join-Path $snapDir "latest_snapshot.txt"

if (-not (Test-Path $pointerFile)) {
    Write-Warning "No snapshot pointer found at $pointerFile."
    Write-Warning "Either the experiment was never applied, or snapshots/ was cleaned."
    Write-Host ""
    Write-Host "If you need to restore the skill to a clean state, re-install it:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Install-SharedSkill.ps1"
    return
}

$lines        = Get-Content $pointerFile
$entryPoint   = $lines[0].Trim()
$snapshotPath = $lines[1].Trim()

if (-not (Test-Path $snapshotPath)) {
    Write-Error "Snapshot file not found: $snapshotPath  (snapshots/ is gitignored – was it cleaned?)"
    Write-Host "Re-install the skill to restore it to a clean state:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Install-SharedSkill.ps1"
    return
}

Write-Host "Restoring $entryPoint from $snapshotPath ..." -ForegroundColor Cyan
Copy-Item -Path $snapshotPath -Destination $entryPoint -Force

# Clean up pointer so a future apply can start fresh
Remove-Item $pointerFile -Force -ErrorAction SilentlyContinue

Write-Host "Local skill restored to original state." -ForegroundColor Green
Write-Host "The experiment is no longer active."
