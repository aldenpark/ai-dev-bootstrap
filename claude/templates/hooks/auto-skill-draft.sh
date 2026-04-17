#!/usr/bin/env bash
# Stop hook: detect sessions that look like reusable workflows and draft skills.
#
# Input (stdin, JSON from Claude Code):
#   { "session_id": "...", "transcript_path": "/path/to/session.jsonl",
#     "hook_event_name": "Stop", "stop_hook_active": false, ... }
#
# Behavior:
#   1. Read transcript, count user turns + tool uses.
#   2. If below threshold (short session), exit 0 quietly.
#   3. Otherwise fork a background process that invokes `claude -p` to analyze
#      the transcript and emit a SKILL.md draft into ~/.claude/skills/drafts/.
#   4. Return immediately so the Stop event isn't blocked on LLM latency.
#
# Tunable via env:
#   AUTO_SKILL_MIN_USER_TURNS  (default 6)
#   AUTO_SKILL_MIN_TOOL_CALLS  (default 8)
#   AUTO_SKILL_DRAFTS_DIR      (default ~/.claude/skills/drafts)
#   AUTO_SKILL_MODEL           (default sonnet — cheap/fast is the point)
#
# Disable without uninstalling: touch ~/.claude/skills/drafts/.disabled

set -euo pipefail

MIN_USER_TURNS="${AUTO_SKILL_MIN_USER_TURNS:-6}"
MIN_TOOL_CALLS="${AUTO_SKILL_MIN_TOOL_CALLS:-8}"
DRAFTS_DIR="${AUTO_SKILL_DRAFTS_DIR:-$HOME/.claude/skills/drafts}"
MODEL="${AUTO_SKILL_MODEL:-sonnet}"

# Read hook input from stdin
input="$(cat)"

# Short-circuit if this is a re-fired Stop hook (avoid loops)
stop_active="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("stop_hook_active", False))' 2>/dev/null || echo False)"
if [ "$stop_active" = "True" ]; then
  exit 0
fi

# Disabled flag
mkdir -p "$DRAFTS_DIR"
if [ -f "$DRAFTS_DIR/.disabled" ]; then
  exit 0
fi

transcript_path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null || echo "")"
session_id="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null || echo "")"

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

# Fast heuristics: count user turns and tool uses in the JSONL
stats="$(python3 - "$transcript_path" <<'PYEOF'
import json, sys
path = sys.argv[1]
user_turns = tool_calls = 0
with open(path, "r", encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            e = json.loads(line)
        except Exception:
            continue
        t = e.get("type")
        if t == "user":
            user_turns += 1
        elif t == "assistant":
            msg = e.get("message") or {}
            content = msg.get("content")
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        tool_calls += 1
print(f"{user_turns} {tool_calls}")
PYEOF
)"

read -r user_turns tool_calls <<< "$stats"

if [ "${user_turns:-0}" -lt "$MIN_USER_TURNS" ] || [ "${tool_calls:-0}" -lt "$MIN_TOOL_CALLS" ]; then
  exit 0
fi

# Skip if we've already drafted for this session
if [ -n "$session_id" ] && ls "$DRAFTS_DIR"/*"${session_id}"* >/dev/null 2>&1; then
  exit 0
fi

# Fork background job: analyze the transcript and draft a skill if warranted
nohup bash -c '
  set -e
  DRAFTS_DIR="'"$DRAFTS_DIR"'"
  MODEL="'"$MODEL"'"
  TRANSCRIPT="'"$transcript_path"'"
  SID="'"$session_id"'"
  TS="$(date +%Y-%m-%d-%H%M%S)"
  OUT="$DRAFTS_DIR/$TS-$SID.md"

  PROMPT="You are analyzing a Claude Code session transcript to decide if the workflow is worth preserving as a reusable skill.

Read the transcript at $TRANSCRIPT. Apply these tests:
1. Did the session establish a repeatable procedure (not just a one-off fix)?
2. Did it involve non-obvious steps, knowledge, or gotchas that would save future-you time?
3. Does it generalize beyond this single task?

If ANY answer is no — output exactly: NOT_WORTH_DRAFTING
and a one-sentence reason.

If all yes — output a SKILL.md draft in this exact format:

---
name: suggested-name
description: One-line description (under 120 chars) explaining when to use this skill.
user-invocable: true
---

# Skill Title

## When to use
- Specific triggers

## Process
### Step 1: ...
### Step 2: ...
### Step N: ...

## Gotchas
- Non-obvious things the session surfaced

## Example invocation
\\\`\\\`\\\`
/suggested-name <args>
\\\`\\\`\\\`

Source session: $SID

Output ONLY the skill markdown or the NOT_WORTH_DRAFTING line. No preamble."

  result="$(claude -p "$PROMPT" --model "$MODEL" 2>/dev/null || true)"

  if [ -z "$result" ]; then
    exit 0
  fi

  if printf "%s" "$result" | head -1 | grep -q "NOT_WORTH_DRAFTING"; then
    # Log the rejection to a lightweight candidates log instead of the drafts dir
    printf "%s\t%s\t%s\n" "$TS" "$SID" "$(printf "%s" "$result" | head -2 | tail -1)" \
      >> "$DRAFTS_DIR/.rejected.log"
    exit 0
  fi

  printf "%s" "$result" > "$OUT"
' >/dev/null 2>&1 &
disown

exit 0
