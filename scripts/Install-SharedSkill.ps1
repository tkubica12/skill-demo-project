<#
.SYNOPSIS
    Installs the shared 'release-readiness-check' skill from the central catalog
    into this project's scope via 'gh skill install'.

.DESCRIPTION
    Runs 'gh skill install' targeting the shared skill in the central catalog repo.
    After installation the skill will be available to GitHub Copilot when working
    in this repository.

.PARAMETER CatalogRepo
    The central catalog repository in 'owner/repo' format.
    Default: tkubica12/skills-demo-catalog

.PARAMETER SkillName
    The name of the shared skill to install.
    Default: release-readiness-check

.EXAMPLE
    .\Install-SharedSkill.ps1
    .\Install-SharedSkill.ps1 -CatalogRepo myorg/skills-catalog -SkillName my-skill

#>
[CmdletBinding()]
param(
    [string]$CatalogRepo = "tkubica12/skills-demo-catalog",
    [string]$SkillName   = "release-readiness-check"
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
Write-Host "You can now use it in Copilot sessions within this repo."
