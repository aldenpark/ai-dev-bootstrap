# Current State

## Repo Purpose

This repo is building a repeatable AI coding environment for:

- `Codex` with a `spec-kit`-oriented workflow
- `Claude` with a `task-master`-oriented workflow
- shared MCP and workflow add-ons that improve both

## Implemented

- Codex installer and workflow docs
- Claude installer and workflow docs
- synced top-level setup guide in `Local AI Coding Environment Setup.md`
- Context7 added to the Codex and Claude installer/config path
- shared documentation for Context7, Repomix, Promptfoo, and Aider-inspired patterns
- repo-local agent instructions in `AGENTS.md` and `CLAUDE.md`, including Context7 guidance and file-based memory usage
- starter eval scaffold in `evals/`
- file-based repo memory in `CURRENT_STATE.md` and `DECISIONS.md`

## Current Recommendations

- use `Context7` first
- use `Promptfoo` second
- use `Repomix` on demand
- add repo maps and automatic verification after the shared workflow is stable

## Next Likely Work

- install and validate `Context7`
- expand `evals/` with real project-specific tasks
- decide how much of `spec-kit` and `task-master` should be automated in this repo
