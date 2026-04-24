<#
.SYNOPSIS
    Installs the shared 'task-api-helper' skill from the central catalog.

.DESCRIPTION
    Runs 'gh skill install' targeting the shared skill in the central catalog repo.
    After installation the skill will be available to GitHub Copilot when working
    in this repository.

.PARAMETER CatalogRepo
    The central catalog repository in 'owner/repo' format.
    Default: tkubica12/skills-demo-catalog

.PARAMETER SkillName
    The name of the shared skill to install.
    Default: task-api-helper

.EXAMPLE
    .\Install-SharedSkill.ps1
    .\Install-SharedSkill.ps1 -CatalogRepo myorg/skills-catalog -SkillName my-skill
#>
[CmdletBinding()]
param(
    [string]$CatalogRepo = "tkubica12/skills-demo-catalog",
    [string]$SkillName   = "task-api-helper"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Installing shared skill '$SkillName' from '$CatalogRepo' ..." -ForegroundColor Cyan

gh skill install $CatalogRepo $SkillName

if ($LASTEXITCODE -ne 0) {
    Write-Error "gh skill install failed (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host "Skill '$SkillName' installed successfully." -ForegroundColor Green

$repoRoot = Split-Path -Parent $PSScriptRoot
$cliPath  = Join-Path $repoRoot ".agents\skills\task-api-helper\scripts\task_cli.py"

Write-Host ""
Write-Host "The CLI is installed at:"
Write-Host "  $cliPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Invoke it via Python (it is NOT a global shell command):"
Write-Host "  `$env:TASK_API_URL = 'http://localhost:8080'   # or set to deployed URL"
Write-Host "  python `"$cliPath`" list-tasks [--status <status>]"
Write-Host "  python `"$cliPath`" get-task <id>"
Write-Host "  python `"$cliPath`" add-comment <id> <text>"
