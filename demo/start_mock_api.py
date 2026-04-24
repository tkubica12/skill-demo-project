"""Start the mock Task REST API.

Usage:
    uv run start-mock-api                      # background process
    uv run start-mock-api --foreground          # foreground (blocking)
    uv run start-mock-api --port 9090
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
import urllib.request

from demo._common import find_python, repo_root


def main() -> None:
    parser = argparse.ArgumentParser(description="Start the mock Task REST API.")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument(
        "--foreground",
        action="store_true",
        help="Run in the foreground (blocking). Default: background.",
    )
    args = parser.parse_args()

    server_py = repo_root() / "api" / "server.py"
    if not server_py.exists():
        print(f"ERROR: Cannot find api/server.py at {server_py}", file=sys.stderr)
        sys.exit(1)

    python = find_python()
    cmd = [python, str(server_py), "--port", str(args.port), "--host", args.host]

    print(f"Starting Mock Task API on http://{args.host}:{args.port} ...")

    if args.foreground:
        subprocess.run(cmd)
        return

    # Background
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    time.sleep(2)
    try:
        with urllib.request.urlopen(
            f"http://{args.host}:{args.port}/health", timeout=3
        ) as resp:
            print(f"API is up: {resp.read().decode().strip()}")
    except Exception as exc:
        print(f"WARNING: API did not respond within 2 s: {exc}")

    print(f"\nBackground PID : {proc.pid}")
    print(f"Stop on Linux/macOS : kill {proc.pid}")
    print(f"Stop on Windows     : taskkill /PID {proc.pid} /F")
    print(f"\nVerify: curl http://{args.host}:{args.port}/health")


if __name__ == "__main__":
    main()
