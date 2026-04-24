"""Check whether tracked issues in skill-improvement-log.json have been closed.

Usage:
    uv run check-issues
    uv run check-issues --update-file
    uv run check-issues --update-file --auto-clean
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys

from demo._common import repo_root


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Check GitHub state of issues in skill-improvement-log.json."
    )
    parser.add_argument(
        "--update-file",
        action="store_true",
        help="Write resolved/closed status back to skill-improvement-log.json.",
    )
    parser.add_argument(
        "--auto-clean",
        action="store_true",
        help="Remove resolved entries from the tracker (requires --update-file).",
    )
    args = parser.parse_args()

    root = repo_root()
    tracker_file = root / "skill-improvement-log.json"
    tracker = json.loads(tracker_file.read_text(encoding="utf-8"))
    requests: list = tracker.get("requests", [])

    if not requests:
        print("No tracked issues in skill-improvement-log.json.")
        return

    print(f"Checking {len(requests)} tracked issue(s) ...\n")
    changed = False

    for req in requests:
        state = "UNKNOWN"
        closed_at = ""
        try:
            result = subprocess.run(
                [
                    "gh",
                    "issue",
                    "view",
                    str(req["issue_number"]),
                    "--repo",
                    req["catalog_repo"],
                    "--json",
                    "state,closedAt",
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            info = json.loads(result.stdout)
            state = info.get("state", "UNKNOWN")
            closed_at = info.get("closedAt", "")
        except Exception as exc:
            state = f"UNKNOWN (error: {exc})"

        symbol = {"OPEN": "\U0001f534", "CLOSED": "\u2705"}.get(state, "\u2753")
        print(f"{symbol}  #{req['issue_number']} [{req['status']}] \u2013 {req['title']}")
        print(f"     {req['issue_url']}")
        print(f"     GitHub state: {state}\n")

        if args.update_file and state == "CLOSED" and req.get("status") != "resolved":
            req["status"] = "resolved"
            req["closed_at"] = closed_at
            changed = True
            print("  \u2192 Marked resolved in tracker.")

    if args.update_file and args.auto_clean:
        before = len(requests)
        tracker["requests"] = [r for r in requests if r.get("status") != "resolved"]
        removed = before - len(tracker["requests"])
        if removed:
            print(f"Removed {removed} resolved entry(ies) from tracker.")
            changed = True

    if args.update_file and changed:
        tracker_file.write_text(json.dumps(tracker, indent=2), encoding="utf-8")
        print(f"Tracker updated: {tracker_file}")
        print("Commit and push:")
        print(
            "  git add skill-improvement-log.json"
            " && git commit -m 'tracker: update issue status'"
            " && git push"
        )
    elif args.update_file:
        print("No changes \u2013 all tracked statuses already up to date.")


if __name__ == "__main__":
    main()
