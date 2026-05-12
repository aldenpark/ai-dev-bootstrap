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
  Best when you want stronger structure, explicit plans, phased implementation, and Codex-native reusable skills, agents, rules, and review workflows.
- `Claude -> spec-kit`
  Best when you want spec-driven planning plus Claude-native execution features like sub-agents, hooks, and worktrees.

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
- global Codex instructions rendered into `~/.codex/AGENTS.md`
- modular rule fragments in `~/.codex/rules-md/`
- global skills in `~/.codex/skills/`
- global custom agents in `~/.codex/agents/`
- optional Stop hook and monthly learn-eval scheduler
- optional MemPalace Cloud MCP
- optional local Qwen3.6 coding worker through `llama.cpp`/`llama-server`
- repo-local Codex plugin bundle scaffold in `plugins/ai-dev-bootstrap-codex/`
- repo-local Codex project-management plugin scaffold in `plugins/ai-dev-bootstrap-projects/`

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
- `plugins/ai-dev-bootstrap-codex/`: repo-local Codex plugin bundle
- `plugins/ai-dev-bootstrap-projects/`: repo-local Codex project-management plugin
- `.agents/plugins/marketplace.json`: example local marketplace entry for the repo plugin bundle

## Install Commands

Codex:

```bash
# Global install (default)
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
./codex/scripts/install-codex-mcp-setup.sh --write-vscode-workspace-config
./codex/scripts/install-codex-mcp-setup.sh --with-hooks --with-learn-eval-cron
./codex/scripts/install-codex-mcp-setup.sh --with-mempalace
codex mcp login mempalace-cloud
./codex/scripts/install-codex-mcp-setup.sh --with-qwen36-local
./claude/scripts/install-claude-mcp-setup.sh --github-pat ghp_yourtoken
./claude/scripts/install-claude-mcp-setup.sh --skip-playwright
```

## Verified Working

This repo has already been validated locally for:

- Codex global MCP install to `~/.codex/config.toml`
- Codex global rules install to `~/.codex/AGENTS.md` and `~/.codex/rules-md/`
- Codex global skills install to `~/.codex/skills/`
- Codex global custom agents install to `~/.codex/agents/`
- Codex CLI + MCP
- Codex in VS Code
- Codex installer smoke test (`codex/scripts/test-codex-installer.sh`)
- Codex hook and learn-eval scheduler install paths
- Codex local Qwen3.6 coding-worker install path
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
