---
name: project-orchestrator
description: Manage large projects and task backlogs across multiple repos using a file-backed project hub that Codex can read and update from any repo.
---

# Project Orchestrator

Use this skill when work spans multiple repositories, multiple milestones, or more than one session.

## Goal

Create a Codex-readable project hub that lives outside any single repo and can track:

- projects
- milestones
- tasks
- repo ownership
- status
- dependencies
- decisions

## Default Hub

Use `CODEX_PM_HOME` if it is set.

Otherwise default to:

```text
~/codex-projects
```

## Expected Structure

```text
~/codex-projects/
  README.md
  projects/
    PROJECT-<slug>.md
  tasks/
    TASK-<id>.md
  repos/
    <repo-alias>.md
  decisions/
    DECISION-<id>.md
  templates/
    project-template.md
    task-template.md
    repo-template.md
```

## Workflow

1. Create or update the project hub before touching multiple repos.
2. Keep each task atomic enough to belong to one repo or one clear cross-repo milestone.
3. Record dependencies explicitly instead of burying them in prose.
4. Use task IDs consistently in commit messages, branch names, and PR descriptions when practical.
5. Prefer one controller thread per active task, but keep project state in the hub.

## Task File Requirements

Each task file should include:

- task id
- title
- status
- owning repo
- related repos
- priority
- dependencies
- acceptance criteria
- notes for the next session

## Repo File Requirements

Each repo file should include:

- local path
- default branch
- project memberships
- active task IDs
- key setup commands
- important local URLs or ports if relevant

## Guardrails

- Do not use the hub as a dump for raw chat logs.
- Prefer concise durable state.
- If a task becomes too broad, split it into smaller task files.
- If external PM tooling is unavailable, the file-backed hub remains the source of truth.

## Related Skill

If the user wants a board/wiki system outside local files, also use `external-pm-sync`.
