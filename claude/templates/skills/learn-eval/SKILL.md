---
name: learn-eval
description: Evaluate reviewer effectiveness by replaying past PRs and scoring how well reviewers caught real bugs. Use to tune reviewer prompts.
user-invocable: true
---

# Learn-Eval (Review Quality Feedback Loop)

Replays merged PRs through the current reviewer system and scores how well reviewers would have caught issues that were later fixed, reverted, or flagged in production. Outputs a scorecard per reviewer and actionable suggestions for prompt tuning.

## Usage

```
/learn-eval REPO                         # Analyze last 20 merged PRs in repo
/learn-eval REPO --count 50              # Analyze last 50
/learn-eval REPO --pr 123,145,167        # Analyze specific PRs
/learn-eval REPO --since 2026-03-01      # PRs merged since date
/learn-eval --all                        # Analyze across all repos in workspace
```

## Process

### Step 1: Gather PR history

For the target repo(s), use `gh` to list merged PRs:

```bash
gh pr list --repo NetDocs-Apps/{repo} --state merged --limit {count} --json number,title,mergedAt,headRefName
```

For each merged PR, collect:
- The merge diff: `gh pr diff {number} --repo NetDocs-Apps/{repo}`
- The PR comments and review comments (may contain post-merge feedback)

### Step 2: Identify PRs with post-merge issues

For each merged PR, search for evidence of problems after merge:

**Signal 1 — Follow-up fixes:** Look for subsequent PRs/commits that reference the same files within 14 days:
```bash
git log --oneline --since="{mergedAt}" --until="{mergedAt + 14d}" -- {changed_files}
```
Check if commit messages contain `fix`, `revert`, `hotfix`, `bug`, or reference the original PR number.

**Signal 2 — Reverts:** Search for revert commits:
```bash
git log --oneline --all --grep="Revert.*{PR title or branch}" --since="{mergedAt}"
```

**Signal 3 — PR review comments:** Parse review comments for post-merge issues flagged by humans:
```bash
gh pr view {number} --repo NetDocs-Apps/{repo} --json reviews,comments
```

Classify each PR:
- **Clean**: No post-merge issues detected
- **Fixed**: Had a follow-up fix within 14 days
- **Reverted**: Was reverted
- **Flagged**: Had concerning review comments that were merged anyway

### Step 3: Replay reviews on problematic PRs

For each PR classified as Fixed, Reverted, or Flagged:

1. Get the original diff
2. Run the `/review` skill's file classification logic (Step 2 of /review) to determine which reviewers would trigger
3. For each triggered reviewer, read its prompt from `~/.claude/skills/review/reviewers/{name}.md`
4. Launch a lightweight agent to review the diff using that reviewer's prompt
5. Collect findings

**Do NOT run this on Clean PRs** — that would waste tokens. Clean PRs are only used for false-positive scoring (Step 4).

### Step 4: Score reviewers

For each reviewer, calculate:

#### Hit Rate (on problematic PRs)
```
hits = PRs where reviewer flagged the area that was later fixed/reverted
misses = PRs where reviewer was triggered but didn't flag the problem area
hit_rate = hits / (hits + misses)
```

A "hit" means the reviewer produced a finding on the same file (and ideally same function/region) that was later changed in the follow-up fix.

#### False Positive Rate (on clean PRs)
Sample 5 clean PRs and run the same reviewers:
```
false_positives = P1 or P2 findings on PRs that had no post-merge issues
fp_rate = false_positives / total_findings_on_clean_prs
```

#### Noise Score
```
noise = total P3 findings across all reviewed PRs / total PRs reviewed
```
High noise means the reviewer prompt is too sensitive.

### Step 5: Generate scorecard

```markdown
## Review Quality Scorecard — {repo}

**Period:** {date range} | **PRs analyzed:** {N} ({clean}/{fixed}/{reverted}/{flagged})

### Reviewer Effectiveness

| Reviewer | Triggered | Hits | Misses | Hit Rate | FP Rate | Noise | Grade |
|----------|-----------|------|--------|----------|---------|-------|-------|
| dotnet-reviewer | 12 | 3 | 2 | 60% | 15% | 1.2 | B |
| python-reviewer | 8 | 4 | 0 | 100% | 10% | 0.8 | A |
| config-safety | 5 | 1 | 3 | 25% | 40% | 3.1 | D |
| test-coverage | 15 | 2 | 5 | 29% | 20% | 2.5 | C |
| ... | | | | | | | |

**Grading:** A (hit>=80%, fp<=15%) | B (hit>=60%, fp<=25%) | C (hit>=40%, fp<=35%) | D (below C)

### Blind Spots (bugs no reviewer caught)

{List PRs where ALL triggered reviewers missed the issue that was later fixed}

- **PR #{N}: {title}** — Fixed by #{M}. Changed `{file}`. No reviewer flagged `{problem area}`.
  **Suggested new rule for {best_matching_reviewer}:** {specific rule that would have caught this}

### Noisy Reviewers (high false positive / low signal)

{List reviewers with grade D or noise > 3.0}

- **{reviewer}** — {noise} P3s per PR, {fp_rate}% false positives
  **Suggestion:** {specific prompt tightening recommendation}

### Prompt Improvement Suggestions

For each reviewer with grade C or below, provide:
1. The specific pattern it missed (from the blind spots analysis)
2. A concrete addition to the reviewer prompt that would catch it
3. Any rules that should be removed (causing false positives)

Format as a diff against the current reviewer prompt:
\`\`\`diff
--- a/reviewers/{name}.md
+++ b/reviewers/{name}.md
@@ ...
+ New rule: Check for {pattern} when {condition}
- Remove: Overly broad rule about {thing}
\`\`\`
```

### Step 6: Save results

Write the scorecard to `~/.claude/learnings/review-evals/{repo}-{date}.md` for future reference.

If the learnings database (`~/.claude/learnings/learnings.jsonl`) exists, append any blind spots as new learnings entries so the `learnings-check` reviewer can catch them in future reviews.

## Notes

- This is expensive (runs many reviewer agents). Use judiciously — monthly or after a production incident.
- The quality of scoring depends on git history quality. Squash-merged repos with poor commit messages will have lower signal.
- PRs with follow-up fixes within 24 hours are the strongest signal. 14-day fixes may be coincidental.
- This skill does NOT modify reviewer prompts automatically. It suggests changes — you apply them manually after reviewing the suggestions.
