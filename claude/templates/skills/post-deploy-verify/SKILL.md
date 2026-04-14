---
name: post-deploy-verify
description: Verify a deployment by checking ECS health, CloudWatch logs, and comparing error rates before/after. Run after deploying to QA or dev.
user-invocable: true
---

# Post-Deploy Verify

Checks that a deployment is healthy by comparing CloudWatch logs before and after.

## Usage

```
/post-deploy-verify chunkembed qa
/post-deploy-verify chunkreindex dev
```

## Process

### Step 1: Identify service

Map the service name to AWS resources:

| Service | Cluster | Log Group | Account | Profile |
|---------|---------|-----------|---------|---------|
| chunkembed | search-index-chunkembed-svc | /nd/{acct}-nd-{env}-compute-non-prod/us-west-2/ai/ai-search/ai-search-chunkembed-svc | dev:730335459224, qa:767397921534 | nd-{env}-poweruser |
| chunkreindex | ai-search-chunkreindex-svc | /nd/{acct}-nd-{env}-compute-non-prod/us-west-2/ai/ai-search/ai-search-chunkreindex-svc | same | same |

### Step 2: Snapshot current state (before window)

Pull last 30 minutes of logs before the deploy:
```bash
aws logs filter-log-events --log-group-name "{log_group}" \
  --start-time $(python3 -c "import time; print(int((time.time() - 1800)*1000))") \
  --profile {profile} --region us-west-2 --limit 1000
```

Parse and categorize: count by level (INFO/WARNING/ERROR/CRITICAL), extract unique error types.

### Step 3: Wait for deploy

Tell the user to deploy. When they confirm, wait 2 minutes for the new tasks to stabilize.

### Step 4: Snapshot post-deploy

Pull 10 minutes of logs after deploy, same parsing.

### Step 5: Compare and report

```markdown
## Post-Deploy Verification: {service} ({env})

### ECS Health
- Tasks: {running}/{desired}
- Version: {task_definition_version}
- Status: {HEALTHY|DEGRADED}

### Log Comparison (before → after)
| Level | Before (30min) | After (10min) | Rate Change |
|-------|---------------|---------------|-------------|
| ERROR | N | N | {+/-/same} |
| WARNING | N | N | {+/-/same} |

### New Errors (not seen before deploy)
- {error_type}: {message} (Nx)

### Resolved Errors (seen before, gone after)
- {error_type}: was occurring Nx

### Verdict
{CLEAN — no new errors | REGRESSION — new errors appeared | IMPROVED — errors resolved}
```
