---
name: python
description: Python development workflow for services, CLIs, tests, and automation. Use when the task changes Python code, packaging, linting, typing, or async behavior.
---

# Python Workflow

## First pass

- Detect the toolchain from `pyproject.toml`, `requirements*.txt`, `uv.lock`, `poetry.lock`, `tox.ini`, `noxfile.py`, `Makefile`, and CI files.
- Match the repo's existing package manager and execution pattern. Do not swap `uv`, `poetry`, `pip`, `pip-tools`, or `tox` unless the user asks.
- Read the configured lint, format, typecheck, and test settings before editing.

## Editing guidance

- Prefer targeted changes over broad cleanup.
- Preserve the repo's typing style. Tighten types at boundaries when it reduces real ambiguity.
- In async code, avoid blocking calls and mixed sync/async control flow.
- Follow the existing data-modeling pattern for the repo, whether that is `dataclasses`, `pydantic`, plain dicts, or ORM models.

## Validation

- Run the narrowest useful test first, then the broader suite if the repo supports it.
- Use configured lint and typecheck commands when they exist.
- If the repo has a `Makefile` or task runner, prefer those entry points over re-creating command sequences.

## Common mistakes

- Do not assume `pytest`, `ruff`, or `mypy` are present just because the repo is Python.
- Do not add new runtime dependencies for small helper tasks that the standard library can handle.
- If packaging or CLI behavior changes, verify the installed entry point or module invocation path still works.
