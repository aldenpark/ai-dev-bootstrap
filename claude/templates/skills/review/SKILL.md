---
name: review
description: Comprehensive code review for NetDocuments AI services. Spawns specialized sub-agents in parallel based on what changed.
user-invocable: true
---

# NetDocuments Code Review

Multi-agent code review tailored to the NetDocuments AI platform. Analyzes the diff, selects relevant reviewers, and produces a unified report.

## Usage

```
/review              # Adversarial dual-pass review of uncommitted changes (default)
/review PR_URL       # Adversarial dual-pass review of a GitHub PR
/review PR_NUMBER    # Adversarial dual-pass review of a PR by number
/review --files      # Adversarial dual-pass review of staged files only
/review --quick      # Single-pass review (faster, less thorough)
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
*asyncio*, *subprocess*, *ThreadPool*, *Semaphore*, *sleep*, *queue*, *visibility* → python-concurrency
*batch*, *parallel*, *concurrent*, *throughput*, *ratelimit*, *embedding_texts*, *max_workers* → performance
terraform/iam.tf, terraform/policy.tf, *Permission*, *iam* → aws-permissions
Dockerfile*, docker-compose*, *.dockerfile → docker-compose
*CloudEvent*, *cloud_event*, *specversion*, *PascalCase*, events/ → cloud-events
*sqs*, *queue*, *fifo*, *visibility*, *redrive*, *dlq* → sqs-configuration
requirements.txt, pyproject.toml, setup.py, *__version__*, Dockerfile.scout → dependency-versions
*error*, *exception*, *retry*, *dlq*, *backoff*, *circuit* → error-handling
*logger*, *logging*, *log_level*, *LOG_LEVEL*, *metric*, *doc:* → logging-standards
(always)                → learnings-check
```

A file can trigger multiple reviewers. Log which reviewers are being launched and why.

### Step 3: Launch reviewers

**Default (adversarial dual-pass):** Skip to **Step 3A: Adversarial Dual-Pass**.

**If `--quick` is set:** Use single-pass mode below instead.

#### Single-pass mode (`--quick`)

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

---

## Adversarial Dual-Pass (default mode)

The default review mode. Runs two independent review passes and reconciles findings. Use `--quick` to skip this and run a single pass instead.

### Step 3A: Launch two independent review passes

Launch **Pass A** and **Pass B** as completely independent background agents. Each pass runs the full reviewer dispatch (Step 2's file classification → select reviewers → launch reviewer sub-agents → collect findings).

**Isolation rules:**
- Pass A and Pass B MUST NOT share context, findings, or intermediate results
- Launch both using `run_in_background: true` so they run in parallel
- Each pass gets the same diff, repo path, and reviewer selection — nothing else

Each pass agent prompt:
```
You are Review Pass {A|B} in an adversarial dual-review. Run a full code review of the provided diff.

1. Read the diff and classify changed files using the reviewer selection rules
2. For each triggered reviewer, read its prompt from ~/.claude/skills/review/reviewers/{name}.md
3. Execute each reviewer's analysis against the diff and source files
4. Collect all findings as JSON: [{severity, title, file, line, problem, suggestion, proof}]
5. Return the complete findings list

Line numbers must be source-file line numbers, not diff offsets.
Be thorough — your findings will be compared against an independent pass.
```

### Step 4A: Reconcile findings

Once both passes complete, act as the **Reconciler**. Compare findings:

| Category | Meaning | Action |
|----------|---------|--------|
| **Agreed** | Both passes flagged same issue (same file, same/adjacent lines, same category) | Keep — high confidence |
| **Unique-A** | Only Pass A found it | Verify — read source, confirm valid or drop as false positive |
| **Unique-B** | Only Pass B found it | Verify — read source, confirm valid or drop as false positive |
| **Contradicted** | Passes disagree on same code | Read source, check against reviewer rules, make a ruling |

For each unique or contradicted finding, read the actual source file and make a ruling.

### Step 5A: Generate adversarial report

Use the same P1/P2/P3 report format as standard mode, but add these sections:

```markdown
## Code Review Results (Adversarial)

### Convergence Summary
- Pass A: {N} findings | Pass B: {M} findings
- Agreed: {X} | Unique-A: {Y} (kept/dropped) | Unique-B: {Z} (kept/dropped) | Contradictions: {W}
- **Confidence: {High|Medium|Low}**

### P1 — Must Fix ...
{same format as standard, each finding tagged [agreed|verified-A|verified-B]}

### Contradictions Resolved
- **{file}:{line}** — Pass A: {X}. Pass B: {Y}. **Ruling:** {decision + reasoning}

### Blind Spots
{Patterns where one pass consistently missed issues the other caught}
```

**Confidence scoring:**
- **High**: >80% of findings agreed, no unresolved contradictions
- **Medium**: 50-80% agreement, or 1-2 contradictions resolved with clear reasoning
- **Low**: <50% agreement, or rulings that required judgment calls

### Step 6A: Post findings (GitHub PRs only)

Same as standard Step 6, but prefix each comment with `[Adversarial — {Agreed|Verified}]`.

---

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
| python-concurrency | `reviewers/python-concurrency.md` | *asyncio*, *subprocess*, *ThreadPool*, *sleep*, *queue* |
| performance | `reviewers/performance.md` | *batch*, *parallel*, *concurrent*, *ratelimit*, *embedding_texts* |
| aws-permissions | `reviewers/aws-permissions.md` | terraform/iam.tf, terraform/policy.tf |
| docker-compose | `reviewers/docker-compose.md` | Dockerfile*, docker-compose* |
| cloud-events | `reviewers/cloud-events.md` | *CloudEvent*, *specversion*, events/ |
| sqs-configuration | `reviewers/sqs-configuration.md` | *sqs*, *queue*, *fifo*, *visibility*, *dlq* |
| dependency-versions | `reviewers/dependency-versions.md` | requirements.txt, pyproject.toml, setup.py, Dockerfile.scout |
| error-handling | `reviewers/error-handling.md` | *error*, *exception*, *retry*, *dlq*, *backoff* |
| logging-standards | `reviewers/logging-standards.md` | *logger*, *logging*, *log_level*, *metric* |
| learnings-check | `reviewers/learnings-check.md` | always |
