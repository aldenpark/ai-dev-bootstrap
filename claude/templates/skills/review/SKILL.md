---
name: review
description: Comprehensive code review for NetDocuments AI services. Spawns specialized sub-agents in parallel based on what changed.
user-invocable: true
---

# NetDocuments Code Review

Multi-agent code review tailored to the NetDocuments AI platform. Analyzes the diff, selects relevant reviewers, and produces a unified report.

## Usage

```
/review              # Review uncommitted changes
/review PR_URL       # Review a GitHub PR
/review PR_NUMBER    # Review a PR by number (infers repo from cwd)
/review --files      # Review only staged files
```

## Process

### Step 1: Determine review target

Parse the argument:
- No argument: `git diff HEAD` for uncommitted changes
- PR URL or number: fetch the diff via `gh pr diff`
- `--files`: `git diff --cached`

**Repo resolution for PR URLs:** When the argument is a GitHub PR URL (e.g. `https://github.com/NetDocs-Apps/repo-name/pull/123`), extract the repo name from the URL and locate the local checkout under `~/source/netdocuments/`. Search all subdirectories: `find ~/source/netdocuments -maxdepth 2 -type d -name "<repo-name>"`. If found, `cd` into it before fetching the diff or launching agents — this ensures agents can read source files for context. If not found locally, warn the user and proceed with diff-only review.

Save the diff to a temp file. If the diff is empty, tell the user and stop.

### Step 2: Analyze the diff to select reviewers

Read the diff and classify changed files:

```
*.cs, *.csproj          → dotnet-reviewer
*.py                    → python-reviewer
*.tsx, *.jsx, *.ts      → react-reviewer
appsettings*.json, *.tfvars, terraform/, *.tf → config-safety
(any code changes)      → test-coverage
Tools/, Filters/, *Mcp*, *mcp* → agent-interface
*Polly*, *HttpClient*, *cache*, *retry*, *resilience*, *Circuit* → resilience
*metric*, *counter*, *histogram*, *Instrumentation*, *otel*, *telemetry*, *span* → observability
*auth*, *dlp*, *token*, *prompt*, *cabinet*, *membership* → cross-service
(always)                → learnings-check
```

A file can trigger multiple reviewers. Log which reviewers are being launched and why.

### Step 3: Launch reviewers in parallel

For each selected reviewer, read its prompt from `reviewers/{name}.md` (relative to this skill's directory). Launch an Agent (subagent_type: "general-purpose") with the prompt contents. Run all agents in parallel using `run_in_background: true`.

Pass each agent:
- The diff content (or path to diff file)
- The repo name and branch
- The local repo checkout path (so agents can read actual source files)
- The reviewer-specific instructions from the prompt file

**Critical — line numbers must be source-file line numbers, not diff offsets:**
Instruct each agent that the `line` field in findings MUST be the line number in the actual source file on the PR branch, NOT the position within the diff. Agents must `grep -n` or read the source file to confirm the real line number before reporting. Diff offsets are meaningless to the reviewer and make findings hard to locate.

### Step 4: Collect results

As agents complete, collect their findings. Each agent returns findings as JSON:

```json
[
  {
    "severity": "P1|P2|P3",
    "title": "Short title",
    "file": "path/to/file.cs",
    "line": 42,
    "problem": "What's wrong",
    "suggestion": "How to fix it",
    "proof": "Why this matters / evidence"
  }
]
```

If an agent returns `{"no_findings": true}`, skip it.

### Step 5: Generate unified report

Combine all findings, deduplicate by file+line, sort by severity, and output:

```markdown
## Code Review Results

### P1 — Must Fix (N findings)
- **[dotnet] Missing test trait attribute** `test/FooTests.cs:8`
  Problem: ...
  Fix: ...

### P2 — Should Fix (N findings)
- ...

### P3 — Consider (N findings)
- ...

### Learnings Match
- Past gotcha "Redis Cache Failure Cascades" is relevant to changes in CacheExtensions.cs

### Summary
- N files changed, M reviewers ran, X findings (P1: a, P2: b, P3: c)
```

### Step 6: Post findings as draft PR review (GitHub PRs only)

If the review target is a GitHub PR (URL or number), post all P1 and P2 findings as pending review comments in a draft review. This runs as a background agent after the report is shown to the user.

**How it works:**
1. Build a JSON payload with a `comments` array — one entry per P1/P2 finding
2. Each comment needs `path`, `line`, `side: "RIGHT"`, and `body` (markdown-formatted finding)
3. The `line` must be within a diff hunk. For findings on lines NOT in the diff, comment on the nearest line that IS in the hunk and reference the actual line in the body.
4. Create the review via `gh api repos/{owner}/{repo}/pulls/{number}/reviews --input <payload-file>`
5. **Omit the `event` field** — this creates a PENDING review (draft). The `event: "PENDING"` value is NOT valid and will 422.
6. Comments are only visible to the review author until they manually publish the review on GitHub.

**Comment body format:**
```
**P1: Short title**

Problem description.

**Suggestion:** How to fix it.
```

**Skip this step for:**
- Non-PR reviews (uncommitted changes, staged files)
- ADO-hosted repos (ADO does not support draft/pending reviews — comments are immediately visible)

## Reviewer Prompts

Each reviewer's prompt is stored in `reviewers/{name}.md`:

| Reviewer | File | Triggers on |
|----------|------|-------------|
| dotnet-reviewer | `reviewers/dotnet-reviewer.md` | *.cs, *.csproj |
| python-reviewer | `reviewers/python-reviewer.md` | *.py |
| react-reviewer | `reviewers/react-reviewer.md` | *.tsx, *.jsx, *.ts |
| config-safety | `reviewers/config-safety.md` | appsettings*.json, *.tfvars, terraform/ |
| test-coverage | `reviewers/test-coverage.md` | any code changes |
| agent-interface | `reviewers/agent-interface.md` | Tools/, Filters/, *Mcp* |
| resilience | `reviewers/resilience.md` | *Polly*, *HttpClient*, *cache*, *retry* |
| observability | `reviewers/observability.md` | *metric*, *Instrumentation*, *otel* |
| cross-service | `reviewers/cross-service.md` | *auth*, *dlp*, *token*, *cabinet* |
| learnings-check | `reviewers/learnings-check.md` | always |
