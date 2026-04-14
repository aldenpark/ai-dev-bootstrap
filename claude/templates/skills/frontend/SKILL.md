---
name: frontend
description: Frontend development with React, TypeScript, and modern CSS
---

# Frontend Conventions

## Build and Test
- Check `package.json` scripts for the actual commands — don't guess.
- Common: `npm run dev`, `npm run build`, `npm run test`, `npm run lint`.
- If using pnpm or bun, match what the repo uses. Don't swap package managers.

## React
- Functional components only. No class components.
- Hooks for state and effects. Custom hooks for shared logic.
- Prefer composition over prop drilling — context for cross-cutting concerns.
- Co-locate components with their tests and styles.
- Memoize with `useMemo`/`useCallback` only when profiling shows a need, not preemptively.
- Use Suspense boundaries for async data loading where supported.

## TypeScript
- Strict mode enabled. No `any` unless unavoidable (and comment why).
- Prefer `interface` for object shapes, `type` for unions/intersections.
- Use `satisfies` for type-safe config objects.
- Exhaustive switch with `never` for discriminated unions.
- Import types with `import type` to keep bundles clean.

## Styling
- Check what the project uses (Tailwind, CSS Modules, styled-components, etc.) and match it.
- Don't introduce a new styling approach without asking.
- Responsive: mobile-first. Use relative units over fixed pixels.

## Common Pitfalls
- Verify UI changes visually — use Playwright or screenshots, don't assume from code.
- Don't install new dependencies for things that can be done with existing ones.
- Bundle size matters. Check imports aren't pulling in entire libraries.
- Server vs. client components (Next.js/RSC) — `"use client"` only when needed.
