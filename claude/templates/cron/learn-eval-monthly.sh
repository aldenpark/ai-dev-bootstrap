#!/usr/bin/env bash
# Monthly reviewer-quality evaluation. Replays recent PRs through the
# /review reviewers and scores their effectiveness.
#
# Designed to be run by launchd (macOS) or cron (Linux). Headless — writes
# scorecards under ~/.claude/learnings/review-evals/ and logs to
# ~/.claude/learnings/review-evals/logs/.
#
# Env overrides:
#   LEARN_EVAL_REPOS     Space-separated repo aliases to evaluate (default: all
#                        active repos under ~/www/ with git remotes)
#   LEARN_EVAL_COUNT     Number of PRs per repo to analyze (default: 20)
#   LEARN_EVAL_MODEL     Model for the eval run (default: sonnet)

set -euo pipefail

COUNT="${LEARN_EVAL_COUNT:-20}"
MODEL="${LEARN_EVAL_MODEL:-sonnet}"
REPOS="${LEARN_EVAL_REPOS:-}"

LEARNINGS_DIR="$HOME/.claude/learnings"
EVALS_DIR="$LEARNINGS_DIR/review-evals"
LOG_DIR="$EVALS_DIR/logs"
mkdir -p "$EVALS_DIR" "$LOG_DIR"

ts="$(date +%Y-%m-%d)"
log="$LOG_DIR/$ts.log"

# Ensure PATH picks up user-installed tools (launchd minimal env)
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

if ! command -v claude >/dev/null 2>&1; then
  echo "[$ts] ERROR: claude CLI not found on PATH" >> "$log"
  exit 1
fi

if [ -z "$REPOS" ]; then
  # Auto-discover: any repo aliases the user has defined in /review trigger
  # If nothing to discover, just run --all
  prompt="/learn-eval --all --count $COUNT"
else
  # Run once per repo alias, in sequence
  prompt=""
  for repo in $REPOS; do
    prompt+="/learn-eval $repo --count $COUNT"$'\n'
  done
fi

{
  echo "[$ts] learn-eval run starting"
  echo "[$ts] prompt: $prompt"
  echo "[$ts] model:  $MODEL"
  claude -p "$prompt" --model "$MODEL" 2>&1 || echo "[$ts] claude exited non-zero"
  echo "[$ts] done"
} >> "$log" 2>&1
