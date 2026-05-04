---
name: mine-learnings
description: Mine archived Codex sessions for reusable learnings and recurring workflows. Use when the user wants to extract durable lessons, debugging notes, or future skills from past sessions.
---

# Mine Learnings

This skill works from archived Codex sessions stored under `~/.codex/archived_sessions/`.

## Step 1: Extract candidate sessions

Run the extractor and save the result to a temp file:

```bash
python3 ~/.codex/skills/mine-learnings/scripts/extract-sessions.py \
  --processed-file ~/.codex/learnings/.processed-sessions \
  --max-sessions 20 \
  --min-user-turns 4 \
  --min-tool-calls 3
```

If the output is empty, report that there are no unprocessed sessions that meet the threshold.

## Step 2: Extract durable learnings

For each session, focus on durable facts:

- root causes and fixes
- debugging approaches that worked
- configuration gotchas
- recurring commands or workflows
- patterns that should become a skill or agent

Store the results in `~/.codex/learnings/learnings.jsonl`. Add:

- `session_id`
- `cwd`
- `source_file`
- `mined_at`

Do not store raw transcripts as the learning itself.

## Step 3: Update summary files

- Append processed session IDs to `~/.codex/learnings/.processed-sessions`
- Refresh `~/.codex/learnings/SUMMARY.md` with grouped learnings and recent additions
- If a session looks like a reusable workflow, note that in `~/.codex/learnings/skill-drafts/`

## Optional export

If the user asks to export session data for evals, fine-tuning experiments, or model comparison, use:

```bash
python3 ~/.codex/skills/mine-learnings/scripts/export-sharegpt.py \
  --out ~/.codex/learnings/sharegpt.jsonl
```

You can restrict the export:

```bash
python3 ~/.codex/skills/mine-learnings/scripts/export-sharegpt.py \
  --project-filter ai-dev-bootstrap \
  --out ~/.codex/learnings/sharegpt-ai-dev-bootstrap.jsonl
```
