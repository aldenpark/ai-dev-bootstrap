# Decisions

## Accepted

### Agent Split

- `codex/` uses `spec-kit` as the preferred structure and planning layer
- `claude/` uses `spec-kit` (GitHub Spec Kit `specify` CLI) as the planning layer, with `sequential-thinking` MCP for in-session decomposition

### Shared Tooling

- `Context7`, `Repomix`, and `Promptfoo` are shared add-ons that help both workflows
- `Context7` is part of the default installer/config path for both agent setups
- `Promptfoo` starts as a repo-local eval scaffold under `evals/`, not a fully automated pipeline
- Aider is not the main workflow here, but its `repo map` and `automatic verification` ideas are worth borrowing

### GitHub MCP Authentication

- GitHub MCP uses a Personal Access Token (PAT), not OAuth/GitHub App
- PAT is stored in `~/.claude.json` as a Bearer token header
- PAT is also persisted to `~/.zprofile` as `GITHUB_PAT` for env-based detection on re-runs
- the installer auto-detects existing PATs before prompting

### Global vs Project Install

- `--global` is the recommended Claude install mode
- global writes MCP servers to `~/.claude.json`, rules to `~/.claude/CLAUDE.md`, VS Code user settings
- project-only writes to `.mcp.json` and `.vscode/mcp.json` in the repo
- global CLAUDE.md template lives at `claude/templates/global-CLAUDE.md` in this repo

### Modular Rules and Skills

- global CLAUDE.md now uses `@rules/` references instead of inline content
- rules are split into focused files: communication, code-style, testing, git
- skills are language-specific convention files: frontend, python, csharp
- installer copies both rules and skills during `--global` install
- `--skip-rules` and `--skip-skills` flags available for users who want their own

### Optional Plugins

- optional plugins are opt-in via `--with-*` flags, not installed by default
- MemPalace (`--with-mempalace`): persistent memory palace using ChromaDB, stores verbatim content
- Caveman (`--with-caveman`): terse output mode, ~75% token savings
- Atlassian (`--with-atlassian`): Jira, Confluence, Compass via OAuth 2.1 — auth handled on first use via `/mcp`
- Azure DevOps (`--with-ado`): work items, repos, PRs via `@azure-devops/mcp` — requires org name
- plugins are installed via the Claude Code plugin marketplace; MCP servers via `claude mcp add`

### Memory Strategy

- keep the official MCP memory server as the primary structured memory backend
- use file-based memory for human-readable repo state and decision logging
- MemPalace is available as an optional upgrade for users who want richer memory

### File-Based Memory

- `CURRENT_STATE.md` tracks what is implemented and what is next
- `DECISIONS.md` tracks stable choices that future sessions should not rediscover from scratch
