# ai-dev-bootstrap

Bootstrap a practical AI coding workspace with MCP-aware tools, editor integration, project memory, structured decomposition, parallel execution, current docs/search, GitHub context, and browser verification.

## Purpose

This repo is for building a repeatable local setup that improves common AI coding weaknesses:

- weak project memory
- poor task breakdown on larger features
- stale documentation answers
- weak GitHub context
- guessing about browser behavior instead of verifying it
- serial execution of independent subtasks

## Layout

- `README.md`: repo overview and navigation
- `codex/`: Codex-specific setup, docs, and installer
- `claude/`: Claude-specific setup, docs, and installer
- `shared/`: cross-agent tools and patterns that help both workflows
- `evals/`: Promptfoo starter and comparison scaffolding
- `.vscode/`: workspace-level editor configuration
- `AGENTS.md`: repo-local Codex behavior rules for this repo
- `CLAUDE.md`: repo-local Claude behavior rules for this repo

## Current Scope

Both paths are now implemented, but they are not meant to be identical.

Recommended split:

- `codex/` is optimized around `spec-kit`
- `claude/` is optimized around `spec-kit` (GitHub Spec Kit)
- `shared/` contains tools that help both, such as docs, repo-context packing, and evals

### Codex workflow

- Codex CLI and VS Code integration
- OpenAI Developer Docs MCP
- Memory MCP
- Sequential Thinking MCP
- Playwright MCP
- GitHub MCP
- recommended planning layer: `spec-kit`

### Claude workflow

- Claude Code CLI and VS Code extension
- Context7 MCP (versioned library/framework docs)
- Memory MCP (knowledge graph persistence)
- Sequential Thinking MCP (structured decomposition)
- Playwright MCP (browser verification)
- GitHub MCP (issue/PR context via PAT)
- Built-in: WebSearch, WebFetch, parallel sub-agents, worktree isolation
- Modular rules: communication, code-style, testing, git (`~/.claude/rules/`)
- Skills: frontend, python, csharp (`~/.claude/skills/`)
- Optional plugins: MemPalace (persistent memory palace), Caveman (terse output)
- Optional MCP servers: Atlassian (Jira/Confluence), Azure DevOps (work items/PRs)
- planning layer: `spec-kit` (GitHub Spec Kit `specify` CLI)

### Shared MCP servers

Both workflows use the same MCP servers for the core capabilities:

- **Memory** — persistent project knowledge across sessions
- **Sequential Thinking** — structured task decomposition with revision
- **Playwright** — browser-truth verification for UI work
- **GitHub** — issue and PR context (optional)

### Shared add-ons

These are good next additions for both workflows:

- `Context7` for version-specific library and framework docs
- `Repomix` for AI-friendly repo packing when large context is needed
- `Promptfoo` for evals and workflow regression testing
- Aider-inspired patterns for repo maps and automatic verification after edits
- lightweight file-based memory via `CURRENT_STATE.md` and `DECISIONS.md`

Recommended order:

1. `Context7`
2. `Promptfoo`
3. `Repomix`
4. repo maps
5. automatic verification

## Quick Start

### Codex

```bash
./codex/scripts/install-codex-mcp-setup.sh
```

### Claude

```bash
# Global install (recommended — available in all projects)
./claude/scripts/install-claude-mcp-setup.sh --global

# Project-only install
./claude/scripts/install-claude-mcp-setup.sh
```

### Shared extras

- [Codex workflow notes](codex/README.md)
- [Claude workflow notes](claude/README.md)
- [Shared add-ons](shared/README.md)
- [Promptfoo starter evals](evals/README.md)

### Common options

Claude installer options:

```bash
# Skip GitHub MCP
./claude/scripts/install-claude-mcp-setup.sh --global --skip-github

# Provide GitHub PAT directly (no interactive prompt)
./claude/scripts/install-claude-mcp-setup.sh --global --github-pat ghp_yourtoken

# Skip Playwright MCP
./claude/scripts/install-claude-mcp-setup.sh --global --skip-playwright

# Skip rules or skills
./claude/scripts/install-claude-mcp-setup.sh --global --skip-rules
./claude/scripts/install-claude-mcp-setup.sh --global --skip-skills

# Install optional plugins and MCP servers
./claude/scripts/install-claude-mcp-setup.sh --global --with-mempalace --with-caveman
./claude/scripts/install-claude-mcp-setup.sh --global --with-atlassian
./claude/scripts/install-claude-mcp-setup.sh --global --with-ado --ado-org myorg

# Custom memory directory
./claude/scripts/install-claude-mcp-setup.sh --memory-dir "$HOME/.claude-memory/my-project"
```

Without `--global`, configs are written to the current repo only (`.mcp.json` and `.vscode/mcp.json`). With `--global`:

- MCP servers are added to `~/.claude.json` (Claude Code user scope)
- MCP servers are merged into VS Code user-level `settings.json`
- Global Claude rules are installed to `~/.claude/CLAUDE.md`
- `specify` CLI (GitHub Spec Kit) is installed via `uv`
- GitHub PAT is auto-detected from env/config or prompted interactively

Codex-only:

```bash
# Install VS Code Codex extension
./codex/scripts/install-codex-mcp-setup.sh --install-vscode-extension
```

## Main Files

- `codex/README.md`: Codex setup plan and operating notes
- `claude/README.md`: Claude setup plan and operating notes
- `claude/templates/global-CLAUDE.md`: template for global Claude rules (installed to `~/.claude/CLAUDE.md`)
- `claude/templates/rules/`: modular behavior rules (installed to `~/.claude/rules/`)
- `claude/templates/skills/`: language-specific skills (installed to `~/.claude/skills/`)
- `shared/README.md`: cross-agent tools and workflow additions
- `evals/README.md`: Promptfoo starter evals
- `CURRENT_STATE.md`: current repo state and likely next work
- `DECISIONS.md`: durable repo decisions
- `AGENTS.md`: repo-local behavior rules for Codex
- `CLAUDE.md`: repo-local behavior rules for Claude
- `codex/scripts/install-codex-mcp-setup.sh`: portable installer for Codex + MCP
- `claude/scripts/install-claude-mcp-setup.sh`: portable installer for Claude + MCP (supports `--global`)
- `.mcp.json`: Claude Code project-level MCP configuration
- `.vscode/mcp.json`: VS Code workspace MCP configuration

## Status

Both paths are working locally:

- Codex + MCP from the command line and VS Code
- Claude + MCP from the command line and VS Code

## License

MIT. See `LICENSE`.
