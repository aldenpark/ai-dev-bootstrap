---
name: qwen36-coder
description: Use local Qwen3.6 through llama.cpp for bounded code drafting by default before non-trivial code edits, especially when reducing Codex cloud token use matters.
---

# Qwen3.6 Coding Worker

Use `qwen36-code` as a subordinate coding worker, not as the primary Codex model.

## When To Use

- The task needs non-trivial code generation or test drafting.
- The user asks to use local Qwen/Qwen3.6 for code generation.
- The task is a bounded implementation, refactor, or review subtask where Codex can apply and verify the output.
- Token spend matters and a local first draft is useful.

## Command

```bash
qwen36-code -f path/to/file 'Prompt describing the requested code change'
```

For larger prompts, pipe instructions on stdin:

```bash
cat prompt.md | qwen36-code -f src/file.ts
```

## Runtime Behavior

- `qwen36-code` starts `qwen36-server` on demand if it is not already listening.
- If the command started the server, it stops the server when done.
- Set `QWEN36_KEEP_SERVER=1` to keep the model hot across multiple calls.
- Default endpoint is `http://127.0.0.1:8080/v1`.

## Guardrails

- Treat Qwen output as a draft; Codex owns final edits, tests, and reconciliation.
- Do not wire `llama-server` directly as a Codex model provider until the tool schema mismatch is solved.
- Prefer small file sets and concrete prompts; do not dump an entire repo into the local model.
