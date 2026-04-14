# Current State

## Repo Purpose

This repo is building a repeatable AI coding environment for:

- `Codex` with a `spec-kit`-oriented workflow
- `Claude` with a `spec-kit`-oriented workflow (GitHub Spec Kit)
- shared MCP and workflow add-ons that improve both

## Implemented

- Codex installer and workflow docs
- Claude installer and workflow docs
- Claude `--global` install: MCP servers to `~/.claude.json`, global rules to `~/.claude/CLAUDE.md`, VS Code user settings
- Claude MCP servers: memory, context7, sequential-thinking, playwright, github (PAT-based)
- GitHub Spec Kit (`specify` CLI) installed globally via `uv` for spec-driven development
- Modular global CLAUDE.md template using `@rules/` references instead of inline content
- Modular rules templates: communication, code-style, testing, git (`claude/templates/rules/`)
- Skills: frontend, python, csharp, review, mine-learnings (`claude/templates/skills/`)
- Custom agents: ado-manager (`claude/templates/agents/`)
- Installer copies rules to `~/.claude/rules/` and skills to `~/.claude/skills/` on `--global` install
- Optional plugin support: `--with-mempalace`, `--with-caveman` installer flags
- Optional MCP server support: `--with-atlassian` (OAuth), `--with-ado` (PAT-based) installer flags
- GitHub PAT auto-detection (env var > existing config > interactive prompt > skip)
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

- expand `evals/` with real project-specific tasks
- validate `specify` workflow end-to-end on a real feature
- add Codex `--global` install support to match Claude installer
- add more optional plugins as the ecosystem grows
- add hooks templates for common automation patterns
