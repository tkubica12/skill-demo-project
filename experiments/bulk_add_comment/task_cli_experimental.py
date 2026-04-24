"""
Experimental task-api-helper CLI – drop-in replacement for the installed skill.

Adds `bulk-add-comment` on top of the three baseline commands.
This file lives in experiments/bulk_add_comment/ and is copied over the installed
skill entry-point by Apply-LocalExperiment.ps1.

IMPORTANT: This is temporary evidence for an upstream issue, NOT a permanent fix.
           Always run Reset-LocalSkill.ps1 after benchmarking to restore the
           original installed skill.

Usage (after Apply-LocalExperiment.ps1 has activated it):
  task-api-helper list-tasks [--status <status>] [--api-url <url>]
  task-api-helper get-task   <id>               [--api-url <url>]
  task-api-helper add-comment <id> <text>        [--api-url <url>]
  task-api-helper bulk-add-comment               [--api-url <url>]
                     (--ids <id1> [<id2>...] | --status <status>)
                     --comment <text>
"""

import argparse
import json
import sys
import urllib.error
import urllib.request
from typing import Optional

DEFAULT_API_URL = "http://localhost:8080"


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def _get(url: str) -> dict | list:
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def _post(url: str, payload: dict) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read())


def _api_error(e: urllib.error.HTTPError) -> str:
    try:
        body = json.loads(e.read())
        return body.get("error", str(e))
    except Exception:
        return str(e)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_list_tasks(api_url: str, status: Optional[str]) -> None:
    url = f"{api_url}/tasks"
    if status:
        url += f"?status={status}"
    tasks = _get(url)
    print(json.dumps(tasks, indent=2))


def cmd_get_task(api_url: str, task_id: str) -> None:
    url = f"{api_url}/tasks/{task_id}"
    try:
        task = _get(url)
        print(json.dumps(task, indent=2))
    except urllib.error.HTTPError as e:
        print(f"Error: {_api_error(e)}", file=sys.stderr)
        sys.exit(1)


def cmd_add_comment(api_url: str, task_id: str, text: str) -> None:
    url = f"{api_url}/tasks/{task_id}/comments"
    try:
        comment = _post(url, {"message": text})
        print(json.dumps(comment, indent=2))
    except urllib.error.HTTPError as e:
        print(f"Error adding comment to {task_id}: {_api_error(e)}", file=sys.stderr)
        sys.exit(1)


def cmd_bulk_add_comment(
    api_url: str,
    task_ids: list[str],
    status_filter: Optional[str],
    comment_text: str,
) -> None:
    """
    Add the same comment to multiple tasks in a single process invocation.
    Either pass explicit --ids or --status to derive the list automatically.
    """
    if status_filter and not task_ids:
        tasks = _get(f"{api_url}/tasks?status={status_filter}")
        task_ids = [t["id"] for t in tasks]

    if not task_ids:
        print("No tasks to comment on.", file=sys.stderr)
        sys.exit(1)

    results = []
    errors = []
    for tid in task_ids:
        url = f"{api_url}/tasks/{tid}/comments"
        try:
            comment = _post(url, {"message": comment_text})
            results.append({"task_id": tid, "comment": comment, "ok": True})
            print(f"  ✓ {tid}", file=sys.stderr)
        except urllib.error.HTTPError as e:
            msg = _api_error(e)
            errors.append({"task_id": tid, "error": msg})
            print(f"  ✗ {tid}: {msg}", file=sys.stderr)

    summary = {
        "total": len(task_ids),
        "succeeded": len(results),
        "failed": len(errors),
        "results": results,
        "errors": errors,
    }
    print(json.dumps(summary, indent=2))
    if errors:
        sys.exit(1)


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    # Shared parent so --api-url is accepted both before AND after the subcommand.
    url_parent = argparse.ArgumentParser(add_help=False)
    url_parent.add_argument("--api-url", default=DEFAULT_API_URL, help="Base URL of the Task API")

    parser = argparse.ArgumentParser(
        prog="task-api-helper",
        description="CLI for the Task API  (experimental: includes bulk-add-comment)",
        parents=[url_parent],
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # list-tasks
    p_list = sub.add_parser("list-tasks", help="List tasks", parents=[url_parent])
    p_list.add_argument("--status", help="Filter by status")

    # get-task
    p_get = sub.add_parser("get-task", help="Get a single task", parents=[url_parent])
    p_get.add_argument("id", help="Task ID")

    # add-comment
    p_comment = sub.add_parser("add-comment", help="Add a comment to a task", parents=[url_parent])
    p_comment.add_argument("id", help="Task ID")
    p_comment.add_argument("text", help="Comment text")

    # bulk-add-comment  (EXPERIMENTAL – the new command)
    p_bulk = sub.add_parser("bulk-add-comment", help="[EXPERIMENTAL] Add a comment to multiple tasks", parents=[url_parent])
    group = p_bulk.add_mutually_exclusive_group(required=True)
    group.add_argument("--ids", nargs="+", metavar="ID", help="Explicit task IDs")
    group.add_argument("--status", help="Derive task IDs from status filter")
    p_bulk.add_argument("--comment", required=True, help="Comment text to post")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    try:
        if args.command == "list-tasks":
            cmd_list_tasks(args.api_url, getattr(args, "status", None))
        elif args.command == "get-task":
            cmd_get_task(args.api_url, args.id)
        elif args.command == "add-comment":
            cmd_add_comment(args.api_url, args.id, args.text)
        elif args.command == "bulk-add-comment":
            cmd_bulk_add_comment(
                args.api_url,
                getattr(args, "ids", None) or [],
                getattr(args, "status", None),
                args.comment,
            )
    except urllib.error.URLError as e:
        print(f"Connection error: {e}  (is the API running?)", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
