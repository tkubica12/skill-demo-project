<#
.SYNOPSIS
    Applies the local bulk-add-comment experiment to the installed skill.

.DESCRIPTION
    1. Resolves the installed task-api-helper CLI at the canonical path:
           .agents\skills\task-api-helper\scripts\task_cli.py
    2. Snapshots it to snapshots/<timestamp>_original_task_cli.py (gitignored).
    3. Copies experiments\bulk_add_comment\task_cli_experimental.py over it,
       enabling the new 'bulk-add-comment' sub-command.

    The skill MUST be installed before running this script:
        .\scripts\Install-SharedSkill.ps1

    Run Reset-LocalSkill.ps1 after benchmarking to restore the original.

.EXAMPLE
    .\Apply-LocalExperiment.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$expSrc   = Join-Path $repoRoot "experiments\bulk_add_comment\task_cli_experimental.py"
$snapDir  = Join-Path $repoRoot "snapshots"

if (-not (Test-Path $expSrc)) {
    Write-Error "Experimental file not found: $expSrc"
    exit 1
}

# ------------------------------------------------------------------
# Locate the installed skill entry-point (canonical path after gh skill install)
# ------------------------------------------------------------------
$cliPath = & (Join-Path $PSScriptRoot "Get-SkillCliPath.ps1")
if (-not $cliPath) {
    Write-Error @"
Cannot locate the installed skill CLI.
Install the skill before applying the experiment:
  .\scripts\Install-SharedSkill.ps1
"@
    exit 1
}

Write-Host "Installed CLI found at: $cliPath" -ForegroundColor Cyan

# ------------------------------------------------------------------
# Snapshot original so Reset-LocalSkill.ps1 can restore it
# ------------------------------------------------------------------
$timestamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$snapshotPath = Join-Path $snapDir "${timestamp}_original_task_cli.py"
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
Copy-Item -Path $cliPath -Destination $snapshotPath
Write-Host "Snapshot saved : $snapshotPath" -ForegroundColor Cyan

# Write a pointer file so Reset-LocalSkill.ps1 knows what to restore
$pointerFile = Join-Path $snapDir "latest_snapshot.txt"
Set-Content -Path $pointerFile -Value "$cliPath`n$snapshotPath" -Encoding UTF8

# ------------------------------------------------------------------
# Apply experiment (overwrite installed CLI with experimental version)
# ------------------------------------------------------------------
Copy-Item -Path $expSrc -Destination $cliPath -Force
Write-Host "Experiment applied: bulk-add-comment is now available." -ForegroundColor Green
Write-Host ""
Write-Host "Try it:"
Write-Host "  `$env:TASK_API_URL = 'http://localhost:8080'"
Write-Host "  python `"$cliPath`" bulk-add-comment --status waiting-for-response --comment `"Ping`""
Write-Host ""
Write-Host "Or pass the URL explicitly:"
Write-Host "  python `"$cliPath`" bulk-add-comment --status waiting-for-response --comment `"Ping`" --api-url http://localhost:8080"
Write-Host ""
Write-Host "When done, restore with: .\scripts\Reset-LocalSkill.ps1"

