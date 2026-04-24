"""Restore the installed skill from the local snapshot.

Reads snapshots/latest_snapshot.txt to find the original entry-point and
snapshot paths, then copies the snapshot back.  Falls back to re-installing
the skill if no snapshot exists.

Usage:
    uv run reset-skill
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from demo._common import repo_root


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Restore the installed skill CLI from its local snapshot."
    )
    parser.parse_args()

    root = repo_root()
    snap_dir = root / "snapshots"
    pointer_file = snap_dir / "latest_snapshot.txt"

    if not pointer_file.exists():
        print("WARNING: No snapshot pointer found.")
        print("Either the experiment was never applied, or snapshots/ was cleaned.")
        print("\nRe-install the skill to restore a clean state:")
        print("  uv run install-skill")
        return

    lines = pointer_file.read_text(encoding="utf-8").splitlines()
    entry_point = Path(lines[0].strip())
    snapshot_path = Path(lines[1].strip())

    if not snapshot_path.exists():
        print(
            f"ERROR: Snapshot file not found: {snapshot_path}", file=sys.stderr
        )
        print("Re-install the skill:  uv run install-skill", file=sys.stderr)
        sys.exit(1)

    print(f"Restoring {entry_point} from {snapshot_path} ...")
    shutil.copy2(snapshot_path, entry_point)

    pointer_file.unlink(missing_ok=True)

    print("Local skill restored to original state.")
    print("The experiment is no longer active.")


if __name__ == "__main__":
    main()
