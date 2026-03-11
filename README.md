# ai-dev-bootstrap

Bootstrap a practical AI coding workspace with MCP-aware tools, editor integration, project memory, current docs/search, GitHub context, and browser verification.

## Purpose

This repo is for building a repeatable local setup that improves common AI coding weaknesses:

- weak project memory
- poor task breakdown on larger features
- stale documentation answers
- weak GitHub context
- guessing about browser behavior instead of verifying it

## Layout

- `README.md`: repo overview and navigation
- `codex/`: the working Codex-specific setup, docs, and installer
- `claude/`: Claude-specific notes and future setup
- `.vscode/`: workspace-level editor configuration
- `AGENTS.md`: repo-local Codex behavior rules for this repo itself

## Current Scope

Today the implemented path is centered on a Codex-first workflow with:

- Codex CLI
- Codex VS Code integration
- OpenAI Developer Docs MCP
- Memory MCP
- Sequential Thinking MCP
- Playwright MCP
- GitHub MCP

## Planned Scope

This repo is intentionally broader than Codex alone.

Planned additions include:

- Claude setup and workflow notes
- shared MCP patterns that work across coding agents
- more portable workstation bootstrap steps

## Quick Start

Current working path:

- [Codex setup](codex/README.md)

Planned next path:

- [Claude setup](claude/README.md)

Run the current Codex installer:

```bash
./codex/scripts/install-codex-mcp-setup.sh
```

If you want the script to prompt for your GitHub PAT and save it into the detected shell startup file:

```bash
./codex/scripts/install-codex-mcp-setup.sh --prompt-github-pat
```

If you also want the VS Code extension installed:

```bash
./codex/scripts/install-codex-mcp-setup.sh --install-vscode-extension
```

## Main Files

- `codex/README.md`: current Codex setup plan and operating notes
- `claude/README.md`: Claude placeholder and future entry point
- `AGENTS.md`: repo-local behavior rules for Codex
- `codex/scripts/install-codex-mcp-setup.sh`: portable installer for the current Codex + MCP stack
- `.vscode/mcp.json`: workspace MCP configuration

## Status

The Codex + MCP path is already working locally from both:

- the command line
- the Codex experience inside VS Code

## License

MIT. See `LICENSE`.
