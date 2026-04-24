---
applyTo: "experiments/**,demo/apply_experiment.py,demo/reset_skill.py,scripts/Apply-LocalExperiment.ps1,scripts/Reset-LocalSkill.ps1"
---
# Skill Experiment Instructions

## Purpose

Files in `experiments/` are **evidence assets**, not permanent replacements.
They exist solely to produce benchmark data and a compelling upstream issue.

## Structure

```
experiments/
└── bulk_add_comment/
    └── task_cli_experimental.py   # drop-in replacement for the installed skill CLI
```

## How the Experiment Works

1. `uv run apply-experiment` snapshots the installed skill entry-point to
   `snapshots/<timestamp>_original_task_cli.py` (gitignored) and then
   overwrites it with `experiments/bulk_add_comment/task_cli_experimental.py`.

2. The experimental CLI is fully backward-compatible: it supports all original
   commands (`list-tasks`, `get-task`, `add-comment`) plus adds `bulk-add-comment`.

3. `uv run reset-skill` restores the snapshot. If no snapshot exists it
   suggests re-running `uv run install-skill` to re-download a clean copy.

## Constraints

- Never commit snapshot files.
- Never commit a patched installed skill.
- The experimental file **must** be backward-compatible (all original commands work).
- The experiment targets `http://localhost:8080` by default (overridable with `--api-url`).
