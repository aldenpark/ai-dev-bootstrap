# Claude Setup

This folder contains the Claude-specific implementation for `ai-dev-bootstrap`.

If you want the repo overview or the multi-agent layout, start at the root `README.md`.

Recommended workflow split for this repo:

- `claude/` uses `spec-kit` (GitHub Spec Kit) as the planning layer for spec-driven development
- `codex/` uses `spec-kit` as the preferred structure and planning layer
- shared tools like Context7, Repomix, and Promptfoo live in `shared/`
- shared repo state lives in `CURRENT_STATE.md` and `DECISIONS.md`

This plan targets the same weaknesses as the Codex setup, adapted for Claude Code's architecture:

- task breakdown on larger features
- project memory across sessions
- up-to-date web and docs lookups
- React/browser validation instead of UI guessing
- GitHub issue and PR context without tab switching
- parallel execution of independent subtasks

The controller stays `Claude Code`. MCP servers fill in the weak spots. Claude's built-in capabilities (web search, sub-agents, worktrees) replace some tools that Codex needs externally.

## Why Spec-Kit Fits Claude

GitHub's [Spec Kit](https://github.com/github/spec-kit) is a CLI tool (`specify`) that enables spec-driven development. It pairs well with Claude because:

- Claude benefits from clear written specs before implementation
- `sequential-thinking` MCP handles in-session decomposition, while `specify` handles cross-session planning artifacts
- specs become the source of truth that Claude reads before making changes

What to use `spec-kit` for:

- new features spanning multiple files or components
- refactors, migrations, or architectural changes
- any task where you want a spec before code

What to use Claude's built-in tools for:

- in-session task tracking (`TodoWrite`)
- real-time decomposition (`sequential-thinking` MCP)
- parallel execution of independent work (`Agent` tool)
- “what should I do next?” within a session

## Recommended Architecture

```text
You
  -> Claude Code CLI or Claude VS Code extension
     -> built-in WebSearch + WebFetch for current information
     -> built-in Agent tool for parallel sub-tasks
     -> built-in worktree isolation for safe experimentation
     -> MCP: Context7 (versioned library/framework docs)
     -> MCP: Memory (knowledge graph persistence)
     -> MCP: Sequential Thinking (structured decomposition)
     -> MCP: Playwright (browser verification)
     -> MCP: GitHub (issue/PR context via PAT)
     -> CLI: specify (spec-driven development via GitHub Spec Kit)
     -> Rules: communication, code-style, testing, git (~/.claude/rules/)
     -> Skills: frontend, python, csharp (~/.claude/skills/)
     -> Optional: MemPalace (persistent memory palace plugin)
     -> Optional: Caveman (terse output, ~75% token savings)
     -> Optional: Atlassian MCP (Jira, Confluence, Compass via OAuth)
     -> Optional: Azure DevOps MCP (work items, repos, PRs via PAT)
```

Why this order matters:

- better decomposition beats adding another model too early
- better memory beats relying on chat history
- better browser verification beats arguing about React UI bugs
- parallel sub-agents turn large tasks from serial bottlenecks into concurrent work

## What Claude Code Has Built-In (No MCP Needed)

`WebSearch + WebFetch`

- current docs and web search without a separate MCP or `--search` flag
- always available, no configuration needed

`Agent tool (sub-agents)`

- spawn concurrent workers for independent tasks
- each sub-agent has full tool access
- results flow back to the main conversation

`Worktree isolation`

- run experimental changes in an isolated git worktree
- main working tree stays clean
- worktree is auto-cleaned if no changes are made

`TodoWrite`

- flat task tracking during a session
- useful but not a replacement for Sequential Thinking on complex work

## What Each MCP Fixes

### Must-have

`Context7`

- current library and framework docs with cleaner version awareness than generic search alone
- especially useful for React, Next.js, TypeScript, Vite, and migration questions

`Memory MCP`

- persistent project memory across sessions using a knowledge graph
- store decisions, architecture notes, current status, commands, and next steps
- Claude's built-in auto-memory is file-based and minimal — the MCP memory server adds structured entity/relation storage
- pair it with `CURRENT_STATE.md` and `DECISIONS.md` for human-readable repo state

`Sequential Thinking MCP`

- structured breakdown for multi-step tasks with explicit revision
- goes beyond TodoWrite by forcing phased planning with risk assessment
- critical for architecture, refactors, migrations, and multi-file changes

`Playwright MCP`

- browser automation and screenshots
- ideal for React app verification, UI bugs, regression checks, and flow validation
- Claude Code has zero built-in browser capability — this is the biggest gap

### Strongly recommended

`GitHub MCP`

- issues, pull requests, repo context, and code review flow
- authenticated via Personal Access Token (PAT)
- Claude Code can already use `gh` CLI via Bash, but the MCP provides richer structured access

## What Claude Does Not Need (Skip These)

`OpenAI Developer Docs MCP`

- Codex-specific, not useful for Claude workflows

`DuckDuckGo MCP`

- Claude Code has built-in WebSearch

`Second memory system`

- do not run both Claude auto-memory and a separate knowledge graph on day one
- pick one primary system; the MCP memory server is recommended for project-specific facts

## Modular Rules and Skills

The global install now includes modular configuration files:

### Rules (`~/.claude/rules/`)

Rules are referenced from `CLAUDE.md` via `@rules/filename.md` and provide behavioral guardrails:

- **communication.md** — brevity, no filler, direct answers
- **code-style.md** — smallest patch, no premature abstractions, read before configuring
- **testing.md** — verify your own work, run actual commands, never skip testing
- **git.md** — conventional commits, no amend unless asked, testing before committing

### Skills (`~/.claude/skills/`)

Skills are activated by the `/skill` command and provide domain-specific conventions:

- **frontend** — React, TypeScript, modern CSS patterns
- **python** — Poetry, ruff, pytest, async patterns
- **csharp** — .NET, xUnit, DI patterns, Testcontainers
- **review** — multi-agent code review that spawns specialized sub-agents in parallel based on what changed (10 reviewer prompts covering .NET, Python, React, config safety, test coverage, resilience, observability, agent interfaces, cross-service, and past learnings)
- **mine-learnings** — extracts actionable learnings from past Claude Code sessions and stores them in `~/.claude/learnings/` as JSONL; includes a Python script to extract unprocessed session transcripts and parallel agents to analyze them

### Custom Agents (`~/.claude/agents/`)

Custom agents are specialized sub-agents with constrained tool access and dedicated system prompts. They run on cheaper/faster models to keep the main conversation context clean.

- **ado-manager** — manages Azure DevOps work items (create stories, update state, link parents, assign points). Runs on Sonnet with only ADO MCP tools. Returns concise summaries instead of raw API responses.

## Optional Plugins

### MemPalace

A persistent memory palace plugin that stores verbatim content (not summaries) using ChromaDB. Organizes memory into wings, rooms, and drawers using the method of loci.

Install with the `--with-mempalace` flag or manually:

```bash
claude plugin marketplace add MemPalace/mempalace
claude plugin install mempalace@mempalace
pip3 install mempalace
mempalace init ~/projects/myapp
```

Use in session: `/mempalace:search "why did we switch to X"`

### Caveman

A plugin that makes Claude communicate in ultra-terse style, reducing output tokens by ~75% while maintaining technical accuracy.

Install with the `--with-caveman` flag or manually:

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

Use in session: `/caveman` to activate terse mode. Sub-skills include `caveman-commit`, `caveman-review`, and `caveman-compress`.

## Optional MCP Servers

### Atlassian (Jira, Confluence, Compass)

Adds tools for Jira issues, Confluence pages, and Compass components via OAuth 2.1.

Install with the `--with-atlassian` flag or manually:

```bash
claude mcp add --transport http --scope user atlassian https://mcp.atlassian.com/v1/mcp
```

After adding:

1. Restart Claude Code (or start a new session)
2. Run `/mcp` — you'll see atlassian listed, likely needing auth
3. `/mcp` walks you through the OAuth 2.1 flow (opens browser to your Atlassian Cloud site)

Once authenticated, you get tools for Jira, Confluence, and Compass depending on what your Atlassian site has.

### Azure DevOps (Work Items, Repos, PRs)

Adds tools for ADO work items, repositories, pull requests, and pipelines via `@azure-devops/mcp`.

Install with the `--with-ado` flag or manually:

```bash
claude mcp add --scope user azure-devops -- npx -y @azure-devops/mcp YOUR_ORG
```

Replace `YOUR_ORG` with your Azure DevOps organization name (e.g. `netdocuments`).

The installer prompts for the org name interactively, or you can pass it directly:

```bash
./claude/scripts/install-claude-mcp-setup.sh --global --with-ado --ado-org netdocuments
```

## Claude Extras To Lean On

Claude Code already has several built-in features worth using before adding more tooling:

- slash commands for repeatable workflows
- sub-agents for parallel independent work
- hooks for automation around edits and checks
- worktree isolation for risky experiments

These built-in features complement `spec-kit` and the MCP stack well.

## Shared Add-ons

These shared additions are now part of the repo direction:

- `Context7` for current library/framework docs, already included in the installer/config path
- `Repomix` for larger repo context when normal file-by-file context is not enough
- `Promptfoo` for workflow evals and prompt regression testing, with a starter scaffold in `../evals/`
- `CURRENT_STATE.md` and `DECISIONS.md` for lightweight file-based memory

See `../shared/README.md` for the shared layer.

## Prerequisites

Install these first:

- Node.js `20+`
- `npm` / `npx`
- VS Code with the Claude extension, or Claude Code CLI

Useful checks:

```bash
node --version
npm --version
claude --version
```

## Phase 1: Run The Installer

### Global install (recommended)

Installs MCP servers, global Claude rules, and the `specify` CLI for all projects:

```bash
./claude/scripts/install-claude-mcp-setup.sh --global
```

What it does:

- installs MCP servers to `~/.claude.json` (Claude Code user scope — available in all projects)
- merges MCP servers into VS Code user-level `settings.json`
- installs global Claude rules to `~/.claude/CLAUDE.md`
- installs modular rules to `~/.claude/rules/` (communication, code-style, testing, git)
- installs skills to `~/.claude/skills/` (frontend, python, csharp, review, mine-learnings)
- installs custom agents to `~/.claude/agents/` (ado-manager)
- installs the `specify` CLI (GitHub Spec Kit) via `uv`
- prompts for a GitHub PAT if not already configured (persists to `~/.zprofile`)

### Project-only install

Scoped to the current repo only:

```bash
./claude/scripts/install-claude-mcp-setup.sh
```

What it does:

- writes `.mcp.json` at the repo root for Claude Code project-level MCP config
- writes `.vscode/mcp.json` for VS Code workspace MCP config
- creates the repo-local `.ai` memory directory

### Options

```bash
# Skip GitHub MCP
./claude/scripts/install-claude-mcp-setup.sh --global --skip-github

# Provide GitHub PAT directly (no prompt)
./claude/scripts/install-claude-mcp-setup.sh --global --github-pat ghp_yourtoken

# Skip Playwright MCP
./claude/scripts/install-claude-mcp-setup.sh --global --skip-playwright

# Skip rules or skills
./claude/scripts/install-claude-mcp-setup.sh --global --skip-rules
./claude/scripts/install-claude-mcp-setup.sh --global --skip-skills

# Install optional plugins
./claude/scripts/install-claude-mcp-setup.sh --global --with-mempalace
./claude/scripts/install-claude-mcp-setup.sh --global --with-caveman

# Install optional MCP servers
./claude/scripts/install-claude-mcp-setup.sh --global --with-atlassian
./claude/scripts/install-claude-mcp-setup.sh --global --with-ado --ado-org myorg

# Kitchen sink
./claude/scripts/install-claude-mcp-setup.sh --global --with-mempalace --with-caveman --with-atlassian

# Custom memory directory
./claude/scripts/install-claude-mcp-setup.sh --memory-dir "$HOME/.claude-memory/project-name"
```

## Phase 2: Verify The Setup

After running the installer:

1. Restart VS Code or start a new Claude Code session.
2. Run `/mcp` to confirm MCP servers are connected: `context7`, `memory`, `sequential-thinking`, `playwright`, and `github`.
3. Test each server with a quick prompt.

Good first prompts:

```text
Use sequential-thinking to break down a small React task into phases and likely files.
```

```text
Use memory to store: "This project uses React 19 with TypeScript strict mode."
```

```text
Use context7 to confirm the current Next.js guidance for App Router data fetching.
```

```text
Use Playwright to open http://127.0.0.1:3000 and take a screenshot.
```

## Phase 3: Use It

### Task Decomposition Pattern

For any non-trivial task:

1. Use `sequential-thinking` to plan phases, risks, and file targets.
2. Check `memory` for prior decisions that affect the plan.
3. Read `CURRENT_STATE.md` and `DECISIONS.md` for durable repo context.
4. Break the plan into TodoWrite items.
5. Execute phases, using sub-agents for independent work.
6. Update `memory` with decisions after each phase.
7. Verify with tests and Playwright after each phase.

### Parallelism Pattern

Claude Code's Agent tool enables parallel execution of independent subtasks. Use this when:

- multiple files need independent changes
- research and implementation can happen simultaneously
- tests can run while you continue working on the next phase

Example workflow:

```text
I need to add a new API endpoint and update the frontend to use it.

1. Use sequential-thinking to plan the work.
2. Spawn one sub-agent to implement the API endpoint.
3. Spawn another sub-agent to write the frontend component.
4. Once both complete, integrate and test.
```

For risky changes, use worktree isolation:

```text
Try this refactor in an isolated worktree so we don't affect the main branch.
```

### Browser Verification Pattern

Same as the Codex setup:

1. Confirm the target URL from user context.
2. Open with Playwright.
3. Inspect rendered behavior.
4. Summarize finding.
5. Propose the smallest fix.

Safety rules:

- Only use user-provided URLs.
- Never scan ports or start/stop servers.
- Prefer `127.0.0.1` over `localhost`.

### Memory Pattern

Store concise, reusable facts:

- architecture decisions and rationale
- runtime conventions and chosen ports
- accepted constraints
- recurring commands
- project-specific patterns

Read memory at the start of non-trivial tasks.

Read these files too when the task affects the repo workflow or setup:

- `CURRENT_STATE.md`
- `DECISIONS.md`

## React-Specific Usage Rules

1. Break work into UI structure, state, data flow, styling, browser behavior, and tests.
2. Do not accept claims about browser behavior without Playwright verification.
3. For library-version questions, use Context7 or WebSearch before answering.
4. Store accepted UI decisions in memory.
5. If the task is larger than one component, use Sequential Thinking first.
6. For independent component work, use parallel sub-agents.

## Troubleshooting

If MCP servers do not appear:

- restart VS Code or the Claude session
- check `.mcp.json` exists at the repo root
- run `npx @modelcontextprotocol/server-memory` manually to test

If Playwright fails:

- make sure the target app is already running
- run Playwright once from CLI first
- tighten the prompt to a user-provided URL only

If GitHub MCP fails:

- verify the PAT and its scopes (needs repo, issues, pull requests access)
- re-run the installer with `--global` to re-enter the PAT
- check `~/.claude.json` has a `github` entry with `Authorization` header

If memory feels noisy:

- keep one memory system
- store decisions, not raw transcripts

## Sources

- Claude Code docs: https://docs.anthropic.com/en/docs/claude-code
- GitHub Spec Kit: https://github.com/github/spec-kit
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- GitHub MCP server: https://github.com/github/github-mcp-server
- MCP reference servers: https://github.com/modelcontextprotocol/servers
- MCP memory server: https://www.npmjs.com/package/@modelcontextprotocol/server-memory
- MCP sequential thinking: https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking
- Context7: https://github.com/upstash/context7
- MemPalace: https://github.com/MemPalace/mempalace
- Caveman: https://github.com/JuliusBrussee/caveman
- Atlassian MCP: https://mcp.atlassian.com
- Azure DevOps MCP: https://www.npmjs.com/package/@azure-devops/mcp
