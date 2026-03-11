# ai-dev-bootstrap

Bootstrap a practical AI coding workspace with MCP-aware tools, editor integration, project memory, current docs/search, GitHub context, and browser verification.

## Purpose

This repo is for building a repeatable local setup that improves common AI coding weaknesses:

- weak project memory
- poor task breakdown on larger features
- stale documentation answers
- weak GitHub context
- guessing about browser behavior instead of verifying it

## Current Scope

Today this repo is centered on a Codex-first workflow with:

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

Run the installer:

```bash
./scripts/install-codex-mcp-setup.sh
```

If you want the script to prompt for your GitHub PAT and save it into the detected shell startup file:

```bash
./scripts/install-codex-mcp-setup.sh --prompt-github-pat
```

If you also want the VS Code extension installed:

```bash
./scripts/install-codex-mcp-setup.sh --install-vscode-extension
```

## Main Files

- `Local AI Coding Environment Setup.md`: detailed setup plan and operating notes
- `AGENTS.md`: repo-local behavior rules for Codex
- `scripts/install-codex-mcp-setup.sh`: portable installer for the current Codex + MCP stack
- `.vscode/mcp.json`: workspace MCP configuration

## Status

The Codex + MCP path is already working locally from both:

- the command line
- the Codex experience inside VS Code

## License

MIT. See `LICENSE`.
