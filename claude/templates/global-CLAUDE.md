# Global Claude Instructions

MCP servers are helpers, not decision-makers.

@rules/communication.md
@rules/code-style.md
@rules/testing.md
@rules/git.md
@rules/diagrams.md

## Core Policy

- Use web search or docs tools for current, versioned, or uncertain information.
- Read `CURRENT_STATE.md` and `DECISIONS.md` at the start of non-trivial repo work, if they exist. Update them when durable state or decisions change.

## Planning and Decomposition

Use `sequential-thinking` before multi-file work, refactors, architectural changes, or migration planning. Break into phases, risks, and file targets before writing code. Skip it for single-file or obvious changes.

For complex tasks:
1. Plan with `sequential-thinking`.
2. Check `memory` for prior decisions.
3. Break into TodoWrite items.
4. Spawn parallel sub-agents for independent subtasks.
5. Verify after each phase, not just at the end.

For risky or experimental changes, use worktree isolation — sub-agents work on isolated copies, discard on failure, merge on success.

## Memory Policy

Store only concise, reusable facts: architecture decisions, runtime conventions, accepted constraints, recurring commands, project gotchas. Read memory at the start of non-trivial tasks. For human-readable repo state, use `CURRENT_STATE.md` and `DECISIONS.md`.

## Playwright / Browser Policy

Use Playwright for browser-truth questions, UI bugs, and rendered-state checks. Don't rely on code inspection alone for visible behavior. Only use against user-provided URLs — never scan localhost ports or infer ports. Never start/stop dev servers unless explicitly asked.

## Search and Docs

- Library/framework/tool questions: use `context7` first (it resolves fuzzy names).
- Comparisons, opinions, error diagnostics, ecosystem trends: use web search.
- If a remote docs MCP is unavailable, say so and fall back to official docs or search.

## Spec-Kit

`specify` CLI (GitHub Spec Kit) installed globally via `uv`. Use for new features spanning multiple files, refactors, migrations, or when user asks for a spec. Check for `.specify/` directory before starting non-trivial features — specs are source of truth.
