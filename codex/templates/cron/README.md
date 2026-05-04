# Scheduled Tasks

Scripts here are meant to be run on a schedule to keep Codex review learnings current without manual prompting.

## `learn-eval-monthly.sh`

Runs `$learn-eval` across your repos on the 1st of each month and writes results to `~/.codex/learnings/review-evals/`.

### Install

The Codex installer's `--with-learn-eval-cron` flag copies these assets into `~/.codex/cron/` and installs the scheduler when possible:

- macOS: loads `~/Library/LaunchAgents/com.user.codex.learn-eval.plist`
- Linux: appends a `crontab` entry for `~/.codex/cron/learn-eval-monthly.sh`

### Tuning

Override behavior via env vars in your launchd plist or crontab:

- `LEARN_EVAL_REPOS` — space-separated repo aliases, or empty for `--all`
- `LEARN_EVAL_COUNT` — PRs per repo, default `20`
- `LEARN_EVAL_MODEL` — Codex model for the monthly run, default `gpt-5.4-mini`
- `CODEX_BIN` — alternate Codex CLI binary, useful for testing

Logs land in `~/.codex/learnings/review-evals/logs/YYYY-MM-DD.log`.
