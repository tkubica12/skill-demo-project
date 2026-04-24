"""Apply the local bulk-add-comment experiment to the installed skill.

Steps:
  1. Snapshot the installed task_cli.py to snapshots/<timestamp>_original_task_cli.py
  2. Copy experiments/bulk_add_comment/task_cli_experimental.py over the installed CLI

Usage:
    uv run apply-experiment
"""
from __future__ import annotations

import argparse
import shutil
import sys
from datetime import datetime

from demo._common import repo_root, resolve_cli_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Snapshot and patch the installed skill with the bulk-add-comment experiment."
    )
    parser.parse_args()

    root = repo_root()
    exp_src = root / "experiments" / "bulk_add_comment" / "task_cli_experimental.py"
    snap_dir = root / "snapshots"

    if not exp_src.exists():
        print(f"ERROR: Experimental file not found: {exp_src}", file=sys.stderr)
        sys.exit(1)

    cli_path = resolve_cli_path()
    if not cli_path:
        sys.exit(1)

    print(f"Installed CLI found at: {cli_path}")

    # Snapshot the original
    snap_dir.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    snapshot_path = snap_dir / f"{timestamp}_original_task_cli.py"
    shutil.copy2(cli_path, snapshot_path)
    print(f"Snapshot saved : {snapshot_path}")

    pointer_file = snap_dir / "latest_snapshot.txt"
    pointer_file.write_text(f"{cli_path}\n{snapshot_path}", encoding="utf-8")

    # Apply experiment
    shutil.copy2(exp_src, cli_path)
    print("Experiment applied: bulk-add-comment is now available.\n")
    print("Try it:")
    print(
        f'  TASK_API_URL=http://localhost:8080 python "{cli_path}" '
        f'bulk-add-comment --status waiting-for-response --comment "Ping"'
    )
    print("\nWhen done benchmarking, restore with:  uv run reset-skill")


if __name__ == "__main__":
    main()
