"""Benchmark the baseline loop vs. the bulk-add-comment experiment.

Phases:
  before  – times the per-task loop (one CLI process per task).
  after   – times the single bulk-add-comment call (experiment must be applied).
  compare – prints a side-by-side summary from the two saved JSON files.

Usage:
    uv run benchmark --phase before
    uv run benchmark --phase after
    uv run benchmark --phase compare
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone

from demo._common import find_python, repo_root, resolve_api_url, resolve_cli_path


def _fetch_tasks(api_url: str, status: str) -> list:
    with urllib.request.urlopen(
        f"{api_url}/tasks?status={status}", timeout=10
    ) as resp:
        return json.loads(resp.read())


def _measure_baseline(
    tasks: list, api_url: str, comment: str, cli_path, python: str
) -> float:
    env = {**os.environ, "TASK_API_URL": api_url}
    start = time.monotonic()
    for task in tasks:
        subprocess.run(
            [python, str(cli_path), "add-comment", task["id"], comment],
            env=env,
            capture_output=True,
        )
    return time.monotonic() - start


def _measure_bulk(
    api_url: str, status: str, comment: str, cli_path, python: str
) -> float:
    start = time.monotonic()
    subprocess.run(
        [
            python,
            str(cli_path),
            "bulk-add-comment",
            "--status",
            status,
            "--comment",
            comment,
            "--api-url",
            api_url,
        ],
        capture_output=True,
    )
    return time.monotonic() - start


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark baseline vs. experiment.")
    parser.add_argument(
        "--phase",
        choices=["before", "after", "compare"],
        default="before",
    )
    parser.add_argument("--api-url", default="", help="Task API base URL.")
    parser.add_argument("--status", default="waiting-for-response")
    parser.add_argument("--comment", default="Benchmark ping")
    args = parser.parse_args()

    root = repo_root()

    # ── compare ──────────────────────────────────────────────────────────────
    if args.phase == "compare":
        before_file = root / "benchmark-results-before.json"
        after_file = root / "benchmark-results-after.json"
        if not before_file.exists() or not after_file.exists():
            print(
                "ERROR: Run --phase before and --phase after first.", file=sys.stderr
            )
            sys.exit(1)
        before = json.loads(before_file.read_text())
        after = json.loads(after_file.read_text())
        saving = round(before["elapsed_seconds"] - after["elapsed_seconds"], 3)
        pct = (
            round((saving / before["elapsed_seconds"]) * 100, 1)
            if before["elapsed_seconds"]
            else 0
        )
        print("\n=== Benchmark Comparison ===")
        print(
            f"Before (baseline loop)    : {before['elapsed_seconds']:8.3f}s"
            f"  ({before['task_count']} tasks)"
        )
        print(
            f"After  (bulk-add-comment) : {after['elapsed_seconds']:8.3f}s"
            f"  ({after['task_count']} tasks)"
        )
        print(f"Saved                     : {saving:8.3f}s  ({pct}% faster)")
        return

    # ── before / after ───────────────────────────────────────────────────────
    api_url = resolve_api_url(args.api_url)

    try:
        tasks = _fetch_tasks(api_url, args.status)
    except Exception as exc:
        print(f"ERROR: Cannot reach API at {api_url}: {exc}", file=sys.stderr)
        print("Start it:  uv run start-mock-api", file=sys.stderr)
        sys.exit(1)

    print(f"\n=== Benchmark: phase={args.phase}, tasks={len(tasks)} ===")

    cli_path = resolve_cli_path()
    if not cli_path:
        sys.exit(1)
    python = find_python()

    if args.phase == "before":
        print("Timing baseline loop (one CLI process per task) ...")
        elapsed = _measure_baseline(tasks, api_url, args.comment, cli_path, python)
    else:
        # Verify bulk-add-comment is available (experiment must be applied)
        probe = subprocess.run(
            [python, str(cli_path), "bulk-add-comment", "--help"],
            capture_output=True,
            text=True,
        )
        if probe.returncode != 0 or "bulk-add-comment" not in (probe.stdout + probe.stderr):
            print(
                "ERROR: bulk-add-comment not found. Apply the experiment first:",
                file=sys.stderr,
            )
            print("  uv run apply-experiment", file=sys.stderr)
            sys.exit(1)
        print("Timing bulk-add-comment (single invocation) ...")
        elapsed = _measure_bulk(api_url, args.status, args.comment, cli_path, python)

    result = {
        "phase": args.phase,
        "task_count": len(tasks),
        "status_filter": args.status,
        "elapsed_seconds": round(elapsed, 3),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    out_file = root / f"benchmark-results-{args.phase}.json"
    out_file.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(f"Elapsed: {result['elapsed_seconds']}s")
    print(f"Results saved to: {out_file}")
    next_phase = "after" if args.phase == "before" else "compare"
    print(f"\nNext:  uv run benchmark --phase {next_phase}")


if __name__ == "__main__":
    main()
