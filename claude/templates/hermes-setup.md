# Hermes Agent Setup (for Codex to execute)

**Audience:** A Codex agent running on a machine with enough resources (16GB+ RAM, ~20GB disk, optional GPU for local models) to install and run Hermes Agent.

**Context:** The user is an existing Claude Code power user with a curated stack at `~/.claude/` (rules, skills, custom agents, MCP servers, hooks, MemPalace). They want Hermes Agent as an outer-loop orchestrator that can route across Claude, GPT, and local models while accumulating skills and memory across all of them. The existing Claude Code stack should keep working.

**Your job as Codex:** Walk through this setup step-by-step. Verify each step before moving on. Ask the user for decisions at the marked choice points.

---

## Step 0: Verify prerequisites

Before anything else, confirm these exist on the target machine:

```bash
python3 --version          # need 3.11+
pip --version              # or uv
git --version
claude --version           # Claude Code CLI (used as a subagent target)
```

Optional but recommended for local models:

```bash
# Either ollama OR lm-studio, not both
ollama --version           # https://ollama.com
# OR
lms --version              # LM Studio CLI
```

If `claude` is missing, Hermes can still run with Claude via the Anthropic API directly, but you lose the ability to delegate to Claude Code's harness (your existing skills, MCP stack). Warn the user and offer to install Claude Code first: https://docs.anthropic.com/en/docs/claude-code.

Also verify API keys are available:

```bash
echo "ANTHROPIC_API_KEY set: ${ANTHROPIC_API_KEY:+yes}"
echo "OPENAI_API_KEY set: ${OPENAI_API_KEY:+yes}"
```

If either is missing, ask the user to set them before continuing (persist to `~/.zprofile` or equivalent so future sessions pick them up).

---

## Step 1: Fetch current Hermes docs

Hermes is moving fast. Do NOT trust the commands in this file as final — verify against the current docs first:

1. If the `context7` MCP server is available, use it to resolve `NousResearch/hermes-agent` and fetch the current README and install guide.
2. Otherwise: `gh repo view nousresearch/hermes-agent` or `curl -s https://raw.githubusercontent.com/NousResearch/hermes-agent/main/README.md`.
3. Check for differences between the install steps below and the current README. If the README says something different, **follow the README**, not this file.

Also check the project's docs site: https://hermes-agent.nousresearch.com/docs/

---

## Step 2: Install Hermes Agent

The likely-correct install (verify against Step 1):

```bash
# Preferred: uv tool install (isolated venv)
uv tool install hermes-agent --from git+https://github.com/NousResearch/hermes-agent.git

# Fallback: pipx
pipx install git+https://github.com/NousResearch/hermes-agent.git

# Fallback: pip in a dedicated venv
python3 -m venv ~/.hermes/venv
~/.hermes/venv/bin/pip install git+https://github.com/NousResearch/hermes-agent.git
# Then symlink: ln -s ~/.hermes/venv/bin/hermes ~/.local/bin/hermes
```

Verify:

```bash
hermes --version
hermes --help
```

Initialize the palace/state directory:

```bash
hermes init
```

This should create `~/.hermes/` (or similar) with a default config, skills directory, and state DB.

---

## Step 3: Configure model endpoints

The whole point of Hermes for this user is **skill continuity across Claude + GPT + local models**. Configure all three.

Edit the Hermes config (location depends on version — likely `~/.hermes/config.yaml` or `~/.hermes/config.toml`). Ask Hermes where its config lives if unsure:

```bash
hermes config path
```

Add three provider entries. Example (YAML — translate to TOML if needed):

```yaml
providers:
  anthropic:
    type: anthropic
    api_key_env: ANTHROPIC_API_KEY
    default_model: claude-opus-4-7
    models:
      - claude-opus-4-7
      - claude-sonnet-4-6
      - claude-haiku-4-5

  openai:
    type: openai
    api_key_env: OPENAI_API_KEY
    default_model: gpt-5
    models:
      - gpt-5
      - gpt-4o

  local:
    type: openai_compatible   # Ollama and LM Studio both expose an OpenAI-compatible API
    base_url: http://localhost:11434/v1   # Ollama default; use http://localhost:1234/v1 for LM Studio
    api_key: ollama                       # Ollama ignores the key; LM Studio may accept any string
    default_model: qwen2.5-coder:14b      # Adjust to whatever the user has pulled
```

Routing policy — let Hermes pick per task. A reasonable default:

```yaml
routing:
  default: anthropic
  rules:
    - match: "task_type == 'trivial' or tokens < 1000"
      provider: local
    - match: "task_type == 'long_context'"
      provider: anthropic
    - match: "task_type == 'code_refactor' or task_type == 'planning'"
      provider: anthropic
    - match: "task_type == 'reasoning_heavy'"
      provider: openai
```

**Choice point for the user:** Ask whether they want aggressive local-model routing (cost-optimized, slower) or Claude-by-default (quality-optimized). Adjust the rules accordingly.

---

## Step 4: Wire Claude Code as a delegable subagent

Hermes can call `claude` as a subagent, which keeps the user's existing skills (`/review`, `/pr-creator`, MemPalace, etc.) accessible inside Hermes-orchestrated workflows.

In the Hermes config, add:

```yaml
subagents:
  claude_code:
    command: claude
    args: ["-p", "{prompt}", "--model", "{model}"]
    supports_mcp: true
    description: "Delegate to Claude Code's harness — use when the task benefits from the user's curated skills, MCP tools, or long-context operation."
```

Then add a routing rule that prefers `claude_code` for tasks that touch the user's existing skill domains:

```yaml
routing:
  rules:
    - match: "uses_skill in ['review', 'pr-creator', 'mine-learnings', 'terraform-diff', 'post-deploy-verify']"
      subagent: claude_code
    # ... the model-direct rules above
```

Verify Claude Code is reachable from Hermes:

```bash
hermes test-subagent claude_code --prompt "print the current git branch"
```

(If `test-subagent` isn't a real command, consult the Hermes docs from Step 1 for the equivalent.)

---

## Step 5: Mine the user's Claude Code history into Hermes

The user has valuable conversation history at `~/.claude/projects/*/*.jsonl`. Seed Hermes with it so it doesn't start from zero.

Option A — if Hermes has a native import command:

```bash
hermes import --source claude-code --path ~/.claude/projects/
```

Option B — use the user's existing ShareGPT export script and feed that:

```bash
python3 ~/.claude/skills/mine-learnings/export-sharegpt.py \
  --out /tmp/sessions.jsonl \
  --min-messages 6

hermes import --format sharegpt --path /tmp/sessions.jsonl
```

Option C — ingest MemPalace drawers if the user has a populated palace:

```bash
# If Hermes supports MemPalace as a memory backend, configure it:
# memory:
#   backend: mempalace
#   palace_path: ~/.mempalace
# Otherwise, export drawers and import them via Hermes's native memory API.
```

**Choice point:** Ask the user which history they want Hermes to learn from — all of `~/.claude/projects/`, only a specific project (e.g. `SymanticSearch`), or only mined learnings (`~/.claude/learnings/learnings.jsonl`). Don't dump all of it by default — many sessions are short experiments that would add noise.

---

## Step 6: Carry skills forward

Hermes has its own skills format (check Step 1 docs for the current spec). The user has these skills they'll likely want available in Hermes too:

- `review` (19 reviewers, adversarial dual-pass)
- `pr-creator`
- `mine-learnings`
- `quality-gate`
- `learn-eval`
- `session-handoff`
- `post-deploy-verify`
- `terraform-diff`
- `frontend`, `python`, `csharp` (language conventions)

Two strategies, let the user choose:

1. **Stay Claude-only for these** — register them as `claude_code` subagent-only skills. Hermes routes any task matching these skill names to Claude Code.
2. **Port to Hermes-native** — translate each SKILL.md into Hermes's skill format. More work, but the skills work across all models (GPT and local can run them too).

For option 2, start with the language skills (`frontend`, `python`, `csharp`) — they're generic prompts and port cleanly. The review/pr-creator skills are tightly coupled to Claude Code's Agent tool and should stay as option 1 for now.

---

## Step 7: Enable auto-skill-creation

This is Hermes's headline feature and the reason the user is doing this. Verify it's on:

```bash
hermes config get skills.auto_create
```

If not enabled:

```bash
hermes config set skills.auto_create true
hermes config set skills.auto_create_threshold 5    # minimum tool calls to trigger
hermes config set skills.draft_dir ~/.hermes/skills/drafts
```

This replaces the user's `auto-skill-draft.sh` Stop hook — don't install that hook on this machine.

---

## Step 8: Verify end-to-end

Run a smoke test that exercises the full stack:

```bash
hermes chat "Review the uncommitted changes in the current directory. Use the user's existing /review skill if appropriate."
```

Expected behavior:
- Hermes routes this to `claude_code` subagent (matches the `uses_skill in ['review']` rule)
- Claude Code runs `/review`, producing the normal adversarial dual-pass output
- Hermes captures the interaction into its learning store

Second test — verify multi-model routing:

```bash
hermes chat "Rename the variable foo to bar in this file" --task-type trivial
```

Expected: Hermes routes to local model (if configured) or GPT, not Claude.

Third test — verify auto-skill-creation fires:

```bash
# Do a longer multi-step task, then check:
ls ~/.hermes/skills/drafts/
```

You should see a draft skill after a session with 5+ tool calls.

---

## Step 9: Daily workflow

Tell the user the new entry points:

- `hermes chat` — interactive session with routing
- `hermes chat --provider anthropic` — force Claude
- `hermes chat --provider local` — force local model
- `hermes skills list` — see accumulated skills
- `hermes skills promote <draft>` — move a draft to active
- `hermes memory search "<query>"` — query accumulated memory

For their existing Claude Code workflow, nothing changes — `claude` still works as before. Hermes is additive.

---

## Troubleshooting

**Hermes can't reach Claude Code subagent:** verify `claude` is on PATH when Hermes runs (may need to set `PATH` in Hermes's environment config, especially under systemd/launchd).

**Local model routing fails:** check the local endpoint is up (`curl http://localhost:11434/v1/models`). Ollama models must be pulled first (`ollama pull qwen2.5-coder:14b`).

**Skill drafts never appear:** lower the threshold temporarily (`hermes config set skills.auto_create_threshold 2`) and run a test session. If still nothing, check Hermes logs at `~/.hermes/logs/`.

**Memory search returns nothing after import:** verify the import actually populated the store (`hermes memory stats`). If empty, the format may have been wrong — consult Step 1 docs.

**Conflict with Claude Code's auto-memory:** not a conflict — Claude Code's memory is at `~/.claude/projects/*/memory/` and stays isolated. Hermes maintains its own store.

---

## After install: report back to the user

Summarize:

1. Which provider is default (Claude / OpenAI / local)
2. Which subagents are wired (`claude_code` at minimum)
3. How many sessions were imported from Claude Code history
4. Which skills were ported vs left as Claude-only
5. Whether auto-skill-creation is firing (verify with a test session before declaring success)

Also write a handoff note to `~/.hermes/INSTALL_NOTES.md` so the user can reference what was chosen.

---

## Hard constraints — do not deviate

- **Do not install Hermes on a machine with less than 8GB free RAM.** The user has said their current laptop is underpowered; confirm you're on the right machine before starting.
- **Do not delete or modify `~/.claude/`.** The existing Claude Code stack must keep working. Hermes is additive only.
- **Do not commit API keys.** If the user asks you to persist keys, use `~/.zprofile` or a secrets manager, never a file in a git repo.
- **Do not enable Atropos RL training without explicit approval** — it's expensive and the user has not asked for it.
- **If any step fails, stop and report** instead of continuing past a broken install.
