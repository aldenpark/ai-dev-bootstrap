# Claude Setup

This folder contains the Claude-specific implementation for `ai-dev-bootstrap`.

If you want the repo overview or the multi-agent layout, start at the root `README.md`.

This plan targets the same weaknesses as the Codex setup, adapted for Claude Code's architecture:

- task breakdown on larger features
- project memory across sessions
- up-to-date web and docs lookups
- React/browser validation instead of UI guessing
- GitHub issue and PR context without tab switching
- parallel execution of independent subtasks

The controller stays `Claude Code`. MCP servers fill in the weak spots. Claude's built-in capabilities (web search, sub-agents, worktrees) replace some tools that Codex needs externally.

## Recommended Architecture

```text
You
  -> Claude Code CLI or Claude VS Code extension
     -> built-in WebSearch + WebFetch for current information
     -> built-in Agent tool for parallel sub-tasks
     -> built-in worktree isolation for safe experimentation
     -> MCP: Memory (knowledge graph persistence)
     -> MCP: Sequential Thinking (structured decomposition)
     -> MCP: Playwright (browser verification)
     -> MCP: GitHub (optional, for richer issue/PR context)
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

`Memory MCP`

- persistent project memory across sessions using a knowledge graph
- store decisions, architecture notes, current status, commands, and next steps
- Claude's built-in auto-memory is file-based and minimal — the MCP memory server adds structured entity/relation storage

`Sequential Thinking MCP`

- structured breakdown for multi-step tasks with explicit revision
- goes beyond TodoWrite by forcing phased planning with risk assessment
- critical for architecture, refactors, migrations, and multi-file changes

`Playwright MCP`

- browser automation and screenshots
- ideal for React app verification, UI bugs, regression checks, and flow validation
- Claude Code has zero built-in browser capability — this is the biggest gap

### Optional

`GitHub MCP`

- issues, pull requests, repo context, and code review flow
- Claude Code can already use `gh` CLI via Bash, so this is a convenience upgrade
- most useful if you work heavily from tickets

## What Claude Does Not Need (Skip These)

`OpenAI Developer Docs MCP`

- Codex-specific, not useful for Claude workflows

`DuckDuckGo MCP`

- Claude Code has built-in WebSearch

`Second memory system`

- do not run both Claude auto-memory and a separate knowledge graph on day one
- pick one primary system; the MCP memory server is recommended for project-specific facts

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

```bash
./claude/scripts/install-claude-mcp-setup.sh
```

What it does:

- checks for `node`, `npm`, `npx`
- creates the repo-local `.ai` memory directory
- writes `.mcp.json` at the repo root for Claude Code project-level MCP config
- rewrites `.vscode/mcp.json` with the correct memory path for this repo
- optionally configures GitHub MCP with PAT persistence

Useful examples:

```bash
./claude/scripts/install-claude-mcp-setup.sh --skip-github
```

```bash
./claude/scripts/install-claude-mcp-setup.sh --prompt-github-pat
```

```bash
./claude/scripts/install-claude-mcp-setup.sh --skip-playwright
```

```bash
./claude/scripts/install-claude-mcp-setup.sh --memory-dir "$HOME/.claude-memory/project-name"
```

## Phase 2: Verify The Setup

After running the installer:

1. Open this repo in VS Code with the Claude extension or start `claude` in the terminal.
2. Confirm MCP servers are available (memory, sequential-thinking, playwright).
3. Test each server with a quick prompt.

Good first prompts:

```text
Use sequential-thinking to break down a small React task into phases and likely files.
```

```text
Use memory to store: "This project uses React 19 with TypeScript strict mode."
```

```text
Use Playwright to open http://127.0.0.1:3000 and take a screenshot.
```

## Phase 3: Use It

### Task Decomposition Pattern

For any non-trivial task:

1. Use `sequential-thinking` to plan phases, risks, and file targets.
2. Check `memory` for prior decisions that affect the plan.
3. Break the plan into TodoWrite items.
4. Execute phases, using sub-agents for independent work.
5. Update `memory` with decisions after each phase.
6. Verify with tests and Playwright after each phase.

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

## React-Specific Usage Rules

1. Break work into UI structure, state, data flow, styling, browser behavior, and tests.
2. Do not accept claims about browser behavior without Playwright verification.
3. For library-version questions, use WebSearch before answering.
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

- verify the PAT and its scopes
- check the env var is set in the current shell

If memory feels noisy:

- keep one memory system
- store decisions, not raw transcripts

## Sources

- Claude Code docs: https://docs.anthropic.com/en/docs/claude-code
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- GitHub MCP server: https://github.com/github/github-mcp-server
- MCP reference servers: https://github.com/modelcontextprotocol/servers
- MCP memory server: https://www.npmjs.com/package/@modelcontextprotocol/server-memory
- MCP sequential thinking: https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking
