"""Decepticon entry point: `decepticon` or `python -m decepticon`.

Starts all Docker services and opens the interactive CLI — the same
environment that open-source users get via the bash launcher.

For development with hot-reload, use `make dev` + `make cli` instead.
"""

from __future__ import annotations

import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# ── Colors ───────────────────────────────────────────────────────
DIM = "\033[0;2m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
BOLD = "\033[1m"
NC = "\033[0m"


def _find_project_root() -> Path:
    """Locate the repo root containing docker-compose.yml."""
    candidate = Path(__file__).resolve().parent.parent
    if (candidate / "docker-compose.yml").exists():
        return candidate
    cwd = Path.cwd()
    if (cwd / "docker-compose.yml").exists():
        return cwd
    print(f"{RED}Error: docker-compose.yml not found.{NC}")
    print(f"{DIM}Run from the repo root, or use the bash launcher if installed via curl|bash.{NC}")
    sys.exit(1)


def _compose(root: Path) -> list[str]:
    """Base docker compose command."""
    cmd = ["docker", "compose", "--project-directory", str(root)]
    env_file = root / ".env"
    if env_file.exists():
        cmd.extend(["--env-file", str(env_file)])
    return cmd


def _wait_for_server(port: int = 2024, timeout: int = 90) -> bool:
    """Block until LangGraph server is ready."""
    waited = 0
    print(f"{DIM}Waiting for LangGraph server", end="", flush=True)
    while waited < timeout:
        try:
            req = urllib.request.Request(
                f"http://localhost:{port}/assistants/search",
                data=b'{"graph_id":"decepticon","limit":1}',
                headers={"Content-Type": "application/json"},
            )
            resp = urllib.request.urlopen(req, timeout=2)
            if b"decepticon" in resp.read():
                print(f" {GREEN}ready{NC}")
                return True
        except (urllib.error.URLError, OSError):
            pass
        print(".", end="", flush=True)
        time.sleep(2)
        waited += 2
    print(f"{NC}\n{RED}Server failed to start within {timeout}s.{NC}")
    return False


def main() -> None:
    """Start services and open CLI — identical to production."""
    root = _find_project_root()
    compose = _compose(root)

    print(f"{DIM}Building and starting services...{NC}")
    subprocess.run([*compose, "up", "-d", "--build"], capture_output=True)

    if not _wait_for_server():
        print(f"{DIM}Check logs: {BOLD}make logs{NC}")
        sys.exit(1)

    subprocess.run([*compose, "--profile", "cli", "run", "--rm", "cli"])


if __name__ == "__main__":
    main()
