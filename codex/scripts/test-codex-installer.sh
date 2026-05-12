#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source_installer="$repo_root/codex/scripts/install-codex-mcp-setup.sh"
source_templates_dir="$repo_root/codex/templates"

workspace_root="$(mktemp -d "$repo_root/.tmp-codex-workspace.XXXXXX")"
home_root="$(mktemp -d "$repo_root/.tmp-codex-home.XXXXXX")"
log_root="$(mktemp -d "$repo_root/.tmp-codex-log.XXXXXX")"
bin_root="$(mktemp -d "$repo_root/.tmp-codex-bin.XXXXXX")"

cleanup() {
  rm -rf "$workspace_root" "$home_root" "$log_root" "$bin_root"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_exists() {
  local path="$1"
  local description="$2"

  if [ ! -e "$path" ]; then
    fail "$description missing at $path"
  fi
}

assert_not_exists() {
  local path="$1"
  local description="$2"

  if [ -e "$path" ]; then
    fail "$description should not exist at $path"
  fi
}

assert_file_contains() {
  local path="$1"
  local needle="$2"
  local description="$3"

  if ! grep -Fq "$needle" "$path"; then
    fail "$description missing from $path"
  fi
}

run_installer() {
  local log_file="$1"
  shift

  (
    cd "$workspace_root"
    HOME="$home_root" \
      PATH="$bin_root:$PATH" \
      GITHUB_PAT="test-token" \
      "$workspace_root/codex/scripts/install-codex-mcp-setup.sh" "$@"
  ) >"$log_file" 2>&1
}

trap cleanup EXIT

mkdir -p "$workspace_root/codex/scripts"
cp "$source_installer" "$workspace_root/codex/scripts/install-codex-mcp-setup.sh"
cp "$repo_root/codex/scripts/install-qwen36-local.sh" "$workspace_root/codex/scripts/install-qwen36-local.sh"
chmod +x "$workspace_root/codex/scripts/install-codex-mcp-setup.sh"
chmod +x "$workspace_root/codex/scripts/install-qwen36-local.sh"
cp -R "$source_templates_dir" "$workspace_root/codex/templates"

cat > "$bin_root/crontab" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

store="${HOME}/.fake-crontab"

case "${1:-}" in
  -l)
    if [ -f "$store" ]; then
      cat "$store"
    else
      exit 1
    fi
    ;;
  -)
    cat > "$store"
    ;;
  *)
    echo "unsupported crontab invocation" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$bin_root/crontab"

cat > "$bin_root/codex-automation-stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
while (($#)); do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$output" ]; then
  exit 1
fi

cat > "$output" <<'SKILL'
---
name: stub-skill
description: Stub skill output for installer smoke tests.
---

# Stub Skill

## When to use
- Smoke testing the Codex installer automation path.
SKILL
EOF
chmod +x "$bin_root/codex-automation-stub"

install_log="$log_root/install-default.log"
run_installer "$install_log"

config_file="$home_root/.codex/config.toml"
list_file="$log_root/mcp-list.txt"
global_agents_file="$home_root/.codex/AGENTS.md"
rules_dir="$home_root/.codex/rules-md"
skills_dir="$home_root/.codex/skills"
agents_dir="$home_root/.codex/agents"

assert_exists "$config_file" "global Codex config"
HOME="$home_root" codex mcp list >"$list_file"

assert_file_contains "$config_file" '[mcp_servers.openaiDeveloperDocs]' "OpenAI docs MCP config"
assert_file_contains "$config_file" '[mcp_servers.context7]' "Context7 MCP config"
assert_file_contains "$config_file" '[mcp_servers.memory]' "Memory MCP config"
assert_file_contains "$config_file" '[mcp_servers.sequential-thinking]' "Sequential Thinking MCP config"
assert_file_contains "$config_file" '[mcp_servers.playwright]' "Playwright MCP config"
assert_file_contains "$config_file" '[mcp_servers.github]' "GitHub MCP config"
assert_file_contains "$config_file" '[features]' "features block"
assert_file_contains "$config_file" 'memories = true' "Codex memories feature flag"
assert_file_contains "$config_file" "$home_root/.ai/codex/memory.json" "global memory path"
assert_file_contains "$config_file" 'bearer_token_env_var = "GITHUB_PAT"' "GitHub env var wiring"
assert_file_contains "$config_file" "[projects.\"$home_root\"]" "trusted home project path"
assert_file_contains "$config_file" "[projects.\"$workspace_root\"]" "trusted repo project path"
assert_file_contains "$config_file" 'trust_level = "trusted"' "trusted project setting"

assert_file_contains "$list_file" 'openaiDeveloperDocs' "OpenAI docs server listing"
assert_file_contains "$list_file" 'context7' "Context7 server listing"
assert_file_contains "$list_file" 'memory' "Memory server listing"
assert_file_contains "$list_file" 'sequential-thinking' "Sequential Thinking server listing"
assert_file_contains "$list_file" 'playwright' "Playwright server listing"
assert_file_contains "$list_file" 'github' "GitHub server listing"

assert_exists "$global_agents_file" "global Codex AGENTS"
assert_exists "$rules_dir/communication.md" "communication rule"
assert_exists "$rules_dir/code-style.md" "code style rule"
assert_exists "$rules_dir/testing.md" "testing rule"
assert_exists "$rules_dir/git.md" "git rule"
assert_exists "$rules_dir/diagrams.md" "diagram rule"
assert_not_exists "$rules_dir/local-qwen-coding.md" "Qwen coding rule during default install"
assert_file_contains "$global_agents_file" 'Global Codex Instructions' "global AGENTS header"
assert_file_contains "$global_agents_file" 'Communication Rules' "rendered rule content"

assert_exists "$skills_dir/csharp/SKILL.md" "csharp skill"
assert_exists "$skills_dir/frontend/SKILL.md" "frontend skill"
assert_exists "$skills_dir/learn-eval/SKILL.md" "learn-eval skill"
assert_exists "$skills_dir/mine-learnings/SKILL.md" "mine-learnings skill"
assert_exists "$skills_dir/mine-learnings/scripts/extract-sessions.py" "mine-learnings extractor"
assert_exists "$skills_dir/mine-learnings/scripts/export-sharegpt.py" "mine-learnings exporter"
assert_exists "$skills_dir/post-deploy-verify/SKILL.md" "post-deploy-verify skill"
assert_exists "$skills_dir/pr-creator/SKILL.md" "pr-creator skill"
assert_exists "$skills_dir/python/SKILL.md" "python skill"
assert_exists "$skills_dir/quality-gate/SKILL.md" "quality-gate skill"
assert_exists "$skills_dir/review/SKILL.md" "review skill"
assert_exists "$skills_dir/review/reviewers/dotnet-reviewer.md" "reviewer prompt set"
assert_exists "$skills_dir/review/reviewers/learnings-check.md" "learnings reviewer prompt"
assert_exists "$skills_dir/session-handoff/SKILL.md" "session-handoff skill"
assert_exists "$skills_dir/terraform-diff/SKILL.md" "terraform-diff skill"

assert_exists "$agents_dir/pr-explorer.toml" "pr explorer agent"
assert_exists "$agents_dir/reviewer.toml" "reviewer agent"
assert_exists "$agents_dir/docs-researcher.toml" "docs researcher agent"
assert_exists "$agents_dir/code-mapper.toml" "code mapper agent"
assert_exists "$agents_dir/browser-debugger.toml" "browser debugger agent"

assert_not_exists "$workspace_root/.vscode/mcp.json" "workspace MCP config during default global install"
assert_not_exists "$home_root/.codex/hooks.json" "hooks config during default install"
assert_not_exists "$home_root/.local/bin/qwen36-code" "Qwen coding worker during default install"

if command -v uv >/dev/null 2>&1 || [ -x "$HOME/.local/bin/uv" ]; then
  if ! PATH="$home_root/.local/bin:$PATH" command -v specify >/dev/null 2>&1; then
    fail "specify should be installed when uv is available"
  fi
else
  assert_file_contains "$install_log" 'Note: uv not found.' "uv guidance"
fi

rerun_log="$log_root/install-rerun.log"
run_installer "$rerun_log"

server_count="$(grep -c '^\[mcp_servers\.[^.]*\]$' "$config_file")"
if [ "$server_count" -ne 6 ]; then
  fail "expected 6 MCP server entries after rerun, found $server_count"
fi

workspace_log="$log_root/install-workspace.log"
run_installer "$workspace_log" --write-vscode-workspace-config --with-mempalace

workspace_mcp="$workspace_root/.vscode/mcp.json"
assert_exists "$workspace_mcp" "workspace MCP config"
assert_file_contains "$workspace_mcp" '"MEMORY_FILE_PATH": "${workspaceFolder}/.ai/memory.json"' "workspace memory path"
assert_file_contains "$workspace_mcp" '"Authorization": "Bearer ${env:GITHUB_PAT}"' "workspace GitHub env reference"
assert_file_contains "$workspace_mcp" '"mempalace-cloud"' "workspace MemPalace config"
assert_file_contains "$workspace_mcp" '"url": "https://api.mempalace.cloud/mcp"' "workspace MemPalace URL"

mempalace_list_file="$log_root/mcp-list-mempalace.txt"
HOME="$home_root" codex mcp list >"$mempalace_list_file"
assert_file_contains "$config_file" '[mcp_servers.mempalace-cloud]' "MemPalace MCP config"
assert_file_contains "$config_file" 'url = "https://api.mempalace.cloud/mcp"' "MemPalace URL"
assert_file_contains "$mempalace_list_file" 'mempalace-cloud' "MemPalace server listing"
assert_file_contains "$global_agents_file" 'MemPalace Cloud Memory Protocol' "MemPalace protocol block"
assert_file_contains "$global_agents_file" 'mempalace_list_wings' "MemPalace discovery guidance"

hooks_log="$log_root/install-hooks.log"
run_installer "$hooks_log" --with-hooks

hooks_file="$home_root/.codex/hooks.json"
hook_script="$home_root/.codex/hooks/auto-skill-draft.py"
assert_exists "$hooks_file" "hooks config after opt-in install"
assert_exists "$hook_script" "installed auto-skill-draft hook"
assert_file_contains "$hooks_file" '"Stop"' "Stop hook entry"
assert_file_contains "$hooks_file" 'auto-skill-draft.py' "auto-skill-draft hook command"
assert_file_contains "$config_file" 'codex_hooks = true' "Codex hooks feature flag"

hook_transcript="$log_root/hook-transcript.jsonl"
cat > "$hook_transcript" <<'EOF'
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"figure out the deployment issue"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"wire the new codex skill"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"compare the configs"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"run the review pass"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"capture the lessons"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"output_text","text":"turn it into a reusable skill"}]}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}
EOF

HOME="$home_root" \
  AUTO_SKILL_DRAFT_SYNC=1 \
  AUTO_SKILL_DRAFT_CODEX_BIN="$bin_root/codex-automation-stub" \
  python3 "$hook_script" <<EOF >/dev/null
{"transcript_path":"$hook_transcript","session_id":"session-smoke","cwd":"$workspace_root"}
EOF

draft_file="$(find "$home_root/.codex/learnings/skill-drafts" -type f -name '*session-smoke.md' | head -n 1)"
assert_exists "$draft_file" "hook-generated draft skill"
assert_file_contains "$draft_file" 'stub-skill' "hook draft contents"

cron_log="$log_root/install-cron.log"
run_installer "$cron_log" --with-learn-eval-cron

cron_script="$home_root/.codex/cron/learn-eval-monthly.sh"
fake_crontab="$home_root/.fake-crontab"
assert_exists "$cron_script" "learn-eval cron script"
assert_exists "$home_root/.codex/cron/learn-eval.crontab.example" "learn-eval cron example"
assert_file_contains "$fake_crontab" 'learn-eval-monthly.sh' "learn-eval crontab entry"

HOME="$home_root" CODEX_BIN="$bin_root/codex-automation-stub" "$cron_script"
cron_output="$home_root/.codex/learnings/review-evals/$(date +%Y-%m-%d).md"
assert_exists "$cron_output" "learn-eval cron output"
assert_file_contains "$cron_output" 'stub-skill' "learn-eval cron stub output"

qwen_log="$log_root/install-qwen36.log"
run_installer "$qwen_log" --with-qwen36-local --qwen36-skip-build --qwen36-skip-model

assert_exists "$home_root/.local/bin/qwen36-server" "Qwen server wrapper"
assert_exists "$home_root/.local/bin/qwen36-code" "Qwen coding worker"
assert_exists "$skills_dir/qwen36-coder/SKILL.md" "Qwen coder skill"
assert_exists "$rules_dir/local-qwen-coding.md" "Qwen coding rule"
assert_file_contains "$global_agents_file" 'Local Qwen Coding Policy' "rendered Qwen coding policy"
assert_file_contains "$qwen_log" 'Qwen3.6 local coding setup complete.' "Qwen installer completion"

printf 'PASS: Codex installer smoke test succeeded.\n'
