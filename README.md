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
- `.vscode/`: workspace-level editor configuration
- `AGENTS.md`: repo-local Codex behavior rules for this repo
- `CLAUDE.md`: repo-local Claude behavior rules for this repo

## Current Scope

Both paths are now implemented:

### Codex workflow

- Codex CLI and VS Code integration
- OpenAI Developer Docs MCP
- Memory MCP
- Sequential Thinking MCP
- Playwright MCP
- GitHub MCP

### Claude workflow

- Claude Code CLI and VS Code extension
- Memory MCP (knowledge graph persistence)
- Sequential Thinking MCP (structured decomposition)
- Playwright MCP (browser verification)
- GitHub MCP (optional)
- Built-in: WebSearch, WebFetch, parallel sub-agents, worktree isolation

### Shared MCP servers

Both workflows use the same MCP servers for the core capabilities:

- **Memory** — persistent project knowledge across sessions
- **Sequential Thinking** — structured task decomposition with revision
- **Playwright** — browser-truth verification for UI work
- **GitHub** — issue and PR context (optional)

## Quick Start

### Codex

```bash
./codex/scripts/install-codex-mcp-setup.sh
```

### Claude

```bash
./claude/scripts/install-claude-mcp-setup.sh
```

### Common options

Both installers support:

```bash
# Skip GitHub MCP
./claude/scripts/install-claude-mcp-setup.sh --skip-github

# Prompt for GitHub PAT and save to shell startup file
./claude/scripts/install-claude-mcp-setup.sh --prompt-github-pat

# Custom memory directory
./claude/scripts/install-claude-mcp-setup.sh --memory-dir "$HOME/.claude-memory/my-project"
```

Codex-only:

```bash
# Install VS Code Codex extension
./codex/scripts/install-codex-mcp-setup.sh --install-vscode-extension
```

## Main Files

- `codex/README.md`: Codex setup plan and operating notes
- `claude/README.md`: Claude setup plan and operating notes
- `AGENTS.md`: repo-local behavior rules for Codex
- `CLAUDE.md`: repo-local behavior rules for Claude
- `codex/scripts/install-codex-mcp-setup.sh`: portable installer for Codex + MCP
- `claude/scripts/install-claude-mcp-setup.sh`: portable installer for Claude + MCP
- `.mcp.json`: Claude Code project-level MCP configuration
- `.vscode/mcp.json`: VS Code workspace MCP configuration

## Status

Both paths are working locally:

- Codex + MCP from the command line and VS Code
- Claude + MCP from the command line and VS Code

## License

MIT. See `LICENSE`.
