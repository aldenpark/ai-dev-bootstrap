# Current State

## Repo Purpose

This repo is building a repeatable AI coding environment for:

- `Codex` with a `spec-kit`-oriented workflow
- `Claude` with a `spec-kit`-oriented workflow (GitHub Spec Kit)
- shared MCP and workflow add-ons that improve both

## Implemented

- Codex installer and workflow docs
- Codex installer now configures MCP servers globally in `~/.codex/config.toml` by default
- Codex default memory path moved to `~/.ai/codex/memory.json` instead of a repo-local `.ai/`
- Codex installer can optionally write a workspace backup config with `--write-vscode-workspace-config`
- Codex GitHub PAT wiring now auto-detects common env var names and existing config before prompting
- Codex installer attempts to install GitHub Spec Kit (`specify`) via `uv` when available and prints guidance when `uv` is missing
- Codex smoke test added at `codex/scripts/test-codex-installer.sh`
- Codex modular global instructions rendered into `~/.codex/AGENTS.md` from rule fragments in `codex/templates/rules/`
- Codex skills now cover frontend, python, csharp, review, mine-learnings, pr-creator, post-deploy-verify, terraform-diff, session-handoff, learn-eval, and quality-gate (`codex/templates/skills/`)
- Codex review now ships the 19 specialized reviewer prompts plus adversarial dual-pass instructions in `codex/templates/skills/review/`
- Codex custom agents now install to `~/.codex/agents/` from `codex/templates/agents/`
- Codex Stop hook now supports an async Codex second-pass draft generator in `codex/templates/hooks/auto-skill-draft.py` (installer: `--with-hooks`)
- Codex monthly learn-eval scheduler assets now live in `codex/templates/cron/` (installer: `--with-learn-eval-cron`)
- Codex optionally adds hosted MemPalace Cloud to `~/.codex/config.toml` with `--with-mempalace` and installs a managed memory protocol block into `~/.codex/AGENTS.md`
- Codex multi-model rollout plan documented at `plans/codex-multi-model-setup.md`
- local `Qwen3.6-35B-A3B` now runs on demand through CUDA-built `llama.cpp`/`llama-server` with `UD-IQ4_NL` GGUF at `~/models/qwen3.6-35b-a3b/`
- Codex can offload bounded code drafting to local Qwen through `qwen36-code`; the helper starts `qwen36-server` on demand and stops it by default
- live Codex global instructions now default bounded code drafting to `qwen36-code` to reduce cloud token usage
- repo now includes `codex/scripts/install-qwen36-local.sh` and `--with-qwen36-local` installer support for replicating the Qwen setup on other machines
- direct `Codex` custom-provider wiring to `llama-server` was tested and not kept because Codex sends non-function tools that `llama-server` rejects
- live user install verified for global Codex rules, skills, agents, hooks, monthly learn-eval cron, and optional MemPalace Cloud wiring
- live Codex exec verification completed for `$session-handoff`, and the real hook path produced a draft skill under `~/.codex/learnings/skill-drafts/`
- repo-local Codex plugin bundle scaffold added at `plugins/ai-dev-bootstrap-codex/` with marketplace example at `.agents/plugins/marketplace.json`
- repo-local cross-repo project-management Codex plugin scaffold added at `plugins/ai-dev-bootstrap-projects/` with a file-backed project hub workflow and external PM/wiki extension guidance
- Claude installer and workflow docs
- Claude `--global` install: MCP servers to `~/.claude.json`, global rules to `~/.claude/CLAUDE.md`, VS Code user settings
- Claude MCP servers: memory, context7, sequential-thinking, playwright, github (PAT-based)
- GitHub Spec Kit (`specify` CLI) installed globally via `uv` for spec-driven development
- Modular global CLAUDE.md template using `@rules/` references instead of inline content
- MemPalace large-palace fix doc at `claude/templates/mempalace-large-palace-fixes.md`
- Self-learning automation (three pieces that close the feedback loops):
  - `claude/templates/hooks/auto-skill-draft.sh` — Stop hook that drafts skills from qualifying sessions (installer: `--with-hooks`)
  - `claude/templates/skills/mine-learnings/export-sharegpt.py` — ShareGPT JSONL export for fine-tuning / model comparison
  - `claude/templates/cron/learn-eval-monthly.sh` + launchd plist — monthly reviewer-quality eval (installer: `--with-learn-eval-cron`)
- Skills: frontend, python, csharp, review (19 reviewers, adversarial dual-pass), mine-learnings, pr-creator, post-deploy-verify, terraform-diff, session-handoff, learn-eval, quality-gate (`claude/templates/skills/`)
- Custom agents: ado-manager, deploy-watcher, sagemaker-runner (`claude/templates/agents/`)
- Modular rules: communication, code-style, testing, git, diagrams (`claude/templates/rules/`)
- Installer copies rules to `~/.claude/rules/` and skills to `~/.claude/skills/` on `--global` install
- Optional plugin support: `--with-mempalace`, `--with-caveman` installer flags
- Optional MCP server support: `--with-atlassian` (OAuth), `--with-ado` (PAT-based) installer flags
- GitHub PAT auto-detection (env var > existing config > interactive prompt > skip)
- synced top-level setup guide in `Local AI Coding Environment Setup.md`
- Context7 added to the Codex and Claude installer/config path
- shared documentation for Context7, Repomix, Promptfoo, and Aider-inspired patterns
- repo-local agent instructions in `AGENTS.md` and `CLAUDE.md`, including Context7 guidance and file-based memory usage
- starter eval scaffold in `evals/`
- file-based repo memory in `CURRENT_STATE.md` and `DECISIONS.md`

## Current Recommendations

- use `Context7` first
- use `Promptfoo` second
- use `Repomix` on demand
- add repo maps and automatic verification after the shared workflow is stable

## Next Likely Work

- expand `evals/` with real project-specific tasks
- validate `specify` workflow end-to-end on a real feature
- add more project-specific eval tasks for the Codex review and learn-eval loops
- expand the Codex-controlled multi-model path from local `Qwen3.6` code drafts into local first-pass review and `Gemini 3` second-pass review
- decide whether to wire the repo-local Codex plugin bundle into the main installer or keep it as an explicit local opt-in
- decide whether to port the remaining Claude-only operational agents and optional plugin/MCP extras later
