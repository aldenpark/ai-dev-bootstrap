# Code Style Rules

- Prefer the smallest patch that satisfies the requirement.
- Fix root cause, not band-aid. If unsure, read more code; if still stuck, ask with short options.
- Keep edits small and reviewable. No repo-wide search/replace scripts.
- Keep files under ~500 LOC; split/refactor when they grow.
- Don't add features, refactor, or "improve" beyond what was asked.
- Don't add error handling or validation for scenarios that can't happen.
- Don't create helpers or abstractions for one-time operations.
- Three similar lines of code is better than a premature abstraction.
- Read code before configuring. Never guess at config values, URL paths, format names, or flags.
