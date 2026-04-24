# skill-demo-project

A **consumer project** that hosts a mock task-management REST API and demonstrates
how a team uses the shared `task-api-helper` skill from the central catalog
[tkubica12/skills-demo-catalog](https://github.com/tkubica12/skills-demo-catalog).

It also shows the full **identify → experiment → benchmark → upstream-issue → restore**
workflow that a team follows when a gap in a shared skill is discovered.

---

## The Scenario

Your organisation maintains a **central skill catalog** (`tkubica12/skills-demo-catalog`).  
One published skill is `task-api-helper`, which Copilot uses to interact with task
management APIs. After `gh skill install` the skill lands at:

```
.agents\skills\task-api-helper\scripts\task_cli.py
```

It exposes three commands — invoked via Python, **not** as a global shell command:

| Invocation | What it does |
|---|---|
| `python task_cli.py list-tasks [--status <s>]` | List tasks (optionally filtered by status) |
| `python task_cli.py get-task <id>` | Fetch details of one task |
| `python task_cli.py add-comment <id> --message <text>` | Post a comment on a single task |

### The Pain Point – missing `bulk-add-comment`

A recurring workflow is: **"Post a status-update comment on every task whose
status is `waiting-for-response`."**

With the baseline skill this requires a per-task loop:

```powershell
$cliPath = ".agents\skills\task-api-helper\scripts\task_cli.py"
$env:TASK_API_BASE_URL = "http://localhost:8080"
foreach ($task in (Invoke-RestMethod "http://localhost:8080/tasks?status=waiting-for-response")) {
    python $cliPath add-comment $task.id --message "Following up – please provide an update."
}
```

Every iteration spawns a Python process, pays startup overhead, and opens a
connection. With 5+ tasks the latency is noticeable. A `bulk-add-comment`
command would post all comments in a single process invocation.

---

## How AGENTS.md Drives Automatic Behaviour

`AGENTS.md` at the repo root is the authoritative playbook for any AI agent.
It instructs the agent to:

1. **Prefer the central skill** – never hard-code workarounds.
2. **Benchmark the baseline** before touching anything.
3. **Apply a temporary local experiment** from `experiments/bulk_add_comment/`
   to prove the improvement is real.
4. **Benchmark again** and compare.
5. **File a detailed upstream issue** (not a PR) with benchmark evidence.
6. **Commit the tracker file** so teammates see the open request.
7. **Restore the local skill** to pristine state.

When a Copilot agent sees a repetitive multi-call pattern, `AGENTS.md` gives
it enough context to run the full workflow autonomously.

---

## Manual Trigger Path

Because true custom slash commands are not available, you can trigger the
workflow manually with the individual scripts below, or by prompting Copilot:

> "Follow the AGENTS.md experiment workflow to file an issue for bulk-add-comment."

---

## Repository Layout

```
skill-demo-project/
├── AGENTS.md                          # agent playbook (read this first)
├── README.md
├── skill-improvement-log.json         # committed tracker of upstream issues (starts empty)
├── .gitignore
├── .github/
│   ├── copilot-instructions.md
│   └── instructions/
│       ├── task-api.instructions.md
│       └── skill-experiment.instructions.md
├── api/
│   ├── server.py                      # Mock Task REST API (Python stdlib)
│   └── seed_data.json                 # 8 seed tasks, 5 with waiting-for-response
├── experiments/
│   └── bulk_add_comment/
│       └── task_cli_experimental.py   # proof-of-concept CLI with bulk-add-comment
├── snapshots/                         # gitignored – local skill backups land here
│   └── .gitkeep
└── scripts/
    ├── Install-SharedSkill.ps1        # gh skill install task-api-helper
    ├── Start-MockApi.ps1              # launch api/server.py in background
    ├── Invoke-BaselineScenario.ps1    # painful baseline loop (shows the problem)
    ├── Apply-LocalExperiment.ps1      # snapshot + patch installed skill
    ├── Reset-LocalSkill.ps1           # restore from snapshot
    ├── Invoke-Benchmark.ps1           # before/after timing
    ├── New-UpstreamIssue.ps1          # gh issue create + update tracker
    └── Get-IssueStatus.ps1            # check if tracked issues are resolved
```

---

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `gh auth login`.
- Python 3.9+ on PATH.
- PowerShell 7+.
- Access to `tkubica12/skills-demo-catalog` (read for status checks, write for issues).

---

## Full Demo Command Sequence

### 0 – Install the shared skill (once per clone)

```powershell
.\scripts\Install-SharedSkill.ps1
```

### 1 – Start the mock API

```powershell
.\scripts\Start-MockApi.ps1
# or in foreground: .\scripts\Start-MockApi.ps1 -Foreground
```

The API runs at `http://localhost:8080`.  Verify with:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

### 2 – See the baseline scenario in action

```powershell
.\scripts\Invoke-BaselineScenario.ps1
```

This loops through all `waiting-for-response` tasks and calls
`python task_cli.py add-comment` once per task – the slow path (one process
spawn per task).

### 3 – Benchmark the baseline

```powershell
.\scripts\Invoke-Benchmark.ps1 -Phase before
```

Saves elapsed time to `benchmark-results-before.json`.

### 4 – Apply the local experiment

```powershell
.\scripts\Apply-LocalExperiment.ps1
```

Snapshots the installed skill to `snapshots/` (gitignored) and replaces it
with the experimental CLI that includes `bulk-add-comment`.

### 5 – Run the improved scenario

```powershell
$cliPath = ".agents\skills\task-api-helper\scripts\task_cli.py"
python $cliPath bulk-add-comment --status waiting-for-response --comment "Following up" --api-url http://localhost:8080
```

### 6 – Benchmark the experiment

```powershell
.\scripts\Invoke-Benchmark.ps1 -Phase after
.\scripts\Invoke-Benchmark.ps1 -Phase compare
```

### 7 – File the upstream issue with evidence

```powershell
.\scripts\New-UpstreamIssue.ps1 `
    -Title "Add bulk-add-comment command to task-api-helper" `
    -BenchmarkBefore benchmark-results-before.json `
    -BenchmarkAfter  benchmark-results-after.json
```

Then commit the tracker:

```powershell
git add skill-improvement-log.json
git commit -m "track: upstream issue #<N> – bulk-add-comment request"
git push
```

### 8 – Restore the local skill

```powershell
.\scripts\Reset-LocalSkill.ps1
```

Always run this. The experiment is evidence only, not a permanent override.

### 9 – Monitor resolution

When the catalog ships a new version:

```powershell
.\scripts\Get-IssueStatus.ps1           # see current state of tracked issues
.\scripts\Install-SharedSkill.ps1       # upgrade to new release
.\scripts\Get-IssueStatus.ps1 -UpdateFile -AutoClean
git add skill-improvement-log.json && git commit -m "tracker: resolved issue #<N>" && git push
```

---

## skill-improvement-log.json Format

```json
{
  "description": "...",
  "skill": "task-api-helper",
  "catalog_repo": "tkubica12/skills-demo-catalog",
  "requests": [
    {
      "issue_number": 42,
      "issue_url":    "https://github.com/tkubica12/skills-demo-catalog/issues/42",
      "title":        "Add bulk-add-comment command to task-api-helper",
      "skill":        "task-api-helper",
      "catalog_repo": "tkubica12/skills-demo-catalog",
      "enhancement":  "bulk-add-comment",
      "created_at":   "2025-07-01T09:00:00Z",
      "status":       "open"
    }
  ]
}
```

`Get-IssueStatus.ps1 -UpdateFile` adds `"status": "resolved"` and `"closed_at"` when the catalog closes the issue.

---

## Mock API Reference

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/tasks` | List all tasks (supports `?status=<s>`) |
| `GET` | `/tasks/{id}` | Get one task |
| `POST` | `/tasks/{id}/comments` | Add a comment `{"text":"..."}` |

Seed data includes 8 tasks: 5 with `waiting-for-response`, 1 `open`, 1 `in-progress`, 1 `resolved`.

Start directly:

```bash
python api/server.py --port 8080
```
