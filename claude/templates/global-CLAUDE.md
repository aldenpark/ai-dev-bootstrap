# Global Claude Instructions

MCP servers are helpers, not decision-makers.

## Core Policy

- Use `sequential-thinking` before multi-file work, refactors, or architectural changes. Do not skip decomposition on complex tasks.
- Use `memory` to persist durable decisions, architecture notes, chosen ports, accepted constraints, and recurring commands. Do not dump raw chat transcripts into memory.
- Read `CURRENT_STATE.md` and `DECISIONS.md` at the start of non-trivial repo work, if they exist.
- Update `CURRENT_STATE.md` and `DECISIONS.md` when durable repo-level state or decisions change.
- Use web search or docs tools for current, versioned, or uncertain information.
- Prefer the smallest patch that satisfies the requirement.
- Use tests, lint, type checks, and browser verification as the final arbiters.

## Sequential Thinking Policy

- For any task spanning more than two files, use `sequential-thinking` to break it into phases, risks, and file targets before writing code.
- For architecture decisions, use `sequential-thinking` to evaluate tradeoffs before committing to an approach.
- For refactors and migrations, use `sequential-thinking` to plan the order of changes and identify rollback points.

## Memory Policy

Store only concise, reusable facts:

- architecture decisions and rationale
- runtime conventions and chosen ports
- accepted implementation constraints
- recurring commands and workflows
- project-specific patterns and gotchas

Read memory at the start of non-trivial tasks to avoid repeating past mistakes or contradicting prior decisions.

For human-readable repo state, use:

- `CURRENT_STATE.md`
- `DECISIONS.md`

## React and Browser Policy

- Use Playwright for browser-truth questions, UI bugs, navigation flows, and rendered-state checks.
- Do not rely on code inspection alone for claims about visible browser behavior when Playwright can verify it.
- For UI bugs, redirects, auth flow behavior, form behavior, rendered-state questions, and page-level React issues, use Playwright by default even if the user does not explicitly ask for it.
- If the user explicitly says not to use Playwright, follow that instruction.

## Playwright Guardrails

- Use Playwright only against a user-provided URL.
- Never scan localhost ports.
- Never infer a port if the user did not provide one.
- Never start frontend or backend dev servers unless the user explicitly asks.
- Never stop running services unless the user explicitly asks.
- If the provided URL is unreachable, stop and report that directly.
- Prefer `127.0.0.1` when the user gives an explicit local endpoint.

## Suggested Prompt Behavior

For browser work, follow this pattern:

1. confirm the target URL from the user context
2. open that URL with Playwright
3. inspect the rendered behavior
4. summarize the finding
5. only then propose the smallest fix

## Search and Docs

- If the user asks for the latest or current behavior, search before answering.
- If a remote docs MCP is unavailable, say so briefly and fall back to official docs or search.

### When to use Context7

Use `context7` when the question involves **how to use a library, framework, or tool** — even if you only have a vague or partial name. Context7 can resolve fuzzy names via `resolve-library-id`, so treat it as the default for any documentation lookup.

Examples:
- "What props does Next.js `<Image>` accept?" → context7
- "How do I configure Vitest coverage?" → context7
- "What's that React animation library?" → context7 (resolve-library-id can find it)
- "How do I set up that Tailwind plugin for forms?" → context7
- "What's the ORM that uses decorators in TypeScript?" → context7

### When to use web search instead

Use web search when the question is **comparative, opinion-based, error-diagnostic, or about ecosystem trends** rather than how to use a specific tool.

Examples:
- "What's the best React state management library in 2026?" → web search
- "How does Bun compare to Node for serverless?" → web search
- "Why is my Vercel deploy failing with exit code 1?" → web search

### Rule of thumb

If the answer lives in a library's docs, start with context7 — even with a vague name. If the answer requires community discussion, comparisons, or error troubleshooting, start with web search.

## Spec-Kit (Spec-Driven Development)

The `specify` CLI (GitHub Spec Kit) is installed globally via `uv`. Use it for spec-driven development.

- `specify init <project-name> --ai claude` — scaffold a new spec-driven project
- `specify init . --ai claude` — add spec-kit to the current project
- `specify check` — verify the environment

When to use:

- New features spanning multiple files or components
- Refactors, migrations, or architectural changes
- Any task where the user asks for a spec or structured breakdown

When starting a non-trivial feature, check if the project has a `.specify/` directory. If it does, read existing specs before making changes. Specs are the source of truth for what to build.

## Task Decomposition

For complex tasks, follow this order:

1. Use `sequential-thinking` to plan phases and file targets.
2. Use `memory` to check for prior decisions that affect the plan.
3. Break the plan into TodoWrite items.
4. Identify which phases are independent and can run in parallel.
5. Execute phases, using parallel sub-agents for independent work.
6. Update memory with decisions as they are made.
7. Use tests and verification after each phase, not just at the end.

## Parallelism Policy

Claude Code can spawn concurrent sub-agents via the Agent tool. Use this to turn serial bottlenecks into parallel work.

When to parallelize:

- Multiple files need independent changes (e.g., API endpoint + frontend component).
- Research tasks are independent of each other (e.g., check docs + explore codebase).
- Tests can run in the background while the next phase starts.
- Multiple independent code reviews or searches.

When NOT to parallelize:

- One task depends on the output of another.
- Changes touch the same files or shared state.
- The task requires sequential human review between steps.

Pattern:

1. Decompose the work with `sequential-thinking`.
2. Identify independent subtasks from the plan.
3. Spawn sub-agents for independent subtasks simultaneously.
4. Wait for all sub-agents to complete.
5. Integrate results and verify.

For risky or experimental changes, use worktree isolation:

- Sub-agents can run in isolated git worktrees so the main working tree stays clean.
- If the experiment fails, the worktree is discarded with no cleanup needed.
- If it succeeds, the changes can be merged back.
