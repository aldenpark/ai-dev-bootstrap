# Decisions

## Accepted

### Agent Split

- `codex/` uses `spec-kit` as the preferred structure and planning layer
- `claude/` uses `task-master` as the preferred execution and backlog layer

### Shared Tooling

- `Context7`, `Repomix`, and `Promptfoo` are shared add-ons that help both workflows
- `Context7` is part of the default installer/config path for both agent setups
- `Promptfoo` starts as a repo-local eval scaffold under `evals/`, not a fully automated pipeline
- Aider is not the main workflow here, but its `repo map` and `automatic verification` ideas are worth borrowing

### Memory Strategy

- keep the official MCP memory server as the primary structured memory backend
- use file-based memory for human-readable repo state and decision logging
- do not add a second heavy memory system yet

### File-Based Memory

- `CURRENT_STATE.md` tracks what is implemented and what is next
- `DECISIONS.md` tracks stable choices that future sessions should not rediscover from scratch
