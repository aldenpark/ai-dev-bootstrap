---
name: terraform-diff
description: Shows a side-by-side diff of terraform tfvars across all environments for a service. Use before applying config changes.
user-invocable: true
---

# Terraform Diff

Shows what config values differ across environments for a service.

## Usage

```
/terraform-diff                    # Diff all tfvars in current repo
/terraform-diff chunkembed         # Diff chunkembed service tfvars
/terraform-diff chunkreindex       # Diff chunkreindex service tfvars
```

## Process

### Step 1: Find tfvars files

Locate the terraform directory. If a service name is given, find the repo:
- `chunkembed` → `~/www/SymanticSearch/search-index-chunkembed-svc/terraform/`
- `chunkreindex` → `~/www/SymanticSearch/ai-search-chunkreindex-svc/terraform/`
- No arg → use `./terraform/` in current directory

List all `*.tfvars` files.

### Step 2: Parse all tfvars

For each `.tfvars` file, extract all key=value pairs (ignoring comments). Build a table:

```
{variable_name: {env1: value, env2: value, ...}}
```

### Step 3: Also parse defaults from variables.tf

Read `variables.tf` and extract `default = ...` values. These fill in gaps where a tfvars doesn't override.

### Step 4: Generate side-by-side report

```markdown
## Terraform Config: {service}

### Performance
| Parameter | Default | us-dev | us-qa | us-prod | ca-prod | uk-prod |
|-----------|---------|--------|-------|---------|---------|---------|
| max_messages | 5 | 5 | 5 | — | — | — |
| content_worker_max_concurrent_tasks | 5 | 20 | 12 | — | — | — |
| embedding_texts_per_batch | 10 | 45 | 45 | — | — | — |

### Rate Limiting
| Parameter | Default | us-dev | us-qa | us-prod | ... |
...

### Differences from Default
- us-dev overrides 5 values
- us-qa overrides 8 values  
- us-prod overrides 1 value (ratelimit_requests_per_minute)

### Uncommitted Changes
{git diff output for tfvars files, if any}
```

Mark values that differ from defaults in bold. Mark values that differ across environments with a warning.

### Step 5: Flag issues

- Missing overrides: if dev has a value but qa doesn't (or vice versa)
- Inconsistencies: if the same param has very different values across prod regions without explanation
- Defaults in prod: anything using the default in prod that dev/qa override
