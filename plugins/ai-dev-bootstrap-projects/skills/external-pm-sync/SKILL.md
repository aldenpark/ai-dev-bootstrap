---
name: external-pm-sync
description: Extend the file-backed Codex project hub to an external PM/wiki system, with GitHub Projects recommended first and Notion, Trello, or Confluence as optional secondary mirrors.
---

# External PM Sync

Use this skill when the user wants project and task tracking outside local files.

## Default Recommendation Order

1. `GitHub Projects` plus repo issues and docs
2. `Notion`
3. `Trello`
4. `Confluence`

## Why This Order

- `GitHub Projects` is the best fit for multi-repo engineering work because it already sits next to issues, PRs, and repos.
- `Notion` is strong when you want richer docs plus lightweight database-backed planning.
- `Trello` is simple and cheap, but weaker for engineering traceability across repos.
- `Confluence` is useful as a wiki, but its free tier is tighter and it is better paired with Jira than used alone.

## External System Policy

- Keep the local file-backed hub as the operational source of truth unless the user explicitly chooses a remote system as primary.
- Mirror only durable state externally:
  - project title
  - milestone
  - task status
  - owner
  - links to repo, issue, or PR
- Do not mirror volatile debugging notes by default.

## Recommended Free Setup

For free multi-repo use, prefer:

- `GitHub Projects` for board and roadmap views
- `GitHub Issues` for tasks
- `GitHub Docs` or repo markdown docs for the wiki layer

## Mapping Rules

Map local hub records as follows:

- `PROJECT-<slug>` -> external project or top-level page
- `TASK-<id>` -> issue, card, or database row
- `DECISION-<id>` -> wiki page, doc, or linked decision note

## Guardrails

- Do not create the same backlog in two external systems unless the user explicitly wants duplication.
- If an external system has connector friction, keep local files primary and use exported links only.
- For cross-repo engineering work, avoid Trello as the sole source of truth if you need PR and issue traceability.
