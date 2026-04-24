<#
.SYNOPSIS
    Applies the local bulk-add-comment experiment to the installed skill.

.DESCRIPTION
    1. Locates the installed task-api-helper CLI entry-point.
    2. Snapshots it to snapshots/<timestamp>_original_task_cli.py (gitignored).
    3. Copies experiments\bulk_add_comment\task_cli_experimental.py over it,
       enabling the new 'bulk-add-comment' sub-command.

    Run Reset-LocalSkill.ps1 after benchmarking to restore the original.

.PARAMETER SkillEntryPoint
    Explicit path to the installed skill Python entry-point.
    If omitted the script tries to locate it automatically via 'where task-api-helper'.

.EXAMPLE
    .\Apply-LocalExperiment.ps1
#>
[CmdletBinding()]
param(
    [string]$SkillEntryPoint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $PSScriptRoot
$expSrc     = Join-Path $repoRoot "experiments\bulk_add_comment\task_cli_experimental.py"
$snapDir    = Join-Path $repoRoot "snapshots"

if (-not (Test-Path $expSrc)) {
    Write-Error "Experimental file not found: $expSrc"
    exit 1
}

# ------------------------------------------------------------------
# Locate installed skill entry-point
# ------------------------------------------------------------------
if (-not $SkillEntryPoint) {
    # Try to find via where/Get-Command
    $cmd = Get-Command "task-api-helper" -ErrorAction SilentlyContinue
    if ($cmd) {
        $SkillEntryPoint = $cmd.Source
        Write-Host "Found installed skill at: $SkillEntryPoint" -ForegroundColor Cyan
    } else {
        # Fall back: look for a known install location pattern
        $candidates = @(
            "$env:USERPROFILE\.local\share\gh\extensions\gh-task-api-helper\task_cli.py",
            "$env:USERPROFILE\.local\bin\task_cli.py",
            (Join-Path $repoRoot ".github\copilot\skills\task-api-helper\task_cli.py")
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $SkillEntryPoint = $c
                Write-Host "Found skill entry-point at: $c" -ForegroundColor Cyan
                break
            }
        }
    }
}

if (-not $SkillEntryPoint -or -not (Test-Path $SkillEntryPoint)) {
    Write-Warning "Could not locate the installed skill entry-point automatically."
    Write-Warning "Pass -SkillEntryPoint <path> explicitly, or install the skill first:"
    Write-Warning "  .\scripts\Install-SharedSkill.ps1"
    Write-Warning ""
    Write-Warning "For demo purposes, creating a local stub at .github\copilot\skills\task-api-helper\task_cli.py"

    # Create a stub so the demo can proceed without a real 'gh skill install'
    $stubDir = Join-Path $repoRoot ".github\copilot\skills\task-api-helper"
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null
    $stubPath = Join-Path $stubDir "task_cli.py"

    # Write a minimal baseline stub (no bulk-add-comment)
    $stubContent = @'
"""Baseline task-api-helper stub (installed by Install-SharedSkill.ps1)."""
import argparse, json, sys, urllib.request, urllib.error
DEFAULT_API_URL = "http://localhost:8080"

def _get(url):
    with urllib.request.urlopen(url, timeout=10) as r: return json.loads(r.read())

def _post(url, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data,
        headers={"Content-Type":"application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=10) as r: return json.loads(r.read())

def main():
    p = argparse.ArgumentParser(prog="task-api-helper")
    p.add_argument("--api-url", default=DEFAULT_API_URL)
    sub = p.add_subparsers(dest="cmd", required=True)
    pl = sub.add_parser("list-tasks"); pl.add_argument("--status")
    pg = sub.add_parser("get-task");   pg.add_argument("id")
    pc = sub.add_parser("add-comment");pc.add_argument("id"); pc.add_argument("text")
    a = p.parse_args()
    if a.cmd == "list-tasks":
        url = a.api_url+"/tasks"+(f"?status={a.status}" if a.status else "")
        print(json.dumps(_get(url), indent=2))
    elif a.cmd == "get-task":
        print(json.dumps(_get(f"{a.api_url}/tasks/{a.id}"), indent=2))
    elif a.cmd == "add-comment":
        print(json.dumps(_post(f"{a.api_url}/tasks/{a.id}/comments", {"text":a.text}), indent=2))

if __name__ == "__main__":
    main()
'@
    Set-Content -Path $stubPath -Value $stubContent -Encoding UTF8
    $SkillEntryPoint = $stubPath
    Write-Host "Stub created at: $stubPath" -ForegroundColor Yellow
}

# ------------------------------------------------------------------
# Snapshot
# ------------------------------------------------------------------
$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$snapshotPath = Join-Path $snapDir "${timestamp}_original_task_cli.py"
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
Copy-Item -Path $SkillEntryPoint -Destination $snapshotPath
Write-Host "Snapshot saved : $snapshotPath" -ForegroundColor Cyan

# Write a pointer file so Reset-LocalSkill.ps1 knows what to restore
$pointerFile = Join-Path $snapDir "latest_snapshot.txt"
Set-Content -Path $pointerFile -Value "$SkillEntryPoint`n$snapshotPath" -Encoding UTF8

# ------------------------------------------------------------------
# Apply experiment
# ------------------------------------------------------------------
Copy-Item -Path $expSrc -Destination $SkillEntryPoint -Force
Write-Host "Experiment applied: bulk-add-comment is now available." -ForegroundColor Green
Write-Host ""
Write-Host "Try it:"
Write-Host "  python `"$SkillEntryPoint`" bulk-add-comment --status waiting-for-response --comment `"Ping`""
Write-Host ""
Write-Host "When done, restore with: .\scripts\Reset-LocalSkill.ps1"
