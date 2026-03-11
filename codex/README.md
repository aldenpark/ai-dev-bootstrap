# Codex Setup

This folder contains the current Codex-first implementation for `ai-dev-bootstrap`.

If you want the repo overview or the future multi-agent layout, start at the root `README.md`.

Recommended workflow split for this repo:

- `codex/` uses `spec-kit` as the preferred structure and planning layer
- `claude/` uses `task-master` as the preferred execution and backlog layer
- shared tools like Context7, Repomix, and Promptfoo live in `shared/`
- shared repo state lives in `CURRENT_STATE.md` and `DECISIONS.md`

This plan is optimized for the weaknesses you care about most:

- task breakdown on larger features
- project memory across sessions
- up-to-date web and docs lookups
- React/browser validation instead of UI guessing
- GitHub issue and PR context without tab switching

The controller stays `Codex`. MCP servers fill in the weak spots. A local model stays optional and comes later.

## Why Spec-Kit Fits Codex

For this repo, `spec-kit` is the best fit for Codex because it gives Codex explicit artifacts to work from:

- feature specs
- implementation plans
- task breakdowns
- phased implementation

That matches Codex well because Codex benefits from clear written structure, explicit instructions, and planned execution.

What to use `spec-kit` for:

- new features
- multi-file changes
- refactors
- migrations
- anything where you want a spec before code

What not to expect from it:

- ongoing backlog management
- “what should I do next?” task orchestration during day-to-day work

## Recommended Architecture

```text
You
  -> Codex CLI or Codex IDE extension
     -> built-in search for current information
     -> MCP: Context7
     -> MCP: OpenAI Developer Docs
     -> MCP: Memory
     -> MCP: Sequential Thinking
     -> MCP: Playwright
     -> MCP: GitHub
     -> optional local model later
```

Why this is the right order:

- better decomposition beats adding another model too early
- better memory beats relying on chat history
- better browser verification beats arguing about React UI bugs
- better current docs/search beats stale answers

## Parallelism

Use parallelism for `context gathering` and `verification`, not for competing edits.

Good uses:

- read code, memory, docs, and GitHub context in parallel
- inspect code and verify browser behavior in parallel for UI work
- run independent checks like lint, typecheck, and tests in parallel when the commands are known

Bad uses:

- multiple agents editing the same files
- multiple models trying to drive the same task
- competing patches unless you explicitly want alternatives

Rule:

- one controller
- one final writer
- parallel readers and checkers when the work is independent

## What Each MCP Fixes

### Must-have

`OpenAI Developer Docs MCP`

- current OpenAI and Codex docs
- useful when the question is versioned or tool-specific

`Context7`

- current library and framework docs with better version awareness than generic web search
- useful for React, Next.js, TypeScript, Vite, and migration questions

`Memory MCP`

- persistent project memory across sessions
- store durable decisions, architecture notes, current status, commands, and next steps
- pair it with `CURRENT_STATE.md` and `DECISIONS.md` for human-readable repo state

`Playwright MCP`

- browser automation and screenshots
- ideal for React app verification, UI bugs, regression checks, and flow validation

### Strongly recommended

`Sequential Thinking MCP`

- structured breakdown for multi-step tasks
- useful for architecture, refactors, and multi-file changes

`GitHub MCP`

- issues, pull requests, repo context, and code review flow
- especially useful if you work from tickets

### Skip for now

`Puppeteer MCP`

- Playwright is the better default for your React/web workflow

`DuckDuckGo MCP`

- Codex CLI already has a built-in `--search` flag

`Second memory system`

- do not run both a markdown memory bank and a separate knowledge graph memory system on day one

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
- VS Code
- ChatGPT Plus / Codex access

Optional:

- Docker, only if you want an alternative container-based workflow later

Useful checks:

```bash
node --version
npm --version
code --version
codex --version
```

Optional check:

```bash
docker --version
```

## Hardware Recommendations

For the current Codex-first setup, local hardware matters more for `VS Code + browser + terminals + Playwright` than for model inference.

Official minimums are low:

- VS Code recommends a `1.6 GHz+` CPU and `1 GB RAM`
- Claude Code documents `4 GB+ RAM`
- if you choose to use Docker Desktop for Linux later, it requires `at least 4 GB of RAM`

Practical recommendation for this repo:

- `Baseline`: 4 modern CPU cores, `16 GB RAM`, SSD storage, no discrete GPU required
- `Comfortable daily use`: 6 to 8 CPU cores, `32 GB RAM`, `512 GB+` SSD
- `Heavy local multitasking`: `32 GB RAM` minimum if you keep Playwright, a browser, multiple IDE windows, and optional Docker workloads open at the same time

GPU note:

- for the setup in this folder, a dedicated GPU is optional
- if you later add local models, the hardware guidance changes substantially and should be documented separately

## Phase 1: Install Codex

Install the CLI:

```bash
npm install -g @openai/codex
```

Sign in:

```bash
codex login
```

For VS Code:

- install the OpenAI Codex IDE extension from the official Codex IDE docs
- sign into the same OpenAI account in the extension

Important detail:

OpenAI documents that your MCP server configuration is shared between the Codex CLI and the Codex IDE extension, so you only need to configure Codex MCP servers once.

## Phase 2: Install The Core MCP Stack In Codex

Create a folder for persistent project memory:

```bash
mkdir -p ./.ai
```

Add the OpenAI docs server:

```bash
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp
```

Add Context7:

```bash
codex mcp add context7 \
  -- npx -y @upstash/context7-mcp
```

If you already added the older `docs.mcp.openai.com` endpoint, remove and re-add it:

```bash
codex mcp remove openaiDeveloperDocs
codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp
```

Add the memory server:

```bash
codex mcp add memory \
  --env MEMORY_FILE_PATH="$(pwd)/.ai/memory.json" \
  -- npx -y @modelcontextprotocol/server-memory
```

Add Sequential Thinking:

```bash
codex mcp add sequential-thinking \
  -- npx -y @modelcontextprotocol/server-sequential-thinking
```

Add Playwright:

```bash
codex mcp add playwright \
  -- npx @playwright/mcp@latest
```

Add GitHub through the hosted remote MCP server:

```bash
export GITHUB_MCP_PAT=YOUR_GITHUB_PAT
codex mcp add github \
  --url https://api.githubcopilot.com/mcp/ \
  --bearer-token-env-var GITHUB_MCP_PAT
```

Recommended GitHub PAT scopes:

- repo access for private repos if needed
- pull request and issues access
- keep scopes as narrow as practical

Check what is configured:

```bash
codex mcp list
```

## Phase 3: Use It From The Command Line

Start Codex with search enabled:

```bash
codex --search
```

Recommended operating rules:

1. For anything spanning multiple files, ask Codex to use `sequential-thinking` first.
2. For anything time-sensitive or version-specific, ask Codex to use search, Context7, or docs before answering.
3. For any React or browser behavior question, ask Codex to verify with `playwright` before proposing a fix.
4. After an important decision, ask Codex to update `memory`.
5. For non-trivial repo work, expect Codex to read `CURRENT_STATE.md` and `DECISIONS.md` before it acts.
6. Ask Codex to parallelize safe reads, lookups, and verification when that will reduce turnaround time.
7. Use tests, lint, and type checks as the final judge.

Prompt patterns that work well:

```text
Before changing code, use sequential-thinking to break this into phases, risks, and file targets.
```

```text
This may depend on current docs. Use search and the OpenAI docs MCP before answering.
```

```text
This depends on current React or Next.js behavior. Use Context7 first, then answer with the current version-specific guidance.
```

```text
This is a React UI bug. Reproduce it with Playwright first, then propose the smallest fix.
```

```text
After we agree on the approach, write the decision and affected files into memory.
```

```text
Gather code context, docs, and GitHub issue details in parallel if they are independent, then give me one recommendation.
```

```text
After the patch, run the available verification steps in parallel where safe, then summarize the failures first.
```

## Phase 4: Use It In VS Code

### Preferred route: Codex IDE extension

This is the cleanest path if you want Codex to stay the controller.

Important note:

- in the VS Code marketplace / local extension list, the extension ID is currently `openai.chatgpt`
- the installed display name is `Codex - OpenAI's coding agent`
- if you already have `openai.chatgpt` installed and signed in, that is the current Codex extension path

Workflow:

1. install the Codex IDE extension
2. sign in
3. configure MCP servers once using `codex mcp add ...`
4. restart VS Code if the new MCP servers do not appear immediately

Because Codex shares MCP configuration between CLI and the IDE extension, the CLI setup should carry over.

Quick VS Code verification:

1. reload the VS Code window
2. open the `Codex` sidebar
3. start a fresh thread in this workspace
4. confirm the repo-local `AGENTS.md` rules are in effect
5. test one MCP-backed prompt in the IDE

Good first IDE prompts:

```text
Use memory to read back the Phase 2 validation note.
```

```text
Use sequential-thinking to break down a small React task into phases and likely files.
```

```text
Use the OpenAI docs MCP only and summarize what the Codex IDE page is for in one sentence.
```

### Optional route: VS Code native MCP config

VS Code also supports MCP servers through workspace configuration. This is useful if you want a backup path for Agent Mode or other MCP-aware extensions.

I added a starter config at:

- `.vscode/mcp.json`

What it contains:

- Context7
- OpenAI Developer Docs
- Playwright
- Memory
- Sequential Thinking
- GitHub remote MCP

If you use this route, you may still prefer Codex as the main chat/controller while letting VS Code manage the MCP server list.

## Phase 5: React-Specific Usage Rules

For React and frontend work, use this policy:

1. break work into UI structure, state, data flow, styling, browser behavior, and tests
2. do not accept claims about browser behavior without Playwright verification
3. for library-version questions, use Context7 or search before answering
4. store accepted UI decisions in memory
5. if the task is larger than one component, use Sequential Thinking first

## Playwright Safety Rules

Keep Playwright installed, but constrain it hard.

Default browser-validation policy:

1. use Playwright only against a user-provided URL
2. never scan localhost ports
3. never start frontend or backend servers unless explicitly requested
4. never stop existing servers unless explicitly requested
5. if the provided URL is unreachable, stop and report that clearly
6. prefer `127.0.0.1` over `localhost` when the user gives an explicit local endpoint

Recommended prompt pattern:

```text
Use Playwright only against http://127.0.0.1:3107.
Do not scan ports.
Do not start or stop any servers.
If the app is not reachable, stop and tell me.
```

Why this matters:

- avoids conflicts with other dev work
- avoids surprise binds on common ports like `3000` or `8000`
- makes Playwright a verification tool instead of an environment manager

If you work on multiple projects, assign fixed per-project ports and treat them as part of the project runtime contract.

Examples:

- "Use sequential-thinking to break this React refactor into component, state, and data-flow steps."
- "Use Playwright to reproduce the bug before editing the component."
- "Use search to verify the current React Router behavior before proposing a fix."

## Phase 6: Add A Local Model Later, Not First

Only add a local model after the Codex + MCP workflow is stable.

Why:

- a local model does not solve decomposition
- a local model does not solve memory
- a local model does not solve stale docs
- a local model does not solve browser verification

A local model is still useful later for:

- cheap drafts
- repetitive transforms
- low-risk boilerplate
- offline fallback

But it is not the first fix for the problems you described.

## Suggested Rollout Order

This is the order I would actually use:

1. Codex CLI + Codex IDE extension
2. built-in `--search`
3. Context7
4. OpenAI Developer Docs MCP
5. Memory MCP
6. Playwright MCP
7. GitHub MCP
8. Sequential Thinking MCP
9. optional local model later

Why Playwright ahead of Sequential Thinking:

- for React work, browser truth usually matters more than extra planning
- broken UI flows are easier to verify than to reason about abstractly

If you are doing architecture-heavy backend work for a week, swap 5 and 7.

## Minimal Day-One Setup

If you want the smallest useful setup, do only this:

```bash
codex mcp add context7 \
  -- npx -y @upstash/context7-mcp

codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp

codex mcp add memory \
  --env MEMORY_FILE_PATH="$(pwd)/.ai/memory.json" \
  -- npx -y @modelcontextprotocol/server-memory

codex mcp add playwright \
  -- npx @playwright/mcp@latest
```

Then run:

```bash
codex --search
```

That already gives you:

- version-aware library docs plus fresh web/docs search
- persistent project memory
- browser-backed React verification

## Validation Checklist

After setup, verify these:

- `codex mcp list` shows all expected servers
- Context7 can answer current library/framework questions
- Codex can answer current docs questions with search enabled
- Playwright can open your local app
- memory writes persist to `./.ai/memory.json`
- GitHub queries work for your repos

## Leave It As Is For Now

At this point, the biggest ChatGPT shortcomings are already covered:

- memory and continuity -> Memory MCP + repo instructions
- task decomposition -> Sequential Thinking
- stale docs -> built-in search + OpenAI docs MCP
- browser guessing -> Playwright
- GitHub context drift -> GitHub MCP

The next gains should come from usage discipline, not more tooling:

- start a fresh Codex thread for each distinct task
- save durable facts, chosen ports, and accepted decisions into memory
- provide the exact local URL when browser verification is needed
- explicitly say `search/docs if needed` for current or versioned questions

Only add more later if a failure pattern keeps repeating:

- if project state is still getting lost, add `CURRENT_STATE.md` or `DECISIONS.md`
- if long tasks still drift, tighten the task template or repo instructions
- if you keep reusing the same workflow, turn it into a skill

Recommended rule: use this setup for a week before adding new MCP servers or a second model.

## Copy This Setup To Another Computer

Use the installer script in this repo:

```bash
./codex/scripts/install-codex-mcp-setup.sh
```

What it does:

- checks for `node`, `npm`, `npx`, and `codex`
- creates the repo-local `.ai` memory directory
- configures the Codex MCP servers globally
- rewrites `.vscode/mcp.json` with the correct memory path for the current repo location
- optionally installs the VS Code Codex extension

Useful examples:

```bash
./codex/scripts/install-codex-mcp-setup.sh --install-vscode-extension
```

```bash
./codex/scripts/install-codex-mcp-setup.sh --prompt-github-pat
```

```bash
./codex/scripts/install-codex-mcp-setup.sh --skip-github
```

```bash
./codex/scripts/install-codex-mcp-setup.sh --memory-dir "$HOME/.codex-memory/local-dev"
```

Important GitHub note:

- the script configures the GitHub MCP to read `GITHUB_MCP_PAT`
- if you pass `--prompt-github-pat`, the script securely prompts for the token and writes a managed export block into the detected shell startup file
- on modern macOS with the default `zsh` shell, that will usually be `~/.zprofile`
- on `bash`, the script prefers `~/.bash_profile` if it exists and otherwise falls back to `~/.profile`
- the token itself is not stored by Codex
- for reliable non-interactive shells, use the shell startup file the installer picked or use `direnv`
- do not rely on a line placed below the early-return block in `~/.bashrc`
- writing the token to a shell startup file is convenient but stores it in plaintext on disk

## Troubleshooting

If MCP servers do not appear in the IDE:

- restart VS Code
- confirm you are signed into the same account
- run `codex mcp list` in the shell first

If Playwright fails:

- run it once from the CLI first
- make sure the target app is already running
- if Playwright guessed ports or tried to start services, tighten the prompt to a user-provided URL only

If GitHub MCP fails:

- verify the PAT
- verify the PAT scopes
- remove and re-add the server if needed

If memory feels noisy:

- keep one memory system
- store decisions, not raw chat transcripts

## Sources

- Codex IDE docs: https://developers.openai.com/codex/ide
- OpenAI Docs MCP: https://platform.openai.com/docs/docs-mcp
- OpenAI MCP docs: https://platform.openai.com/docs/mcp/
- Codex CLI README: https://github.com/openai/codex
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- GitHub MCP server: https://github.com/github/github-mcp-server
- MCP reference servers: https://github.com/modelcontextprotocol/servers
- MCP memory server npm package: https://www.npmjs.com/package/@modelcontextprotocol/server-memory
- MCP sequential thinking npm package: https://www.npmjs.com/package/@modelcontextprotocol/server-sequential-thinking
