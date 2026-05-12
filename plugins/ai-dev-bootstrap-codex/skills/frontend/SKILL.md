---
name: frontend
description: Frontend development with React, TypeScript, CSS, and browser verification. Use when the task changes visible UI, routing, forms, client state, or rendered behavior.
---

# Frontend Workflow

Use this skill when the user is changing browser-visible behavior.

## First pass

- Detect the framework and package manager from `package.json`, lockfiles, and config files before editing.
- Match the repo's existing patterns for styling, state, routing, and data loading.
- Read only the files that own the current flow before changing shared UI primitives.

## Build and validation

- Use the repo's own scripts for lint, test, typecheck, and build. Do not guess command names.
- For rendered-state questions, reproduce with Playwright on the user-provided URL instead of relying on code inspection alone.
- If the bug crosses code and runtime behavior, map the owning files first, then verify the browser behavior, then patch the smallest fix.

## React and TypeScript

- Prefer function components and hooks.
- Keep types explicit at boundaries. Avoid `any` unless the repo already uses it there and the tradeoff is justified.
- Respect server/client boundaries in Next.js or RSC-style apps.
- Do not add `useMemo` or `useCallback` by default. Follow the repo's compiler and performance guidance.

## Styling and dependencies

- Preserve the existing design system and visual language.
- Do not introduce a new styling stack, component library, or form library unless the user asks.
- Prefer existing utilities over new dependencies for small tasks.

## When Subagents Help

If the user explicitly asks for parallel or multi-agent work, use:

- `code_mapper` to locate the owning code paths
- `browser_debugger` to verify the rendered behavior and capture evidence
