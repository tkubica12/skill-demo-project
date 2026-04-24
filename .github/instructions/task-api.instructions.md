---
applyTo: "api/**"
---
# Task API Instructions

The mock API (`api/server.py`) uses Python's standard library only (`http.server`, `json`, `urllib.parse`).
Do **not** add third-party dependencies to the API server.

## Data Model

```json
{
  "id": "string",
  "title": "string",
  "status": "open | in-progress | waiting-for-response | resolved | closed",
  "assignee": "string",
  "created_at": "ISO-8601",
  "comments": [
    { "id": "string", "author": "string", "text": "string", "created_at": "ISO-8601" }
  ]
}
```

## Seed Data

Seed data lives in `api/seed_data.json`.  Always include at least three tasks
with status `waiting-for-response` so the baseline scenario is demonstrable.

## Running the Server

```bash
# via uv (recommended – multiplatform):
uv run start-mock-api          # background, port 8080
uv run start-mock-api --foreground

# or directly:
python api/server.py --port 8080
```

## Testing Endpoints Manually

```bash
# List waiting-for-response tasks
curl "http://localhost:8080/tasks?status=waiting-for-response"

# Add a comment
curl -X POST http://localhost:8080/tasks/task-001/comments \
     -H "Content-Type: application/json" \
     -d '{"text":"Following up."}'
```
