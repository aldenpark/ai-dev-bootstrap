# Scheduled Tasks

Scripts here are meant to be run on a schedule (cron on Linux, launchd on macOS) to close self-learning loops without manual triggering.

## `learn-eval-monthly.sh`

Runs `/learn-eval` across your repos on the 1st of each month. Scores reviewer hit rate / false positives and writes a scorecard to `~/.claude/learnings/review-evals/`.

### Install (macOS — launchd)

The installer's `--with-learn-eval-cron` flag handles this for you. Manual install:

```bash
# 1. Copy the script
mkdir -p ~/.claude/cron
cp claude/templates/cron/learn-eval-monthly.sh ~/.claude/cron/
chmod +x ~/.claude/cron/learn-eval-monthly.sh

# 2. Template the plist with your username
sed "s|USERNAME|$(whoami)|g" claude/templates/cron/com.user.claude.learn-eval.plist \
  > ~/Library/LaunchAgents/com.user.claude.learn-eval.plist

# 3. Load
launchctl load ~/Library/LaunchAgents/com.user.claude.learn-eval.plist

# Test-run without waiting a month:
launchctl start com.user.claude.learn-eval

# Unload if you want to remove it:
launchctl unload ~/Library/LaunchAgents/com.user.claude.learn-eval.plist
```

### Install (Linux — cron)

```bash
mkdir -p ~/.claude/cron
cp claude/templates/cron/learn-eval-monthly.sh ~/.claude/cron/
chmod +x ~/.claude/cron/learn-eval-monthly.sh

# Edit your crontab
crontab -e

# Add this line — runs 1st of month at 09:00 local time
0 9 1 * * /home/$(whoami)/.claude/cron/learn-eval-monthly.sh
```

### Tuning

Override behavior via env vars in the launchd plist (`EnvironmentVariables` dict) or in your crontab:

- `LEARN_EVAL_REPOS` — space-separated repo aliases (default: `--all`)
- `LEARN_EVAL_COUNT` — PRs per repo (default: 20)
- `LEARN_EVAL_MODEL` — model used for the eval pass (default: sonnet)

Logs land in `~/.claude/learnings/review-evals/logs/YYYY-MM-DD.log`.
