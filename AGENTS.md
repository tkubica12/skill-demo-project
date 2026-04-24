# AGENTS.md – Copilot Agent Workflow Guide

This file is authoritative for any AI agent working in this repository.
Read it fully before taking action on any task.

---

## Project Purpose

This project hosts a **mock task-management REST API** and consumes the shared
`task-api-helper` skill from the central catalog
[tkubica12/skills-demo-catalog](https://github.com/tkubica12/skills-demo-catalog).

`gh skill install` places the skill files at:

```
.agents\skills\task-api-helper\
    SKILL.md
    references\
    scripts\
        task_cli.py          ← the CLI wrapper — invoke via Python, NOT as a shell command
```

The CLI is **NOT** added to PATH. Always invoke it through Python:

```powershell
$env:TASK_API_BASE_URL = "http://localhost:8080"
python ".agents\skills\task-api-helper\scripts\task_cli.py" list-tasks
```

| Sub-command | Example |
|---|---|
| `list-tasks [--status <s>]` | `python task_cli.py list-tasks --status open` |
| `get-task <id>` | `python task_cli.py get-task task-001` |
| `add-comment <id> --message <text>` | `python task_cli.py add-comment task-001 --message "Ping"` |

Use the helper script to resolve the path reliably:

```powershell
$cliPath = & .\scripts\Get-SkillCliPath.ps1
if (-not $cliPath) { exit 1 }
python $cliPath list-tasks
```

---

## The Painful Baseline Scenario

A recurring real-world need is: **"Add a status-update comment to every task
whose status is `waiting-for-response`."**

With the current skill this requires a loop:

```powershell
$cliPath = ".agents\skills\task-api-helper\scripts\task_cli.py"
$env:TASK_API_BASE_URL = "http://localhost:8080"
foreach ($task in (Invoke-RestMethod "http://localhost:8080/tasks?status=waiting-for-response")) {
    python $cliPath add-comment $task.id --message "Following up – please provide an update."
}
```

Every iteration spawns a new Python process, pays startup overhead, opens a TCP
connection, and closes it. With many tasks this is noticeably slow.

**The missing capability is `bulk-add-comment`** – a single command that accepts
a status filter or explicit IDs and posts all comments in one session.

---

## Normal Workflow (prefer the central skill)

1. Install the skill:     `.\scripts\Install-SharedSkill.ps1`
2. Start the mock API:    `.\scripts\Start-MockApi.ps1`
3. Use the CLI via Python (`$cliPath = & .\scripts\Get-SkillCliPath.ps1`).
4. If you find a gap or pain point, **do not edit the installed skill directly**.
   Instead follow the Experiment & Issue workflow below.

---

## Experiment & Issue Workflow

When you identify a painful repetitive operation that the installed skill does
not support well, follow these steps **in order**:

### Step 1 – Run the baseline benchmark

```powershell
.\scripts\Invoke-Benchmark.ps1 -Phase before
```

This times the per-task CLI loop (one Python process per task) and saves results
to `benchmark-results-before.json`.

### Step 2 – Apply the local experiment

```powershell
.\scripts\Apply-LocalExperiment.ps1
```

This script:
- Requires the skill to be installed (fails with a clear message if not).
- Snapshots the currently installed `task_cli.py` to `snapshots/` (gitignored).
- Copies `experiments\bulk_add_comment\task_cli_experimental.py` over the
  installed skill entry-point so the new `bulk-add-comment` sub-command is
  available.

**The snapshot is local-only and gitignored. Do not commit it.**

### Step 3 – Run the after benchmark

```powershell
.\scripts\Invoke-Benchmark.ps1 -Phase after
```

Saves results to `benchmark-results-after.json` and prints a side-by-side
comparison.

### Step 4 – File an upstream issue

```powershell
.\scripts\New-UpstreamIssue.ps1 `
    -Title "Add bulk-add-comment command to task-api-helper" `
    -BenchmarkBefore benchmark-results-before.json `
    -BenchmarkAfter  benchmark-results-after.json
```

This script:
- Creates a detailed GitHub issue in `tkubica12/skills-demo-catalog` with
  benchmark data, motivation, and the experimental implementation as evidence.
- Appends the issue ID, URL, and metadata to `skill-improvement-log.json`.

**Commit and push the tracker after running the script:**

```powershell
git add skill-improvement-log.json
git commit -m "track: upstream issue #<N> – bulk-add-comment request"
git push
```

### Step 5 – Restore the local skill

```powershell
.\scripts\Reset-LocalSkill.ps1
```

Restores the installed skill from the snapshot.
**Always run this step** – the experiment is evidence, not a permanent fix.

### Step 6 – Monitor resolution

```powershell
.\scripts\Get-IssueStatus.ps1
```

Checks whether any tracked issues in `skill-improvement-log.json` have been
closed. When the catalog ships a new release that includes `bulk-add-comment`,
re-run:

```powershell
.\scripts\Install-SharedSkill.ps1   # upgrade to the new release
.\scripts\Get-IssueStatus.ps1 -UpdateFile -AutoClean
git add skill-improvement-log.json && git commit -m "tracker: resolved issue #<N>" && git push
```

---

## Key Principles

- **Prefer the central skill.** Local overrides are temporary evidence only.
- **The CLI is not a shell command.** Always invoke via `python task_cli.py ...`.
- **Use `Get-SkillCliPath.ps1`** to resolve the canonical CLI path.
- **Benchmark before and after.** Numbers justify the upstream issue.
- **File an issue, not a PR.** The catalog has maintainers; respect their process.
- **Always restore.** Never leave the installed skill in a patched state after the demo.
- **Commit the tracker.** Future sessions and teammates need to see open requests.
- **Do not commit snapshots.** They contain the vendor-provided skill binary.

---

## Quick Reference: Full Demo Sequence

```powershell
# 0. Install the shared skill (once per clone)
.\scripts\Install-SharedSkill.ps1

# 1. Start the mock API in a background job
.\scripts\Start-MockApi.ps1

# 2. Run the painful baseline scenario (shows the problem)
.\scripts\Invoke-BaselineScenario.ps1

# 3. Benchmark the baseline (one CLI process per task)
.\scripts\Invoke-Benchmark.ps1 -Phase before

# 4. Apply local experiment (overwrites installed task_cli.py reversibly)
.\scripts\Apply-LocalExperiment.ps1

# 5. Run the experiment scenario (shows the improvement)
$cliPath = ".agents\skills\task-api-helper\scripts\task_cli.py"
python $cliPath bulk-add-comment --status waiting-for-response --comment "Following up" --api-url http://localhost:8080

# 6. Benchmark the experiment
.\scripts\Invoke-Benchmark.ps1 -Phase after
.\scripts\Invoke-Benchmark.ps1 -Phase compare

# 7. File upstream issue with evidence
.\scripts\New-UpstreamIssue.ps1 -Title "Add bulk-add-comment to task-api-helper" `
    -BenchmarkBefore benchmark-results-before.json `
    -BenchmarkAfter  benchmark-results-after.json

# 8. Commit the tracker
git add skill-improvement-log.json && git commit -m "track: upstream issue" && git push

# 9. Restore local skill to pristine state
.\scripts\Reset-LocalSkill.ps1
```

