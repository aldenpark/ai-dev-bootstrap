---
name: session-handoff
description: Generate a fast briefing for a new Codex session from repo instructions, repo memory, specs, and git state. Use at the start of a session to get oriented.
---

# Session Handoff

## Read durable context

- Read `AGENTS.md` files that apply to the current working directory.
- Read `CURRENT_STATE.md` and `DECISIONS.md` when they exist.
- Read active planning docs such as `specs/`, `plans/`, or repo-specific planning folders when present.

## Inspect live state

- Summarize the current branch, uncommitted changes, and recent commits.
- If there are multiple git repos in the workspace, report each one separately.
- Note any stashes or obviously paused work.

## Produce a briefing

Return a short handoff with these sections:

- `Active work`: what appears to be in progress
- `Git state`: branch, dirty files, and recent commits
- `Relevant memory`: the 3-5 facts from repo memory that matter most right now
- `Next steps`: the smallest credible next actions

Keep it concise. The point is to compress orientation time, not restate every file.
