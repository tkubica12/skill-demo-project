"""Resolve and print the active Task API URL.

Usage:
    uv run get-api-url
    uv run get-api-url --url https://my-app.azurecontainerapps.io
"""
from __future__ import annotations

import argparse

from demo._common import resolve_api_url


def main() -> None:
    parser = argparse.ArgumentParser(description="Resolve the active Task API base URL.")
    parser.add_argument(
        "--url",
        default="",
        help="Explicit URL (overrides TASK_API_URL env var and localhost fallback).",
    )
    args = parser.parse_args()
    # resolve_api_url already prints the source; emit the bare URL last so
    # callers can capture it with backtick / $() substitution.
    print(resolve_api_url(args.url))


if __name__ == "__main__":
    main()
