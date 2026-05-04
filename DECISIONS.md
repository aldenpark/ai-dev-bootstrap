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
- the Codex installer prefers an existing PAT env var or prior Codex config before changing the configured env var name

### Global vs Project Install

- Codex installs MCP servers globally by default in `~/.codex/config.toml`
- Codex uses `~/.ai/codex/memory.json` as the default global memory path
- Codex does not rewrite repo-local `.vscode/mcp.json` by default; that workspace fallback is opt-in via `--write-vscode-workspace-config`
- `--global` is the recommended Claude install mode
- global writes MCP servers to `~/.claude.json`, rules to `~/.claude/CLAUDE.md`, VS Code user settings
- project-only writes to `.mcp.json` and `.vscode/mcp.json` in the repo
- global CLAUDE.md template lives at `claude/templates/global-CLAUDE.md` in this repo

### Modular Rules and Skills

- Codex global instructions are rendered into `~/.codex/AGENTS.md` from rule fragments stored in `~/.codex/rules-md/`
- Codex skills install globally into `~/.codex/skills/`
- Codex custom agents install globally into `~/.codex/agents/`
- Codex exposes `--skip-rules`, `--skip-skills`, and `--skip-agents` for users who want their own setup
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
- Codex wires MemPalace Cloud directly into `~/.codex/config.toml` as `mempalace-cloud` and adds a managed protocol block to `~/.codex/AGENTS.md`; login completes via `codex mcp login mempalace-cloud`
- Claude plugins are installed via the Claude Code plugin marketplace; MCP servers via `claude mcp add`

### Self-Learning Stack (Hermes-inspired, Claude-native)

Reviewed Nous Hermes Agent (self-improving framework, launched Feb 2026) as a potential outer-loop controller. Decided not to adopt wholesale — Claude Code stays the controller. Selectively imported three mechanics:

- **Auto-skill-draft Stop hook**: after a qualifying session (heuristic: >=6 user turns AND >=8 tool calls), forks an async `claude -p` pass to draft a SKILL.md into `~/.claude/skills/drafts/`. Closes the "proactive skill generation" gap that `/mine-learnings` (reactive) left open.
- **ShareGPT export** from mine-learnings: keeps the fine-tuning / model-comparison pipeline wired without being used today. Cheap to keep in place.
- **Monthly learn-eval cron**: moves reviewer-quality scoring from manual (run-when-remembered) to scheduled. macOS launchd and Linux cron both supported.

Explicitly skipped: Honcho user modeling (overlaps with auto-memory), Atropos RL (no payoff without switching models), multi-platform intake (terminal/IDE is sufficient).

### Codex-Native Learning Loop

- Codex mirrors the Claude learning loop with native assets instead of a direct port
- the Codex Stop hook is opt-in via `--with-hooks` and uses `codex exec` for the second-pass draft generation
- the Codex monthly learn-eval scheduler is opt-in via `--with-learn-eval-cron`
- learnings and review-eval output live under `~/.codex/learnings/`
- live verification should prefer real `codex exec` calls and hook output over stub-only checks when practical

### Codex Multi-Model Direction

- `Codex` remains the single controller for planning, search/docs, verification, and reconciliation
- local coding and local review should run as subordinate Codex or wrapper-script jobs, not as competing primary controllers
- prefer on-demand `llama.cpp`/`llama-server` for exact local `Qwen3.6` on this laptop; it is leaner and more controllable than LM Studio
- use `qwen36-code` as the local Qwen coding worker; Codex remains responsible for applying patches and running verification
- default future Codex coding sessions to local Qwen drafts for bounded implementation work unless the task requires cloud reasoning directly
- replicate local Qwen through the opt-in `--with-qwen36-local` installer path; do not download or build the 17GB model by default
- do not wire `llama-server` directly as a Codex model provider until the tool schema mismatch is solved
- keep `Ollama` as the lower-friction fallback when standardizing on an Ollama-published coding model such as `qwen3-coder`
- staged review should be `local review first -> Gemini 3 review second -> Codex reconciler`

### Memory Strategy

- keep the official MCP memory server as the primary structured memory backend
- use file-based memory for human-readable repo state and decision logging
- MemPalace Cloud is available as an optional upgrade for users who want cross-tool memory beyond the default memory MCP

### File-Based Memory

- `CURRENT_STATE.md` tracks what is implemented and what is next
- `DECISIONS.md` tracks stable choices that future sessions should not rediscover from scratch
