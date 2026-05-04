# Global Codex Instructions

MCP servers are helpers, not decision-makers.

{{RULES_SECTIONS}}

## Core Policy

- Use search or docs tools for current, versioned, or uncertain information.
- Read `CURRENT_STATE.md` and `DECISIONS.md` at the start of non-trivial repo work when they exist. Update them when durable state or decisions change.
- Prefer the smallest patch that satisfies the requirement.

## Planning And Decomposition

Use `sequential-thinking` before multi-file work, refactors, architectural changes, or migration planning. Break the work into phases, risks, and file targets before writing code.

For complex tasks:
1. Plan with `sequential-thinking`.
2. Read durable project memory.
3. Break the task into concrete steps.
4. Use subagents only for independent work.
5. Verify after each phase, not just at the end.

## Memory Policy

Store only concise, reusable facts: architecture decisions, runtime conventions, accepted constraints, recurring commands, and project gotchas.

Use:

- `~/.codex/learnings/` for personal Codex learnings and eval output
- `CURRENT_STATE.md` and `DECISIONS.md` for human-readable repo memory

## Playwright / Browser Policy

Use Playwright for browser-truth questions, UI bugs, redirects, form behavior, and rendered-state checks. Do not rely on code inspection alone for visible behavior. Only use against user-provided URLs. Never scan localhost ports or infer ports. Never start or stop dev servers unless explicitly asked.

## Search And Docs

- Library, framework, and tool questions: use `context7` first when possible.
- OpenAI and Codex questions: use the OpenAI docs tools or official docs.
- Comparisons, opinions, and ecosystem questions: use search.
- If a remote docs MCP is unavailable, say so briefly and fall back to official docs or search.

## Spec-Kit

`specify` is installed globally via `uv`. Use it for multi-file features, migrations, refactors, or whenever the user asks for a written spec before code.

## Installed Codex Assets

- Global skills live in `~/.codex/skills/`
- Custom agents live in `~/.codex/agents/`
- Optional hooks config lives in `~/.codex/hooks.json`
- Optional learn-eval scheduler assets live in `~/.codex/cron/`
