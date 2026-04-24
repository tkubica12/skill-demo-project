"""Run the painful baseline scenario: add-comment on every waiting-for-response task.

Each iteration spawns a new Python process + opens a new TCP connection –
this is the SLOW path that motivates the bulk-add-comment enhancement.

Usage:
    uv run run-baseline
    uv run run-baseline --api-url https://my-app.azurecontainerapps.io
    uv run run-baseline --comment "Any update?" --status waiting-for-response
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

from demo._common import find_python, resolve_api_url, resolve_cli_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Baseline: add-comment on every waiting-for-response task (one process per task)."
    )
    parser.add_argument("--api-url", default="", help="Task API base URL.")
    parser.add_argument("--status", default="waiting-for-response")
    parser.add_argument(
        "--comment",
        default="Following up \u2013 please provide a status update.",
    )
    args = parser.parse_args()

    api_url = resolve_api_url(args.api_url)
    cli_path = resolve_cli_path()
    if not cli_path:
        sys.exit(1)

    python = find_python()

    print("\n=== Baseline Scenario ===")
    print(f"Fetching tasks with status '{args.status}' from {api_url} ...")

    try:
        with urllib.request.urlopen(
            f"{api_url}/tasks?status={args.status}", timeout=10
        ) as resp:
            tasks = json.loads(resp.read())
    except Exception as exc:
        print(f"ERROR: Cannot reach API at {api_url}: {exc}", file=sys.stderr)
        print("Start it first:  uv run start-mock-api", file=sys.stderr)
        sys.exit(1)

    if not tasks:
        print(f"No tasks with status '{args.status}'. Nothing to do.")
        return

    print(
        f"Found {len(tasks)} task(s). Commenting on each via the installed CLI "
        f"(baseline \u2013 one process per task) ..."
    )

    env = {**os.environ, "TASK_API_URL": api_url}
    start = time.monotonic()

    for task in tasks:
        tid = task["id"]
        print(f"  \u2192 python task_cli.py add-comment {tid} ...", end="", flush=True)
        result = subprocess.run(
            [python, str(cli_path), "add-comment", tid, args.comment],
            env=env,
            capture_output=True,
        )
        if result.returncode != 0:
            print(f" FAILED (exit {result.returncode})")
        else:
            print(" done")

    elapsed = round(time.monotonic() - start, 3)

    print(f"\n=== Baseline complete ===")
    print(f"Tasks processed : {len(tasks)}")
    print(f"Elapsed         : {elapsed}s")
    print(
        "\nCompare with the experiment:\n"
        "  uv run apply-experiment\n"
        "  uv run benchmark --phase after"
    )


if __name__ == "__main__":
    main()
