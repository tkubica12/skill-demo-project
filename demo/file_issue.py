"""File a detailed upstream enhancement issue and record it in skill-improvement-log.json.

Usage:
    uv run file-issue --title "Add bulk-add-comment to task-api-helper"
    uv run file-issue --title "..." --benchmark-before benchmark-results-before.json \\
                      --benchmark-after benchmark-results-after.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone

from demo._common import repo_root


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create an upstream issue and update the skill-improvement tracker."
    )
    parser.add_argument("--title", required=True, help="Issue title.")
    parser.add_argument(
        "--benchmark-before",
        default="",
        help="Path to benchmark-results-before.json (optional but recommended).",
    )
    parser.add_argument(
        "--benchmark-after",
        default="",
        help="Path to benchmark-results-after.json (optional but recommended).",
    )
    parser.add_argument("--catalog-repo", default="tkubica12/skills-demo-catalog")
    parser.add_argument("--skill-name", default="task-api-helper")
    args = parser.parse_args()

    root = repo_root()
    tracker_file = root / "skill-improvement-log.json"

    # ── Build benchmark section ───────────────────────────────────────────────
    bench_section = ""
    bf = args.benchmark_before or str(root / "benchmark-results-before.json")
    ba = args.benchmark_after or str(root / "benchmark-results-after.json")
    try:
        before = json.loads(open(bf, encoding="utf-8").read())
        after = json.loads(open(ba, encoding="utf-8").read())
        saving = round(before["elapsed_seconds"] - after["elapsed_seconds"], 3)
        pct = (
            round((saving / before["elapsed_seconds"]) * 100, 1)
            if before["elapsed_seconds"]
            else 0
        )
        bench_section = f"""
## Benchmark Results

Measured against {before["task_count"]} tasks with status `waiting-for-response`.

| Approach | Elapsed (s) |
|---|---|
| Baseline (per-task loop) | {before["elapsed_seconds"]} |
| Experiment (bulk-add-comment) | {after["elapsed_seconds"]} |
| **Savings** | **{saving}s ({pct}% faster)** |

Benchmark run on {before["timestamp"]}.
"""
    except Exception:
        pass  # benchmark files optional

    cli_rel = ".agents/skills/task-api-helper/scripts/task_cli.py"

    body = f"""## Summary

The `{args.skill_name}` skill currently provides `add-comment <id> <text>`
which operates on a single task per invocation.

A common real-world need is: **post the same comment on every task in a given
status** (e.g., `waiting-for-response`).  The only current approach is a loop
that spawns a new Python process for every task:

```python
import json, os, subprocess, urllib.request
tasks = json.loads(
    urllib.request.urlopen("http://localhost:8080/tasks?status=waiting-for-response").read()
)
for task in tasks:
    subprocess.run(["python", "{cli_rel}", "add-comment", task["id"], "Following up."])
```

Each iteration carries the full process-startup and connection overhead.

## Proposed Enhancement

Add a `bulk-add-comment` sub-command:

```
python task_cli.py bulk-add-comment (--ids <id>... | --status <status>) --comment <text>
```

This opens a single process, resolves the task list once, and posts all
comments in one session – dramatically reducing latency.
{bench_section}
## Experimental Implementation

A proof-of-concept CLI (fully backward-compatible) is available in the
requesting project:

[tkubica12/skill-demo-project – experiments/bulk_add_comment/task_cli_experimental.py](https://github.com/tkubica12/skill-demo-project/blob/main/experiments/bulk_add_comment/task_cli_experimental.py)

## Requesting Project

**Repository:** tkubica12/skill-demo-project
**Skill installed:** `{args.skill_name}` from `{args.catalog_repo}`
**Skill CLI path (post-install):** `{cli_rel}`
"""

    # ── Create issue ──────────────────────────────────────────────────────────
    print(f"Creating issue in '{args.catalog_repo}' ...")
    result = subprocess.run(
        [
            "gh",
            "issue",
            "create",
            "--repo",
            args.catalog_repo,
            "--title",
            args.title,
            "--body",
            body,
            "--label",
            "task-api-enhancement",
            "--label",
            "needs-triage",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"ERROR: Failed to create issue:\n{result.stderr}", file=sys.stderr)
        sys.exit(result.returncode)

    issue_url = result.stdout.strip()
    try:
        issue_number = int(issue_url.rstrip("/").split("/")[-1])
    except ValueError:
        issue_number = 0

    print(f"Issue created: {issue_url}")

    # ── Update tracker ────────────────────────────────────────────────────────
    tracker = json.loads(tracker_file.read_text(encoding="utf-8"))
    entry = {
        "issue_number": issue_number,
        "issue_url": issue_url,
        "title": args.title,
        "skill": args.skill_name,
        "catalog_repo": args.catalog_repo,
        "enhancement": "bulk-add-comment",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "status": "open",
    }
    tracker.setdefault("requests", []).append(entry)
    tracker_file.write_text(json.dumps(tracker, indent=2), encoding="utf-8")

    print(f"Recorded in {tracker_file} (issue #{issue_number}).")
    print("\nCommit and push the tracker:")
    print("  git add skill-improvement-log.json")
    print(f'  git commit -m "track: upstream issue #{issue_number} \u2013 {args.title}"')
    print("  git push")


if __name__ == "__main__":
    main()
