"""Shared utilities for the skill-demo CLI tools."""
from __future__ import annotations

import os
import shutil
import sys
from pathlib import Path


def repo_root() -> Path:
    """Return the repository root (two levels up from this file)."""
    return Path(__file__).resolve().parent.parent


def resolve_api_url(url: str = "") -> str:
    """Return the active Task API base URL (no trailing slash)."""
    url = (url or os.environ.get("TASK_API_URL", "")).strip().rstrip("/")
    if url:
        print(f"API URL (from TASK_API_URL): {url}", flush=True)
    else:
        url = "http://localhost:8080"
        print(f"TASK_API_URL not set – using local mock: {url}", flush=True)
        print("  Set TASK_API_URL to switch to a deployed endpoint:", flush=True)
        print("    export TASK_API_URL=https://<your-app>.azurecontainerapps.io", flush=True)
    return url


def resolve_cli_path() -> Path | None:
    """Return the installed task_cli.py path, or None with an error message."""
    cli = (
        repo_root()
        / ".agents"
        / "skills"
        / "task-api-helper"
        / "scripts"
        / "task_cli.py"
    )
    if not cli.exists():
        print("ERROR: Installed skill CLI not found at:", file=sys.stderr)
        print(f"  {cli}", file=sys.stderr)
        print("Install the shared skill first:  uv run install-skill", file=sys.stderr)
        return None
    return cli


def find_python() -> str:
    """Return the Python executable (python or python3)."""
    for name in ("python", "python3"):
        exe = shutil.which(name)
        if exe:
            return exe
    print("ERROR: Python not found on PATH.", file=sys.stderr)
    sys.exit(1)
