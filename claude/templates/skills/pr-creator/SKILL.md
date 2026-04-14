---
name: pr-creator
description: Runs code review, lint, tests, then creates a branch, commits, pushes, and opens a PR. Will not proceed if review finds P1 issues.
user-invocable: true
---

# PR Creator

Creates a pull request from uncommitted changes with full quality gates.

## Usage

```
/pr-creator STORY_ID "Short description"
/pr-creator 436740 "add jitter backoff to shared library"
```

## Process

### Step 1: Validate inputs

- Parse STORY_ID and description from arguments
- Confirm there are uncommitted changes: `git diff --stat HEAD`
- If no changes, tell the user and stop
- Determine repo name from `git remote -v`

### Step 2: Run /review on uncommitted changes

Run the `/review` skill on the current uncommitted changes. This is a **blocking gate** — the PR will NOT proceed if:

- Any **P1** findings exist → STOP. Show findings. Tell the user to fix them first.
- **P2** findings → WARN but continue. Show them in the PR description.
- **P3** findings → Note them but don't block.

If review passes (no P1s), continue.

### Step 3: Run lint and tests

Detect the project type and run appropriate checks:

**Python (Poetry):**
```bash
poetry run ruff check .
poetry run mypy src/  # if src/ exists
poetry run pytest tests/
```

**Python (Makefile):**
```bash
make lint
make test
```

**C# (.NET):**
```bash
dotnet format --verify-no-changes
dotnet test *.sln
```

If lint or tests fail → STOP. Show failures. Tell the user to fix them first.

### Step 4: Create branch and commit

Branch naming convention: `ai/ap/{STORY_ID}-{description_slug}`

```bash
# Create slug from description (lowercase, hyphens, max 50 chars)
SLUG=$(echo "{description}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)
BRANCH="ai/ap/{STORY_ID}-${SLUG}"

git checkout -b "$BRANCH"
git add -A
```

**Commit message format** (Conventional Commits):
```
feat|fix|refactor|docs|test|chore: {description}

AB#{STORY_ID}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

Infer the commit type from the changes:
- New files/features → `feat`
- Bug fixes, error handling → `fix`
- Code restructuring → `refactor`
- Test changes only → `test`
- Config/build changes → `chore`
- Documentation → `docs`

### Step 5: Push and create PR

```bash
git push -u origin "$BRANCH"
```

Create PR with `gh pr create`:

```bash
gh pr create --title "{type}: {description}" --body "$(cat <<'EOF'
## Summary

{2-3 bullet points describing what changed and why}

## Review Findings

{P2/P3 findings from the /review step, if any — or "No findings"}

## Test Plan

- [ ] Unit tests pass
- [ ] Lint clean
- [ ] {any specific manual verification steps}

AB#{STORY_ID}

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Do NOT assign reviewers.** The user handles reviewer assignment.

### Step 6: Report

```
## PR Created

Branch: ai/ap/{STORY_ID}-{slug}
PR: {PR_URL}
Review: {N findings (P2: x, P3: y) | Clean}
Tests: Passed
Lint: Clean
```

## Important Rules

1. **Never skip the /review step.** It must run and pass (no P1s) before any commit.
2. **Never assign reviewers.**
3. **Branch must follow `ai/ap/{STORY_ID}-{slug}` format.**
4. **Never force push or amend.**
5. **If anything fails (review P1, lint, tests), stop and explain what to fix.**
