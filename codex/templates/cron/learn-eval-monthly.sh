#!/usr/bin/env bash
set -euo pipefail

COUNT="${LEARN_EVAL_COUNT:-20}"
MODEL="${LEARN_EVAL_MODEL:-gpt-5.4-mini}"
REPOS="${LEARN_EVAL_REPOS:-}"
CODEX_BIN="${CODEX_BIN:-codex}"

LEARNINGS_DIR="$HOME/.codex/learnings"
EVALS_DIR="$LEARNINGS_DIR/review-evals"
LOG_DIR="$EVALS_DIR/logs"
mkdir -p "$EVALS_DIR" "$LOG_DIR"

ts="$(date +%Y-%m-%d)"
log="$LOG_DIR/$ts.log"
out="$EVALS_DIR/$ts.md"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

if [ -z "$REPOS" ]; then
  prompt='$learn-eval --all --count '"$COUNT"
else
  prompt=""
  for repo in $REPOS; do
    prompt+='$learn-eval '"$repo"' --count '"$COUNT"$'\n'
  done
fi

{
  echo "[$ts] learn-eval run starting"
  echo "[$ts] prompt: $prompt"
  echo "[$ts] model:  $MODEL"
  "$CODEX_BIN" --disable codex_hooks -m "$MODEL" exec \
    --ephemeral \
    --skip-git-repo-check \
    -C "$HOME" \
    -o "$out" \
    "$prompt" 2>&1 || echo "[$ts] codex exited non-zero"
  echo "[$ts] output: $out"
  echo "[$ts] done"
} >> "$log" 2>&1
