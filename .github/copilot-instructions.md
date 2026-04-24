# GitHub Copilot Instructions – skill-demo-project

## What This Repo Is

This project is a **consumer** of the shared `task-api-helper` skill published at
`tkubica12/skills-demo-catalog`.  It hosts a small mock task-management REST API
and scripts that demonstrate how a team works with a shared skill and how to
identify, benchmark, and report gaps back to the central catalog maintainers.

## Always Read AGENTS.md First

Before doing any multi-step task, read `AGENTS.md` at the repo root.  It is the
authoritative guide for how agents should behave in this project.

## Python / uv Tooling

This project uses `uv` for all demo commands. The `pyproject.toml` defines entry
points for every workflow step. Run commands with `uv run <command>`.

Key entry points:

| Command | Purpose |
|---|---|
| `uv run install-skill` | Install the shared skill via `gh skill install` |
| `uv run start-mock-api` | Start `api/server.py` in the background |
| `uv run get-api-url` | Resolve active API URL (env var or localhost fallback) |
| `uv run run-baseline` | Run the slow per-task loop (shows the pain point) |
| `uv run apply-experiment` | Snapshot + patch installed skill with bulk-add-comment |
| `uv run reset-skill` | Restore installed skill from snapshot |
| `uv run benchmark --phase before\|after\|compare` | Time the baseline or experiment |
| `uv run file-issue --title "..."` | Create upstream GitHub issue + update tracker |
| `uv run check-issues [--update-file] [--auto-clean]` | Check issue resolution |

All commands accept `--api-url` to override the endpoint; otherwise they read
`TASK_API_URL` or fall back to `http://localhost:8080`.

## Mock API

The mock REST API lives in `api/server.py` and runs on `http://localhost:8080`
by default.  Seed data is in `api/seed_data.json`.

Start it with: `uv run start-mock-api`

For a deployed endpoint, set `TASK_API_URL` to the Azure Container App URL.
`uv run get-api-url` resolves the active URL automatically.

Endpoints:
- `GET  /tasks`            – list all tasks (supports `?status=<status>` query param)
- `GET  /tasks/{id}`       – get one task
- `POST /tasks/{id}/comments` – add a comment `{ "text": "..." }`

## The Central Skill

The installed skill is `task-api-helper` from `tkubica12/skills-demo-catalog`.
It provides:
- `task-api-helper list-tasks [--status <s>]`
- `task-api-helper get-task <id>`
- `task-api-helper add-comment <id> <text>`

Install it with: `uv run install-skill`

Set `TASK_API_URL` (env var) to point at local mock or deployed endpoint.

## The Known Pain Point

Commenting on all `waiting-for-response` tasks requires looping and spawning a
process per task.  A `bulk-add-comment` command would fix this.
The experiment and issue-filing workflow is documented in `AGENTS.md`.

## Tracker File

`skill-improvement-log.json` records upstream issues filed against the catalog.
After filing an issue, commit and push this file so all teammates see the request.

## Do Not

- Commit patched skill binaries or snapshots.
- Leave the local skill in a modified state after a demo.
- File a PR against the catalog without the maintainers' invitation to do so.
