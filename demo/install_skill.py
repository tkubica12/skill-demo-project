"""Install the shared task-api-helper skill from the central catalog.

Usage:
    uv run install-skill
    uv run install-skill --catalog-repo myorg/catalog --skill-name my-skill
"""
from __future__ import annotations

import argparse
import subprocess
import sys

from demo._common import repo_root


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Install the shared task-api-helper skill via 'gh skill install'."
    )
    parser.add_argument("--catalog-repo", default="tkubica12/skills-demo-catalog")
    parser.add_argument("--skill-name", default="task-api-helper")
    args = parser.parse_args()

    print(f"Installing skill '{args.skill_name}' from '{args.catalog_repo}' ...")
    result = subprocess.run(
        ["gh", "skill", "install", args.catalog_repo, args.skill_name]
    )
    if result.returncode != 0:
        print(
            f"ERROR: gh skill install failed (exit {result.returncode}).",
            file=sys.stderr,
        )
        sys.exit(result.returncode)

    cli = (
        repo_root()
        / ".agents"
        / "skills"
        / "task-api-helper"
        / "scripts"
        / "task_cli.py"
    )
    print(f"\nSkill '{args.skill_name}' installed successfully.")
    print(f"\nCLI path:  {cli}")
    print("\nInvoke via Python (NOT as a global shell command):")
    print(f"  TASK_API_URL=http://localhost:8080 python \"{cli}\" list-tasks")
    print(f"  TASK_API_URL=http://localhost:8080 python \"{cli}\" get-task <id>")
    print(f"  TASK_API_URL=http://localhost:8080 python \"{cli}\" add-comment <id> <text>")


if __name__ == "__main__":
    main()
