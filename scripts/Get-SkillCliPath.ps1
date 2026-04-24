<#
.SYNOPSIS
    Returns the path to the installed task-api-helper CLI script.

.DESCRIPTION
    'gh skill install' places the skill under:
        .agents\skills\task-api-helper\scripts\task_cli.py
    relative to the repository root. This helper surfaces that path so every
    script uses the same resolution logic.

    Outputs the full path on success.
    Writes an error and returns nothing if the skill is not installed.

.OUTPUTS
    [string] Full path to the installed task_cli.py, or nothing on failure.

.EXAMPLE
    $cliPath = & (Join-Path $PSScriptRoot "Get-SkillCliPath.ps1")
    if (-not $cliPath) { exit 1 }
#>
[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent $PSScriptRoot
$cliPath  = Join-Path $repoRoot ".agents\skills\task-api-helper\scripts\task_cli.py"

if (-not (Test-Path $cliPath)) {
    Write-Host "ERROR: Installed skill CLI not found at:" -ForegroundColor Red
    Write-Host "  $cliPath" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Install the shared skill first:" -ForegroundColor Yellow
    Write-Host "  .\scripts\Install-SharedSkill.ps1" -ForegroundColor Yellow
    return   # returns $null to the caller
}

$cliPath  # write path to the output stream so callers can capture it
