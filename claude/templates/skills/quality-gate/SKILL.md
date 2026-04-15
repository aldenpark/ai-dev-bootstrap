---
name: quality-gate
description: Configurable pass/fail gate for code reviews. Evaluates /review output against thresholds and returns a binary verdict.
user-invocable: true
---

# Quality Gate

Evaluates review findings against configurable thresholds and returns a clear pass/fail verdict. Designed to be called standalone or composed into other skills like `/pr-creator`.

## Usage

```
/quality-gate                     # Run /review then apply default gate
/quality-gate --strict            # Zero tolerance: any P1 or P2 = fail
/quality-gate --lenient           # Only P1s fail
/quality-gate --from-review       # Apply gate to the last /review output in this conversation (don't re-run review)
```

## Thresholds

| Preset | P1 | P2 | P3 | Confidence (adversarial) |
|--------|----|----|----|-----------------------|
| **default** | 0 allowed | <=3 allowed | unlimited | Medium+ |
| **strict** | 0 allowed | 0 allowed | <=5 allowed | High only |
| **lenient** | 0 allowed | unlimited | unlimited | any |

## Process

### Step 1: Get review findings

- If `--from-review` is passed, look for the most recent `/review` output in this conversation. If none exists, tell the user and stop.
- Otherwise, run `/review` on uncommitted changes and capture the findings.

### Step 2: Count findings by severity

Parse the review output and count:
- **P1 count**: number of P1 findings
- **P2 count**: number of P2 findings
- **P3 count**: number of P3 findings
- **Confidence**: if from `/review --adversarial`, extract the confidence level

### Step 3: Evaluate against thresholds

Apply the selected preset (default if none specified):

```
PASS if:
  P1_count <= threshold.p1 AND
  P2_count <= threshold.p2 AND
  P3_count <= threshold.p3 AND
  (confidence >= threshold.confidence OR review used --quick)

FAIL otherwise.
```

### Step 4: Output verdict

**On PASS:**
```markdown
## Quality Gate: PASS

Review: {N} findings (P1: {a}, P2: {b}, P3: {c})
Preset: {default|strict|lenient}
Verdict: **PASS** — clear to proceed

{If P2s or P3s exist, list them as acknowledgments:}
### Acknowledged (non-blocking)
- P2: {title} — {file}:{line}
- P3: {title} — {file}:{line}
```

**On FAIL:**
```markdown
## Quality Gate: FAIL

Review: {N} findings (P1: {a}, P2: {b}, P3: {c})
Preset: {default|strict|lenient}
Verdict: **FAIL** — {reason}

### Blocking Findings
- **P1: {title}** `{file}:{line}`
  Problem: ...
  Fix: ...

- **P2: {title}** `{file}:{line}` (over threshold)
  Problem: ...
  Fix: ...

### To pass this gate
1. Fix all P1 findings
2. {Reduce P2 count from {b} to <={threshold} OR switch to --lenient}
```

## Composition with other skills

**`/pr-creator` integration:** `/pr-creator` already checks for P1s before creating a PR. To use `/quality-gate` instead, `/pr-creator` can call `/quality-gate --from-review` after running `/review` and respect the verdict.

**Adversarial confidence integration:** `/review` runs adversarial dual-pass by default, so the confidence score is always available unless `--quick` was used. A `Low` confidence result fails the `default` and `strict` presets even if finding counts are within threshold — it means the reviewers disagreed too much to trust the counts.

## Exit codes (for scripting)

When called from another skill or agent:
- Return `{"pass": true, "findings": {...}}` on pass
- Return `{"pass": false, "findings": {...}, "blocking": [...]}` on fail
