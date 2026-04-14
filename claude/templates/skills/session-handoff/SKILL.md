---
name: session-handoff
description: Generate a briefing for a new Claude Code session from plan docs, memory, git state, and recent work. Run at the start of a session to get up to speed.
user-invocable: true
---

# Session Handoff

Reads all available context and generates a briefing so a new session can pick up where the last one left off.

## Usage

```
/session-handoff              # Full briefing for current workspace
/session-handoff chunkembed   # Focus on a specific area
```

## Process

### Step 1: Read persistent context

1. **CLAUDE.md** — read the workspace CLAUDE.md and any repo-specific CLAUDE.md files
2. **Memory** — read `~/.claude/projects/{project}/memory/MEMORY.md` and any referenced memory files
3. **Plans** — find any `.claude/plans/*.md` files and read them
4. **CURRENT_STATE.md** — if it exists in the workspace
5. **DECISIONS.md** — if it exists in the workspace

### Step 2: Check git state

For each git repo in the workspace:
```bash
git -C {repo} branch --show-current
git -C {repo} status --short
git -C {repo} log --oneline -5
git -C {repo} stash list
```

Report: current branch, uncommitted changes, recent commits, any stashes.

### Step 3: Check running infrastructure

```bash
docker ps --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -20
curl -s http://localhost:4566/_localstack/health 2>/dev/null  # LocalStack
curl -s http://localhost:9200/_cluster/health 2>/dev/null     # Elasticsearch
```

### Step 4: Check for in-progress work

- Any TODO lists in memory?
- Any open PRs for repos in the workspace? (`gh pr list` per repo)
- Any Optuna DBs with incomplete studies? (`sqlite3 *.db "SELECT name, count(*) FROM studies"`)

### Step 5: Generate briefing

```markdown
## Session Briefing — {date}

### Active Work
{Summary from plans/CURRENT_STATE — what was being worked on, what's done, what's next}

### Git State
| Repo | Branch | Uncommitted | Last Commit |
|------|--------|-------------|-------------|
| {repo} | {branch} | {Y/N + count} | {hash} {message} |

### Open PRs
- {repo}#{number}: {title} ({state}, {reviews})

### Infrastructure
- LocalStack: {running/stopped}
- Elasticsearch: {running/stopped}
- Docker: {N containers running}

### Key Context from Memory
{Top 3-5 most relevant memory entries for what's being worked on}

### Suggested Next Steps
{Based on plans and incomplete work, suggest what to do first}
```
