# Local Qwen Coding Policy

- To reduce cloud token use, default to `qwen36-code` for bounded code drafting before writing non-trivial code.
- Use local Qwen for implementation sketches, small patches, refactor drafts, test drafts, and first-pass code review notes.
- Do not use local Qwen for planning, architecture decisions, security-sensitive reasoning, current docs lookup, broad repo analysis, final review, or final verification.
- Treat Qwen output as a draft only: Codex owns reading the code, applying patches, resolving conflicts, running tests, and final judgment.
- Keep Qwen prompts focused: pass only the relevant files with `qwen36-code -f path ...`; do not dump entire repos.
- If `qwen36-code` fails, is too slow, or produces weak output, continue with Codex and mention the fallback briefly.
