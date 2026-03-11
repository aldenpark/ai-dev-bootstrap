# AGENTS.md

This repo uses Codex as the primary controller. MCP servers are helpers, not decision-makers.

## Core Policy

- Use `search` or docs tools for current, versioned, or uncertain information.
- Use `sequential-thinking` before multi-file work, refactors, or architectural changes.
- Write short, durable decisions to memory. Do not dump raw chat transcripts into memory.
- Prefer the smallest patch that satisfies the requirement.
- Use tests, lint, type checks, and browser verification as the final arbiters.

## React And Browser Policy

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

## Search And Docs

- If the user asks for the latest or current behavior, search before answering.
- If the task depends on OpenAI or Codex docs, use the OpenAI docs MCP when available.
- If a remote docs MCP is unavailable, say so briefly and fall back to official docs or search.

## Memory

Store only concise, reusable facts such as:

- architecture decisions
- runtime conventions
- chosen ports and local URLs
- accepted implementation constraints
- recurring commands
