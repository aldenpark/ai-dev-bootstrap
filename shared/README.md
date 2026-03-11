# Shared Add-ons

This folder is for tools and patterns that improve both the `codex/` and `claude/` workflows.

## Implemented Next

These are now part of the repo baseline:

- `Context7` added to the installer/config path
- `evals/` starter added for `Promptfoo`
- file-based memory added with `CURRENT_STATE.md` and `DECISIONS.md`

## Recommended Additions

### Context7

Use this for version-specific framework and library docs.

Why it helps:

- reduces stale API answers
- works well with both Codex and Claude
- gives the agent current examples instead of generic training-data recall

Best use:

- React, Next.js, Vite, TypeScript, library migrations, and setup questions
- replacing generic “search the docs” prompts with version-aware retrieval

Implementation note:

- the installer/config path now includes `Context7` by default
- for higher rate limits, add a `CONTEXT7_API_KEY` in your normal shell environment

### Repomix

Use this when either agent needs a compact, AI-friendly representation of a larger codebase.

Why it helps:

- improves large-repo understanding
- useful when normal file-by-file context is too fragmented
- can be used on demand instead of as a default workflow step

Best use:

- architecture review
- large refactors
- onboarding an agent to an unfamiliar repo
- packing a repo for one-off deep review when normal context is not enough

### Promptfoo

Use this to evaluate prompts, workflow instructions, and model behavior over time.

Why it helps:

- lets you compare Codex vs Claude on your own tasks
- helps catch regressions when you change prompts, memory rules, or MCP setup
- gives you a way to measure whether the workflow actually improved

Best use:

- prompt regression tests
- agent comparison on representative coding tasks
- validating changes to `AGENTS.md`, `CLAUDE.md`, or setup instructions

### Aider-Inspired Ideas

I would not replace this repo's workflows with Aider, but two ideas are worth borrowing:

`Repo maps`

- keep a compact, navigable representation of the repo for larger codebases
- reduce the chance that the agent loses the structure of the project
- pairs well with Repomix or any future codebase-summary tooling

`Automatic verification after edits`

- run lint, typecheck, and tests automatically after meaningful code changes
- treat failures as part of the edit loop, not as a separate cleanup step
- this is especially useful once you start adding evals and more automation

## Recommended Adoption Order

If you want to add these without creating process bloat, use this order:

1. `Context7`
2. `Promptfoo`
3. `Repomix`
4. Aider-inspired `repo maps`
5. Aider-inspired `automatic verification`

Why this order:

- `Context7` fixes stale docs with very little overhead
- `Promptfoo` gives you a way to measure whether the workflow is improving
- `Repomix` helps on larger repos, but is best used on demand
- repo maps and automatic verification are valuable, but they work best once your shared workflow is already stable

## Agent-Specific Fit

These are shared tools, but they help the two agent paths in slightly different ways:

### Codex

- `Context7`: stronger current-doc retrieval than generic search alone
- `Promptfoo`: useful for testing prompt and `AGENTS.md` changes
- `Repomix`: useful when Codex needs a compact repo-wide view

### Claude

- `Context7`: complements Claude's built-in web search with cleaner versioned docs
- `Promptfoo`: useful for testing `CLAUDE.md`, hooks, and task-management prompts
- `Repomix`: useful when Claude's normal context or task flow loses the shape of the repo

## How To Think About These

- `Context7` improves correctness on current docs
- `Repomix` improves large-codebase context
- `Promptfoo` improves confidence and repeatability
- Aider-inspired patterns improve navigation and verification discipline

These should sit above the agent-specific stacks, not replace them.

## Memory Options

Current recommendation:

- keep the official MCP memory server as the primary structured memory backend
- use `CURRENT_STATE.md` and `DECISIONS.md` as the lightweight human-readable memory layer

Alternatives and tradeoffs:

`Built-in product memory`

- lowest setup cost
- weaker portability and weaker project-state reliability

`Memory Bank pattern`

- stronger project narrative and progress tracking
- more process overhead and more duplication risk

`RAG / vector memory`

- stronger fuzzy retrieval across lots of documents
- more moving parts and more complexity than most repos need

For this repo, the current combination is the best default:

- structured MCP memory
- lightweight markdown state files
