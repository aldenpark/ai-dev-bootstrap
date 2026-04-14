---
name: python
description: Python development conventions with Poetry, ruff, pytest, and async patterns
---

# Python Conventions

## Build and Test
- Package manager: Poetry (`poetry install`, `poetry run <cmd>`)
- Lint: `poetry run ruff check .` (autofix: `--fix`)
- Format: `poetry run ruff format .`
- Type check: `poetry run mypy src/`
- Test: `poetry run pytest`
- Single test: `poetry run pytest tests/unit/path/test_x.py::test_name`
- Coverage: `poetry run pytest --cov=src --cov-report=term-missing`
- If repo has Makefile, prefer `make test`, `make lint`, etc.

## Pre-commit
- Most Python repos enforce `ruff check` + `mypy` on commit.
- **Always run both before committing**: `poetry run ruff check . && poetry run mypy src/`
- If either fails, fix and re-run before attempting `git commit`.

## Patterns
- Python 3.12+ target.
- Ruff replaces black/isort/flake8 (except `eng-shared-calleridentitypython-lib` which uses the old stack).
- Ruff config lives in `pyproject.toml`. Read it for the actual rule set.
- Async/await for I/O operations. `asyncio_mode = "auto"` in pytest.
- Pydantic models for data validation and serialization.
- Factory pattern for service clients (SQS, S3, LLM providers).
- Multi-process architecture: FastAPI health server + async worker via `multiprocessing.spawn`.
- `device_map="auto"` required when loading models with AutoModel (otherwise runs on CPU, 30x slower).

## Style
- Line length: 100 characters (ruff enforces this).
- Google-style docstrings.
- Import sorting: ruff isort with `known-first-party` configured per repo.
- Only import sorting (`I`) is auto-fixable by ruff.

## Common Pitfalls
- Private packages from CodeArtifact. Run `aws-login.sh` if `poetry install` fails.
- `AWS_ENDPOINT_URL` breaks Bedrock SSO credential resolution. Use service-specific endpoint vars for LocalStack.
- Always kill zombie processes from previous runs before restarting services.
- Each service uses its own venv — strip `VIRTUAL_ENV` and `PYTHONPATH` when spawning subprocesses.
