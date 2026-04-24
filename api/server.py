"""
Mock Task REST API – uses Python standard library only.

Endpoints:
  GET  /tasks                    List all tasks (optional ?status=<s>)
  GET  /tasks/<id>               Get one task by ID
  POST /tasks/<id>/comments      Add a comment  { "text": "..." }

Usage:
  python server.py [--port 8080] [--host 127.0.0.1] [--data seed_data.json]
"""

import argparse
import json
import os
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

# ---------------------------------------------------------------------------
# In-memory store (initialised from seed_data.json on startup)
# ---------------------------------------------------------------------------
TASKS: dict[str, dict] = {}


def load_seed(path: str) -> None:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for task in data.get("tasks", []):
        TASKS[task["id"]] = task
    print(f"[API] Loaded {len(TASKS)} tasks from {path}")


# ---------------------------------------------------------------------------
# Request handler
# ---------------------------------------------------------------------------
class TaskHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # noqa: N802
        print(f"[API] {self.address_string()} – {fmt % args}")

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------
    def _send_json(self, code: int, payload) -> None:
        body = json.dumps(payload, indent=2, default=str).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, code: int, message: str) -> None:
        self._send_json(code, {"error": message})

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {}

    def _parse_path(self):
        parsed = urlparse(self.path)
        return parsed.path.rstrip("/"), parse_qs(parsed.query)

    # -----------------------------------------------------------------------
    # GET
    # -----------------------------------------------------------------------
    def do_GET(self):  # noqa: N802
        path, qs = self._parse_path()

        # GET /tasks
        if path == "/tasks":
            status_filter = qs.get("status", [None])[0]
            tasks = list(TASKS.values())
            if status_filter:
                tasks = [t for t in tasks if t.get("status") == status_filter]
            self._send_json(200, tasks)
            return

        # GET /tasks/<id>
        if path.startswith("/tasks/"):
            task_id = path[len("/tasks/"):]
            if "/" not in task_id and task_id in TASKS:
                self._send_json(200, TASKS[task_id])
                return
            self._send_error(404, f"Task '{task_id}' not found")
            return

        # Health check
        if path in ("/", "/health"):
            self._send_json(200, {"status": "ok", "tasks": len(TASKS)})
            return

        self._send_error(404, "Not found")

    # -----------------------------------------------------------------------
    # POST
    # -----------------------------------------------------------------------
    def do_POST(self):  # noqa: N802
        path, _ = self._parse_path()

        # POST /tasks/<id>/comments
        if path.startswith("/tasks/") and path.endswith("/comments"):
            parts = path.split("/")
            # /tasks/<id>/comments → parts = ['', 'tasks', '<id>', 'comments']
            if len(parts) == 4:
                task_id = parts[2]
                if task_id not in TASKS:
                    self._send_error(404, f"Task '{task_id}' not found")
                    return
                body = self._read_body()
                text = body.get("text", "").strip()
                if not text:
                    self._send_error(400, "'text' field is required")
                    return
                comment = {
                    "id": f"c-{uuid.uuid4().hex[:8]}",
                    "author": body.get("author", "agent"),
                    "text": text,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                }
                TASKS[task_id].setdefault("comments", []).append(comment)
                self._send_json(201, comment)
                return

        self._send_error(404, "Not found")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Mock Task REST API")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument(
        "--data",
        default=os.path.join(os.path.dirname(__file__), "seed_data.json"),
        help="Path to seed JSON file",
    )
    args = parser.parse_args()

    load_seed(args.data)

    server = HTTPServer((args.host, args.port), TaskHandler)
    print(f"[API] Listening on http://{args.host}:{args.port}")
    print("[API] Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[API] Stopped")
        server.server_close()


if __name__ == "__main__":
    main()
