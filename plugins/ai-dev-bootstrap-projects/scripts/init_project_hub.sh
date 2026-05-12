#!/usr/bin/env bash
set -euo pipefail

hub_root="${1:-${CODEX_PM_HOME:-$HOME/codex-projects}}"

mkdir -p \
  "$hub_root/projects" \
  "$hub_root/tasks" \
  "$hub_root/repos" \
  "$hub_root/decisions" \
  "$hub_root/templates"

if [ ! -f "$hub_root/README.md" ]; then
  cat > "$hub_root/README.md" <<'EOF'
# Codex Project Hub

Cross-repo project and task state for Codex.

Use this hub for durable planning state that should survive individual repo sessions.
EOF
fi

if [ ! -f "$hub_root/templates/project-template.md" ]; then
  cat > "$hub_root/templates/project-template.md" <<'EOF'
# PROJECT-<slug>

- Title:
- Status:
- Owner:
- Repos:
- Milestones:
- External PM Link:

## Goals

## Current Milestone

## Active Tasks

## Decisions
EOF
fi

if [ ! -f "$hub_root/templates/task-template.md" ]; then
  cat > "$hub_root/templates/task-template.md" <<'EOF'
# TASK-<id>

- Title:
- Status:
- Priority:
- Owning Repo:
- Related Repos:
- Dependencies:
- External Link:

## Acceptance Criteria

## Notes
EOF
fi

if [ ! -f "$hub_root/templates/repo-template.md" ]; then
  cat > "$hub_root/templates/repo-template.md" <<'EOF'
# <repo-alias>

- Local Path:
- Default Branch:
- Projects:
- Active Tasks:
- Key Commands:
- Important URLs:
EOF
fi

printf 'Initialized project hub at %s\n' "$hub_root"
