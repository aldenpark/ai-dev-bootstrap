---
name: mine-learnings
description: Mine past Claude Code sessions for cross-repo learnings and store them in a shared knowledge base.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
---

# Mine Learnings from Past Sessions

Extract actionable learnings from past Claude Code conversations and store them in `~/.claude/learnings/`.

## Process

### Step 1: Extract unprocessed sessions

Run the extraction script to get session transcripts that haven't been processed yet:

```bash
python3 ~/.claude/skills/mine-learnings/extract-sessions.py \
  --processed-file ~/.claude/learnings/.processed-sessions \
  --min-messages 6 \
  --max-sessions 20
```

Save the output to a temp file. If no sessions are returned, tell the user everything has been processed.

### Step 2: Analyze sessions in parallel batches

For each session, launch an Agent (subagent_type: "general-purpose") to analyze the transcript. Process up to 5 sessions in parallel.

Each agent should receive this prompt (fill in the transcript and project path):

```
You are analyzing a Claude Code conversation transcript to extract learnings.

Project: {project_path}
Session ID: {session_id}

TRANSCRIPT:
{transcript}

---

Analyze this conversation and extract any learnings worth preserving. Focus on:

1. **Problems solved**: What broke and why? What was the root cause?
2. **Cross-service interactions**: Any issues involving multiple services, APIs, or systems talking to each other?
3. **Debugging insights**: Non-obvious debugging techniques or diagnostic approaches that worked?
4. **Gotchas / pitfalls**: Things that were surprising or easy to get wrong?
5. **Patterns / conventions**: Coding patterns, architecture decisions, or conventions that were established?
6. **Configuration / environment**: Setup steps, config changes, or environment issues that were resolved?

For each learning found, output a JSON object with these fields:
- "title": Short descriptive title (under 80 chars)
- "category": One of: "debugging", "architecture", "gotcha", "cross-service", "configuration", "pattern", "performance", "testing"
- "services": Array of service/repo names involved (use short names like "documents-svc", "chunkembed-svc", "AssistMAX-UI", etc.)
- "problem": What was the problem? (2-3 sentences)
- "solution": What was the solution? (2-3 sentences)
- "why_it_matters": Why is this worth remembering? (1 sentence)
- "code_snippet": Optional relevant code snippet if applicable (or null)

If the session has NO meaningful learnings (e.g., it was just a simple task, routine work, or tool setup), return:
{"no_learnings": true, "reason": "brief explanation"}

Output ONLY valid JSON. Either a single object with no_learnings, or an array of learning objects.
Do NOT wrap in markdown code fences.
```

### Step 3: Collect and store results

After all agents complete:

1. Parse each agent's JSON output
2. Skip sessions with `no_learnings: true`
3. For sessions with learnings, append each learning to `~/.claude/learnings/learnings.jsonl` with added fields:
   - `session_id`: the source session
   - `project_path`: the source project
   - `mined_at`: current ISO timestamp
4. Append all processed session IDs (including no-learning ones) to `~/.claude/learnings/.processed-sessions` (one per line)

### Step 4: Generate summary

After processing, generate a markdown summary:

1. Read all learnings from `~/.claude/learnings/learnings.jsonl`
2. Group by category
3. Write a summary to `~/.claude/learnings/SUMMARY.md` with:
   - Total learnings count and date range
   - Learnings grouped by category, each showing title, services involved, and a one-line summary
   - A "Cross-Service Patterns" section highlighting any learnings that involve 2+ services
4. Display the summary to the user

### Step 5: Report

Tell the user:
- How many sessions were processed
- How many learnings were extracted
- How many sessions had no learnings
- Path to the summary file

## Notes

- The learnings directory is at `~/.claude/learnings/` — global, not per-repo
- Learnings are stored as JSONL for easy appending and querying
- The `.processed-sessions` file prevents reprocessing
- To reprocess everything, delete `~/.claude/learnings/.processed-sessions`
- To reset all learnings, delete `~/.claude/learnings/learnings.jsonl` and the processed file

## Optional: Export to ShareGPT for fine-tuning

If the user asks to export sessions for fine-tuning or model comparison (Opus vs Sonnet benchmarking, custom model training, etc.), run the companion script:

```bash
# All sessions with at least 4 turns
python3 ~/.claude/skills/mine-learnings/export-sharegpt.py \
  --out ~/.claude/learnings/sharegpt.jsonl

# Only sessions that already produced learnings — higher signal
python3 ~/.claude/skills/mine-learnings/export-sharegpt.py \
  --only-mined ~/.claude/learnings/learnings.jsonl \
  --out ~/.claude/learnings/sharegpt-mined.jsonl

# Filter by project
python3 ~/.claude/skills/mine-learnings/export-sharegpt.py \
  --project-filter SymanticSearch \
  --out ~/.claude/learnings/sharegpt-symantic.jsonl
```

Output format is standard ShareGPT — compatible with Axolotl, LLaMA-Factory, and Unsloth. Tool uses, tool results, and thinking blocks are preserved inline so the model learns the full trajectory, not just prose turns.
