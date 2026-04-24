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
| `python task_cli.py add-comment <id> <text>` | Post a comment on a single task |

### The Pain Point – missing `bulk-add-comment`

A recurring workflow is: **"Post a status-update comment on every task whose
status is `waiting-for-response`."**

With the baseline skill this requires a per-task loop:

```python
import json, os, subprocess, urllib.request
cli = ".agents/skills/task-api-helper/scripts/task_cli.py"
tasks = json.loads(
    urllib.request.urlopen("http://localhost:8080/tasks?status=waiting-for-response").read()
)
for task in tasks:
    subprocess.run(["python", cli, "add-comment", task["id"], "Following up – please provide an update."])
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
├── pyproject.toml                     # uv project – entry points for all demo commands
├── demo/                              # Python package backing the uv run commands
│   ├── _common.py                     # shared helpers (resolve URL, CLI path, etc.)
│   ├── get_api_url.py                 # uv run get-api-url
│   ├── install_skill.py               # uv run install-skill
│   ├── start_mock_api.py              # uv run start-mock-api
│   ├── baseline.py                    # uv run run-baseline
│   ├── apply_experiment.py            # uv run apply-experiment
│   ├── reset_skill.py                 # uv run reset-skill
│   ├── benchmark.py                   # uv run benchmark
│   ├── file_issue.py                  # uv run file-issue
│   └── check_issues.py               # uv run check-issues
├── AGENTS.md                          # agent playbook (read this first)
├── README.md
├── skill-improvement-log.json         # committed tracker of upstream issues
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
└── scripts/                           # PowerShell equivalents (kept for compatibility)
    ├── Get-TaskApiUrl.ps1
    ├── Get-SkillCliPath.ps1
    ├── Install-SharedSkill.ps1
    ├── Start-MockApi.ps1
    ├── Invoke-BaselineScenario.ps1
    ├── Apply-LocalExperiment.ps1
    ├── Reset-LocalSkill.ps1
    ├── Invoke-Benchmark.ps1
    ├── New-UpstreamIssue.ps1
    └── Get-IssueStatus.ps1
```

---

## Prerequisites

- [uv](https://docs.astral.sh/uv/) – `pip install uv` or `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `gh auth login`.
- Python 3.9+ (managed automatically by `uv` if not already present).
- Access to `tkubica12/skills-demo-catalog` (read for status checks, write for issues).

No manual `pip install` or virtualenv setup needed — `uv run` handles everything.

---

## API URL Configuration

All `uv run` commands resolve the Task API endpoint automatically:

| Priority | Source | Value |
|---|---|---|
| 1 | `--api-url` flag | Explicit override for that invocation |
| 2 | `TASK_API_URL` env var | Deployed Azure Container App (or any remote URL) |
| 3 | Default fallback | `http://localhost:8080` (local mock server) |

### Local development (mock API)

```bash
uv run start-mock-api       # starts mock on http://localhost:8080 (background)
# TASK_API_URL not required – commands fall back automatically
```

### Deployed Azure Container App (main demo path)

```bash
export TASK_API_URL="https://<your-app>.azurecontainerapps.io"
# All commands now target the deployed endpoint – no other changes needed
uv run run-baseline
```

You can also pass `--api-url` explicitly to any command:

```bash
uv run benchmark --phase before --api-url "https://<your-app>.azurecontainerapps.io"
```

---

## Full Demo Command Sequence

> **Multiplatform:** all commands use `uv run` and work on Linux, macOS, and Windows.
> PowerShell equivalents remain in `scripts/` for compatibility.

### 0 – Install the shared skill (once per clone)

```bash
uv run install-skill
```

### 1 – Start the mock API (or set deployed URL)

**Option A – local mock:**

```bash
uv run start-mock-api
# Verify:
curl http://localhost:8080/health
```

**Option B – deployed Azure Container App:**

```bash
export TASK_API_URL="https://<your-app>.azurecontainerapps.io"
curl "$TASK_API_URL/health"
```

### 2 – See the baseline scenario in action

```bash
uv run run-baseline
```

This loops through all `waiting-for-response` tasks and calls
`python task_cli.py add-comment` once per task – the slow path (one process
spawn per task).

### 3 – Benchmark the baseline

```bash
uv run benchmark --phase before
```

Saves elapsed time to `benchmark-results-before.json`.

### 4 – Apply the local experiment

```bash
uv run apply-experiment
```

Snapshots the installed skill to `snapshots/` (gitignored) and replaces it
with the experimental CLI that includes `bulk-add-comment`.

### 5 – Run the improved scenario

```bash
CLI=".agents/skills/task-api-helper/scripts/task_cli.py"
python "$CLI" bulk-add-comment \
    --status waiting-for-response \
    --comment "Following up" \
    --api-url "$(uv run get-api-url | tail -1)"
```

### 6 – Benchmark the experiment

```bash
uv run benchmark --phase after
uv run benchmark --phase compare
```

### 7 – File the upstream issue with evidence

```bash
uv run file-issue \
    --title "Add bulk-add-comment command to task-api-helper" \
    --benchmark-before benchmark-results-before.json \
    --benchmark-after  benchmark-results-after.json
```

Then commit the tracker:

```bash
git add skill-improvement-log.json
git commit -m "track: upstream issue #<N> – bulk-add-comment request"
git push
```

### 8 – Restore the local skill

```bash
uv run reset-skill
```

Always run this. The experiment is evidence only, not a permanent override.

### 9 – Monitor resolution

When the catalog ships a new version:

```bash
uv run check-issues                             # see current state
uv run install-skill                            # upgrade to new release
uv run check-issues --update-file --auto-clean
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

`uv run check-issues --update-file` adds `"status": "resolved"` and `"closed_at"` when the catalog closes the issue.

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
# or via uv:
uv run start-mock-api --foreground
```
