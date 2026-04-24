# skill-demo-project

A consuming project that demonstrates how a team uses a **centrally managed shared GitHub Copilot skill** and persists enhancement issue links so that every session and every teammate can see what has been requested from the central catalog.

---

## The Story

Your organisation maintains a **central skill catalog** (`tkubica12/skills-demo-catalog`).  
One of its published skills is `release-readiness-check`, which Copilot uses to verify that a repo is ready to ship (changelog updated, tests passing, docs current, etc.).

Individual product teams **install** that skill project-scope instead of copy-pasting it.  
When a team finds a gap in the shared skill they:

1. **File an enhancement issue** in the central catalog repo.
2. **Record the issue link** in this project's `skill-enhancement-tracker.json`.
3. **Push the updated tracker** so teammates and future Copilot sessions can see the pending request without having to search GitHub.
4. When the catalog maintainers ship a new skill version, the team **checks** whether tracked requests were resolved and cleans the tracker.

---

## Repository layout

```
skill-demo-project/
├── README.md
├── skill-enhancement-tracker.json   # persisted enhancement links (committed)
└── scripts/
    ├── Install-SharedSkill.ps1        # install the shared skill project-scope
    ├── New-SkillEnhancement.ps1       # file an issue + persist the link
    ├── Get-SkillEnhancementStatus.ps1 # check whether tracked issues are resolved
    └── Remove-SkillEnhancement.ps1    # remove a stale/resolved entry from the tracker
```

---

## Quick-start command sequence

### 1 – Install the shared skill (once per clone)

```powershell
.\scripts\Install-SharedSkill.ps1
```

This calls `gh skill install tkubica12/skills-demo-catalog release-readiness-check` and makes the skill available inside this repo's Copilot sessions.

---

### 2 – Request an enhancement in the central catalog

When you (or a Copilot agent) identify a gap:

```powershell
.\scripts\New-SkillEnhancement.ps1 `
    -Title "Add LICENSE file check to release-readiness-check" `
    -Body  "The skill currently does not verify that a LICENSE file is present at the repo root."
```

This will:
- Create a GitHub issue in `tkubica12/skills-demo-catalog` labelled `skill-enhancement` and `needs-triage`.
- Append the issue number, URL, title, skill name, and timestamp to `skill-enhancement-tracker.json`.
- Print the `git` command to commit and push the updated tracker.

After running the script, commit the tracker:

```powershell
git add skill-enhancement-tracker.json
git commit -m "track: skill enhancement #<N>"
git push
```

---

### 3 – Check the status of tracked requests

```powershell
# Just print the status:
.\scripts\Get-SkillEnhancementStatus.ps1

# Print AND update the tracker file for resolved issues:
.\scripts\Get-SkillEnhancementStatus.ps1 -UpdateFile
```

---

### 4 – Remove a tracked request (demo reset / cleanup)

```powershell
.\scripts\Remove-SkillEnhancement.ps1 -IssueNumber 42
```

Then commit and push as instructed by the script output.

---

## skill-enhancement-tracker.json format

```json
{
  "description": "Tracks enhancement requests submitted to the central skill catalog.",
  "enhancements": [
    {
      "issue_number": 42,
      "issue_url":    "https://github.com/tkubica12/skills-demo-catalog/issues/42",
      "title":        "Add LICENSE file check",
      "skill":        "release-readiness-check",
      "catalog_repo": "tkubica12/skills-demo-catalog",
      "created_at":   "2025-07-01T09:00:00Z",
      "status":       "open"
    }
  ]
}
```

Fields updated automatically by `Get-SkillEnhancementStatus.ps1 -UpdateFile`:

| Field       | Value when resolved |
|-------------|---------------------|
| `status`    | `"resolved"`        |
| `closed_at` | ISO-8601 timestamp  |

---

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `gh auth login`.
- PowerShell 7+ (works on Windows, macOS, Linux).
- Access to `tkubica12/skills-demo-catalog` (read for status checks, write for new issues).
