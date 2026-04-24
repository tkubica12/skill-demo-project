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
.agents/skills/task-api-helper/
    SKILL.md
    references/
    scripts/
        task_cli.py          ← the CLI wrapper — invoke via Python, NOT as a shell command
```

The CLI is **NOT** added to PATH. Always invoke it through Python:

```bash
export TASK_API_URL="http://localhost:8080"   # or deployed URL
python ".agents/skills/task-api-helper/scripts/task_cli.py" list-tasks
```

| Sub-command | Example |
|---|---|
| `list-tasks [--status <s>]` | `python task_cli.py list-tasks --status open` |
| `get-task <id>` | `python task_cli.py get-task task-001` |
| `add-comment <id> <text>` | `python task_cli.py add-comment task-001 "Ping"` |

Use the `uv` entry points to resolve the path and URL reliably:

```bash
API_URL=$(uv run get-api-url)
uv run run-baseline --api-url "$API_URL"
```

---

## API URL Configuration

All `uv run` commands resolve the Task API endpoint using this priority order:

| Source | Value |
|---|---|
| `--api-url` flag | Explicit override for that invocation |
| `TASK_API_URL` env var | Deployed Azure Container App URL or any custom endpoint |
| Default (fallback) | `http://localhost:8080` (local mock server) |

### Local development (mock API)

```bash
# Start the local mock server (background)
uv run start-mock-api

# TASK_API_URL not required – commands fall back to http://localhost:8080
uv run run-baseline
```

### Deployed Azure Container App (preferred demo path)

```bash
export TASK_API_URL="https://<your-app>.azurecontainerapps.io"

# All commands now target the deployed endpoint automatically
uv run run-baseline
uv run benchmark --phase before
```

You can also pass `--api-url` explicitly to any command to override both the
env var and the default:

```bash
uv run run-baseline --api-url "https://<your-app>.azurecontainerapps.io"
```

---

## The Painful Baseline Scenario

A recurring real-world need is: **"Add a status-update comment to every task
whose status is `waiting-for-response`."**

With the current skill this requires a loop:

```python
import json, os, subprocess, urllib.request
cli = ".agents/skills/task-api-helper/scripts/task_cli.py"
tasks = json.loads(
    urllib.request.urlopen("http://localhost:8080/tasks?status=waiting-for-response").read()
)
for task in tasks:
    subprocess.run(["python", cli, "add-comment", task["id"], "Following up."])
```

Every iteration spawns a new Python process, pays startup overhead, opens a TCP
connection, and closes it. With many tasks this is noticeably slow.

**The missing capability is `bulk-add-comment`** – a single command that accepts
a status filter or explicit IDs and posts all comments in one session.

---

## Normal Workflow (prefer the central skill)

1. Install the skill:     `uv run install-skill`
2. Start the mock API:    `uv run start-mock-api` *(or set `TASK_API_URL` for deployed)*
3. Use the CLI via Python (path: `.agents/skills/task-api-helper/scripts/task_cli.py`).
4. If you find a gap or pain point, **do not edit the installed skill directly**.
   Instead follow the Experiment & Issue workflow below.

---

## Experiment & Issue Workflow

When you identify a painful repetitive operation that the installed skill does
not support well, follow these steps **in order**:

### Step 1 – Run the baseline benchmark

```bash
uv run benchmark --phase before
```

This times the per-task CLI loop (one Python process per task) and saves results
to `benchmark-results-before.json`.

### Step 2 – Apply the local experiment

```bash
uv run apply-experiment
```

This command:
- Requires the skill to be installed (fails with a clear message if not).
- Snapshots the currently installed `task_cli.py` to `snapshots/` (gitignored).
- Copies `experiments/bulk_add_comment/task_cli_experimental.py` over the
  installed skill entry-point so the new `bulk-add-comment` sub-command is
  available.

**The snapshot is local-only and gitignored. Do not commit it.**

### Step 3 – Run the after benchmark

```bash
uv run benchmark --phase after
```

Saves results to `benchmark-results-after.json`.

### Step 4 – File an upstream issue

```bash
uv run file-issue \
    --title "Add bulk-add-comment command to task-api-helper" \
    --benchmark-before benchmark-results-before.json \
    --benchmark-after  benchmark-results-after.json
```

This command:
- Creates a detailed GitHub issue in `tkubica12/skills-demo-catalog` with
  benchmark data, motivation, and the experimental implementation as evidence.
- Appends the issue ID, URL, and metadata to `skill-improvement-log.json`.

**Commit and push the tracker after running the command:**

```bash
git add skill-improvement-log.json
git commit -m "track: upstream issue #<N> – bulk-add-comment request"
git push
```

### Step 5 – Restore the local skill

```bash
uv run reset-skill
```

Restores the installed skill from the snapshot.
**Always run this step** – the experiment is evidence, not a permanent fix.

### Step 6 – Monitor resolution

```bash
uv run check-issues
```

Checks whether any tracked issues in `skill-improvement-log.json` have been
closed. When the catalog ships a new release that includes `bulk-add-comment`,
re-run:

```bash
uv run install-skill            # upgrade to the new release
uv run check-issues --update-file --auto-clean
git add skill-improvement-log.json && git commit -m "tracker: resolved issue #<N>" && git push
```

---

## Key Principles

- **Prefer the central skill.** Local overrides are temporary evidence only.
- **The CLI is not a shell command.** Always invoke via `python task_cli.py ...`.
- **Use `uv run get-api-url`** to resolve the canonical API URL.
- **Set `TASK_API_URL`** to switch from local mock to a deployed endpoint.
- **Benchmark before and after.** Numbers justify the upstream issue.
- **File an issue, not a PR.** The catalog has maintainers; respect their process.
- **Always restore.** Never leave the installed skill in a patched state after the demo.
- **Commit the tracker.** Future sessions and teammates need to see open requests.
- **Do not commit snapshots.** They contain the vendor-provided skill binary.

---

## Quick Reference: Full Demo Sequence

```bash
# 0. Install the shared skill (once per clone)
uv run install-skill

# 1a. Local dev: start the mock API in the background
uv run start-mock-api

# 1b. OR point at the deployed Azure Container App
export TASK_API_URL="https://<your-app>.azurecontainerapps.io"

# 2. Run the painful baseline scenario (shows the problem)
uv run run-baseline

# 3. Benchmark the baseline (one CLI process per task)
uv run benchmark --phase before

# 4. Apply local experiment (overwrites installed task_cli.py reversibly)
uv run apply-experiment

# 5. Run the experiment scenario (shows the improvement)
CLI=".agents/skills/task-api-helper/scripts/task_cli.py"
python "$CLI" bulk-add-comment --status waiting-for-response \
    --comment "Following up" --api-url "$(uv run get-api-url | tail -1)"

# 6. Benchmark the experiment
uv run benchmark --phase after
uv run benchmark --phase compare

# 7. File upstream issue with evidence
uv run file-issue \
    --title "Add bulk-add-comment to task-api-helper" \
    --benchmark-before benchmark-results-before.json \
    --benchmark-after  benchmark-results-after.json

# 8. Commit the tracker
git add skill-improvement-log.json && git commit -m "track: upstream issue" && git push

# 9. Restore local skill to pristine state
uv run reset-skill
```

> **PowerShell users:** equivalent `.ps1` scripts remain in `scripts/` for
> compatibility, but the `uv run` commands above are the canonical multiplatform
> interface.

