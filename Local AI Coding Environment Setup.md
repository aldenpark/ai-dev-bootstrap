# Local AI Coding Environment Setup

This guide is the current top-level setup note for `ai-dev-bootstrap`.

It replaces the older Codex-only framing. The repo is now split into:

- `codex/` for the Codex-first workflow
- `claude/` for the Claude-first workflow
- `shared/` for tools and patterns that help both
- `evals/` for Promptfoo-based comparisons and regression checks

## Current Direction

This repo is designed to improve the main AI coding failure modes:

- weak memory across sessions
- poor breakdown of larger tasks
- stale framework and API answers
- weak GitHub context
- guessing about browser behavior instead of verifying it
- serial execution of independent work

## Recommended Split

Use this repo as two related workflows, not one identical stack:

- `Codex -> spec-kit`
  Best when you want stronger structure, explicit plans, and phased implementation.
- `Claude -> task-master`
  Best when you want stronger execution flow, next-task handling, and backlog management.

Both workflows share the same broad ideas:

- `Memory MCP` for durable structured memory
- `Sequential Thinking MCP` for breakdown and planning
- `Playwright MCP` for browser-truth verification
- `GitHub MCP` for issue and PR context
- `Context7` for current version-specific framework and library docs
- `CURRENT_STATE.md` and `DECISIONS.md` for lightweight file-based repo memory

## What Is Implemented

Codex path:

- Codex CLI setup
- Codex VS Code integration
- OpenAI Developer Docs MCP
- Context7
- Memory MCP
- Sequential Thinking MCP
- Playwright MCP
- GitHub MCP

Claude path:

- Claude Code CLI setup
- Claude VS Code integration
- Context7
- Memory MCP
- Sequential Thinking MCP
- Playwright MCP
- GitHub MCP
- Claude-native features documented: slash commands, sub-agents, hooks, worktrees

Shared path:

- Promptfoo starter scaffold in `evals/`
- shared notes for Context7, Repomix, and Aider-inspired patterns
- repo-local behavior rules in `AGENTS.md` and `CLAUDE.md`

## Current Repo Layout

- `README.md`: repo overview
- `codex/README.md`: Codex operating guide
- `claude/README.md`: Claude operating guide
- `shared/README.md`: shared add-ons and memory options
- `evals/README.md`: Promptfoo starter usage
- `CURRENT_STATE.md`: what is implemented and likely next
- `DECISIONS.md`: stable repo decisions

## Install Commands

Codex:

```bash
./codex/scripts/install-codex-mcp-setup.sh
```

Claude:

```bash
./claude/scripts/install-claude-mcp-setup.sh
```

Useful installer options:

```bash
./codex/scripts/install-codex-mcp-setup.sh --prompt-github-pat
./codex/scripts/install-codex-mcp-setup.sh --install-vscode-extension
./claude/scripts/install-claude-mcp-setup.sh --prompt-github-pat
./claude/scripts/install-claude-mcp-setup.sh --skip-playwright
```

## Verified Working

This repo has already been validated locally for:

- Codex CLI + MCP
- Codex in VS Code
- Claude + MCP
- Context7 lookup flow
- Memory MCP
- Sequential Thinking MCP
- GitHub MCP
- Playwright with explicit URL guardrails

## Operating Rules

Keep the repo rules lean:

- use `sequential-thinking` for multi-file work, refactors, and architectural changes
- use `Context7`, docs tools, or search for current and versioned questions
- use `Playwright` for UI, redirect, auth-flow, and rendered-state questions
- use `CURRENT_STATE.md` and `DECISIONS.md` for human-readable repo context
- write only short durable facts to memory
- use tests, lint, type checks, and browser verification as the final arbiters

## Best Next Additions

The best additions after the core setup are:

1. `Promptfoo` expansion with real project tasks
2. `Repomix` as an on-demand large-repo context tool
3. Aider-inspired `repo maps`
4. Aider-inspired automatic verification after edits

## Use The More Specific Docs

For day-to-day use, the detailed sources of truth are:

- `codex/README.md`
- `claude/README.md`
- `shared/README.md`
- `AGENTS.md`
- `CLAUDE.md`

This file is the current overview, not the detailed per-agent playbook.
