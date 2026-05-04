#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

memory_dir=""
github_pat_env_var=""
install_vscode_extension=0
skip_github=0
prompt_github_pat=0
write_vscode_workspace_config=0
skip_rules=0
skip_skills=0
skip_agents=0
skip_codex_memories=0
with_hooks=0
with_learn_eval_cron=0
with_mempalace=0
with_qwen36_local=0
qwen36_skip_build=0
qwen36_skip_model=0

usage() {
  cat <<'EOF'
Usage: ./codex/scripts/install-codex-mcp-setup.sh [options]

This installer configures Codex MCP servers globally in ~/.codex/config.toml by default.

Options:
  --memory-dir PATH                  Override the global Memory MCP directory.
  --github-pat-env-var NAME          Env var name used by the GitHub MCP.
  --prompt-github-pat                Prompt for the GitHub PAT and save it to the detected shell startup file.
  --write-vscode-workspace-config    Also write a workspace-level .vscode/mcp.json starter file.
  --install-vscode-extension         Install the VS Code Codex extension.
  --skip-rules                       Skip installing global Codex rule fragments and global AGENTS.md.
  --skip-skills                      Skip installing Codex-native skills into Codex home.
  --skip-agents                      Skip installing Codex-native custom agents into Codex home.
  --skip-codex-memories              Do not enable Codex native memories in config.toml.
  --with-hooks                       Install the experimental Codex Stop hook for reusable-session drafting.
  --with-learn-eval-cron             Install the monthly Codex learn-eval scheduler.
  --with-mempalace                   Add the hosted MemPalace Cloud MCP and install its memory protocol.
  --with-qwen36-local                Install local Qwen3.6 coding-worker assets, build llama.cpp, and download the GGUF model.
  --qwen36-skip-build                With --with-qwen36-local, skip building llama.cpp.
  --qwen36-skip-model                With --with-qwen36-local, skip downloading the GGUF model.
  --skip-github                      Skip GitHub MCP configuration.
  -h, --help                         Show this help message.
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
}

configure_mcp_server() {
  local server_name="$1"
  shift

  codex mcp remove "$server_name" >/dev/null 2>&1 || true
  codex mcp add "$server_name" "$@"
}

escape_for_single_quotes() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g"
}

detect_shell_startup_file() {
  local shell_name

  shell_name="$(basename "${SHELL:-}")"

  case "$shell_name" in
    zsh)
      printf '%s\n' "$HOME/.zprofile"
      ;;
    bash)
      if [ -f "$HOME/.bash_profile" ]; then
        printf '%s\n' "$HOME/.bash_profile"
      else
        printf '%s\n' "$HOME/.profile"
      fi
      ;;
    *)
      printf '%s\n' "$HOME/.profile"
      ;;
  esac
}

persist_env_var_to_startup_file() {
  local env_name="$1"
  local env_value="$2"
  local startup_file="$3"
  local marker_begin="# >>> codex-github-pat >>>"
  local marker_end="# <<< codex-github-pat <<<"
  local escaped_value
  local temp_file

  escaped_value="$(escape_for_single_quotes "$env_value")"
  touch "$startup_file"
  temp_file="$(mktemp)"

  awk -v begin="$marker_begin" -v end="$marker_end" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    skip != 1 { print }
  ' "$startup_file" > "$temp_file"

  {
    cat "$temp_file"
    printf '\n%s\n' "$marker_begin"
    printf "export %s='%s'\n" "$env_name" "$escaped_value"
    printf '%s\n' "$marker_end"
  } > "$startup_file"

  rm -f "$temp_file"
}

detect_existing_github_pat_env_var() {
  local config_file="$HOME/.codex/config.toml"

  if [ ! -f "$config_file" ]; then
    return 0
  fi

  awk '
    /^\[mcp_servers\.github\]$/ { in_github=1; next }
    /^\[/ {
      if (in_github) {
        exit
      }
      next
    }
    in_github && /^bearer_token_env_var = "/ {
      line = $0
      sub(/^bearer_token_env_var = "/, "", line)
      sub(/"$/, "", line)
      print line
      exit
    }
  ' "$config_file"
}

choose_github_pat_env_var() {
  local existing_env_var

  if [ -n "$github_pat_env_var" ]; then
    return
  fi

  if [ -n "${GITHUB_MCP_PAT:-}" ]; then
    github_pat_env_var="GITHUB_MCP_PAT"
    return
  fi

  if [ -n "${GITHUB_PAT:-}" ]; then
    github_pat_env_var="GITHUB_PAT"
    return
  fi

  if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    github_pat_env_var="GITHUB_PERSONAL_ACCESS_TOKEN"
    return
  fi

  existing_env_var="$(detect_existing_github_pat_env_var)"
  if [ -n "$existing_env_var" ]; then
    github_pat_env_var="$existing_env_var"
    return
  fi

  github_pat_env_var="GITHUB_PAT"
}

install_specify_cli() {
  if command -v uv >/dev/null 2>&1 || [ -x "$HOME/.local/bin/uv" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v specify >/dev/null 2>&1; then
      printf '\nInstalling spec-kit CLI (specify)...\n'
      uv tool install specify-cli --from git+https://github.com/github/spec-kit.git 2>&1 || {
        printf 'WARNING: Failed to install spec-kit CLI. You can install it manually later:\n' >&2
        printf '  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git\n' >&2
      }
    else
      printf 'spec-kit CLI (specify) already installed.\n'
    fi
  else
    printf '\nNote: uv not found. To install spec-kit CLI, first install uv:\n'
    printf '  curl -LsSf https://astral.sh/uv/install.sh | sh\n'
    printf 'Then install spec-kit:\n'
    printf '  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git\n'
  fi
}

copy_tree_contents() {
  local source_dir="$1"
  local target_dir="$2"
  local path

  if [ ! -d "$source_dir" ]; then
    printf 'WARNING: Template directory not found at %s\n' "$source_dir" >&2
    return
  fi

  mkdir -p "$target_dir"

  for path in "$source_dir"/*; do
    if [ ! -e "$path" ]; then
      continue
    fi

    if [ -d "$path" ]; then
      mkdir -p "$target_dir/$(basename "$path")"
      cp -R "$path"/. "$target_dir/$(basename "$path")/"
    else
      cp "$path" "$target_dir/"
    fi
  done
}

enable_codex_feature() {
  local feature_name="$1"

  if ! codex features enable "$feature_name" >/dev/null 2>&1; then
    printf 'WARNING: Failed to enable Codex feature: %s\n' "$feature_name" >&2
  fi
}

replace_managed_block_in_file() {
  local target_file="$1"
  local marker_begin="$2"
  local marker_end="$3"
  local content_file="$4"

  python3 - "$target_file" "$marker_begin" "$marker_end" "$content_file" <<'PY'
import re
import sys
from pathlib import Path

target_path = Path(sys.argv[1])
marker_begin = sys.argv[2]
marker_end = sys.argv[3]
content_path = Path(sys.argv[4])

existing = target_path.read_text(encoding="utf-8", errors="replace") if target_path.exists() else ""
managed = content_path.read_text(encoding="utf-8")
replacement = f"{marker_begin}\n{managed.rstrip()}\n{marker_end}\n"
pattern = re.compile(re.escape(marker_begin) + r".*?" + re.escape(marker_end) + r"\n?", re.S)

if pattern.search(existing):
    updated = pattern.sub(replacement, existing)
else:
    updated = existing.rstrip()
    if updated:
        updated += "\n\n"
    updated += replacement

target_path.parent.mkdir(parents=True, exist_ok=True)
target_path.write_text(updated.rstrip() + "\n", encoding="utf-8")
PY
}

upsert_http_mcp_server_config() {
  local config_file="$1"
  local server_name="$2"
  local server_url="$3"

  python3 - "$config_file" "$server_name" "$server_url" <<'PY'
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
server_name = sys.argv[2]
server_url = sys.argv[3]

existing = config_path.read_text(encoding="utf-8", errors="replace") if config_path.exists() else ""
pattern = re.compile(
    rf"(?ms)^\[mcp_servers\.{re.escape(server_name)}\]\n.*?(?=^\[|\Z)"
)
entry = f'[mcp_servers.{server_name}]\nurl = "{server_url}"\n'
updated = pattern.sub("", existing).rstrip()
if updated:
    updated += "\n\n"
updated += entry

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(updated.rstrip() + "\n", encoding="utf-8")
PY
}

render_codex_global_agents() {
  local template_file="$1"
  local rules_dir="$2"
  local output_file="$3"

  python3 - "$template_file" "$rules_dir" "$output_file" <<'PY'
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
rules_dir = Path(sys.argv[2])
output_path = Path(sys.argv[3])

template = template_path.read_text(encoding="utf-8")
sections = []
for path in sorted(rules_dir.glob("*.md")):
    sections.append(path.read_text(encoding="utf-8").strip())

rendered = template.replace("{{RULES_SECTIONS}}", "\n\n".join(sections).strip())
output_path.write_text(rendered.rstrip() + "\n", encoding="utf-8")
PY
}

merge_stop_hook_into_config() {
  local hooks_file="$1"
  local hook_command="$2"
  local status_message="$3"

  mkdir -p "$(dirname "$hooks_file")"

  python3 - "$hooks_file" "$hook_command" "$status_message" <<'PY'
import json
import os
import sys

hooks_file, hook_command, status_message = sys.argv[1:]

data = {}
if os.path.exists(hooks_file):
    with open(hooks_file, "r", encoding="utf-8") as handle:
        existing = handle.read().strip()
        if existing:
            data = json.loads(existing)

hooks = data.setdefault("hooks", {})
stop_entries = hooks.setdefault("Stop", [])
target_entry = None

for entry in stop_entries:
    if entry.get("matcher", "") == "":
        target_entry = entry
        break

if target_entry is None:
    target_entry = {"hooks": []}
    stop_entries.append(target_entry)

hook_list = target_entry.setdefault("hooks", [])

for hook in hook_list:
    if hook.get("type") == "command" and hook.get("command") == hook_command:
        hook["statusMessage"] = status_message
        hook["timeout"] = 30
        break
else:
    hook_list.append(
        {
            "type": "command",
            "command": hook_command,
            "statusMessage": status_message,
            "timeout": 30,
        }
    )

with open(hooks_file, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

install_codex_skill_templates() {
  local source_dir="$script_dir/../templates/skills"
  local target_dir="$1"

  copy_tree_contents "$source_dir" "$target_dir"
}

install_codex_agent_templates() {
  local source_dir="$script_dir/../templates/agents"
  local target_dir="$1"

  copy_tree_contents "$source_dir" "$target_dir"
}

install_codex_rule_templates() {
  local target_rules_dir="$1"
  local global_agents_file="$2"
  local rendered_agents_file
  local marker_begin="<!-- >>> ai-dev-bootstrap codex global instructions >>>"
  local marker_end="<!-- <<< ai-dev-bootstrap codex global instructions <<< -->"

  copy_tree_contents "$script_dir/../templates/rules" "$target_rules_dir"

  rendered_agents_file="$(mktemp)"
  render_codex_global_agents "$script_dir/../templates/global-AGENTS.md" "$target_rules_dir" "$rendered_agents_file"
  replace_managed_block_in_file "$global_agents_file" "$marker_begin" "$marker_end" "$rendered_agents_file"
  rm -f "$rendered_agents_file"
}

install_codex_mempalace_protocol() {
  local global_agents_file="$1"
  local marker_begin="<!-- >>> ai-dev-bootstrap mempalace protocol >>>"
  local marker_end="<!-- <<< ai-dev-bootstrap mempalace protocol <<< -->"

  replace_managed_block_in_file \
    "$global_agents_file" \
    "$marker_begin" \
    "$marker_end" \
    "$script_dir/../templates/mempalace-AGENTS.md"
}

install_codex_hook_templates() {
  local target_hooks_dir="$1"
  local hooks_file="$2"
  local hook_command

  copy_tree_contents "$script_dir/../templates/hooks" "$target_hooks_dir"

  if [ -f "$target_hooks_dir/auto-skill-draft.py" ]; then
    chmod +x "$target_hooks_dir/auto-skill-draft.py"
  fi

  hook_command="python3 $target_hooks_dir/auto-skill-draft.py"
  merge_stop_hook_into_config "$hooks_file" "$hook_command" "Queueing reusable Codex session draft"
  enable_codex_feature codex_hooks
}

install_codex_learn_eval_cron() {
  local target_cron_dir="$1"
  local target_learnings_dir="$2"
  local cron_line
  local plist_src
  local plist_dst

  mkdir -p "$target_cron_dir" "$target_learnings_dir/review-evals/logs"
  copy_tree_contents "$script_dir/../templates/cron" "$target_cron_dir"

  if [ -f "$target_cron_dir/learn-eval-monthly.sh" ]; then
    chmod +x "$target_cron_dir/learn-eval-monthly.sh"
  fi

  case "$(uname)" in
    Darwin)
      plist_src="$target_cron_dir/com.user.codex.learn-eval.plist"
      plist_dst="$HOME/Library/LaunchAgents/com.user.codex.learn-eval.plist"
      if [ -f "$plist_src" ]; then
        mkdir -p "$HOME/Library/LaunchAgents"
        sed "s|USERNAME|$(whoami)|g" "$plist_src" > "$plist_dst"
        if command -v launchctl >/dev/null 2>&1; then
          launchctl unload "$plist_dst" 2>/dev/null || true
          launchctl load "$plist_dst"
        fi
      fi
      ;;
    Linux)
      cron_line="0 9 1 * * $target_cron_dir/learn-eval-monthly.sh"
      printf '%s\n' "$cron_line" > "$target_cron_dir/learn-eval.crontab.example"
      if command -v crontab >/dev/null 2>&1; then
        if crontab -l 2>/dev/null | grep -qF "learn-eval-monthly.sh"; then
          :
        else
          (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        fi
      fi
      ;;
  esac
}

install_qwen36_local() {
  local args=()

  if [ "$qwen36_skip_build" -eq 1 ]; then
    args+=(--skip-build)
  fi

  if [ "$qwen36_skip_model" -eq 1 ]; then
    args+=(--skip-model)
  fi

  "$script_dir/install-qwen36-local.sh" "${args[@]}"
}

write_vscode_workspace_config() {
  local vscode_github_server_block=""
  local vscode_mempalace_server_block=""

  mkdir -p "$repo_root/.vscode" "$repo_root/.ai"

  if [ "$skip_github" -eq 0 ]; then
    vscode_github_server_block=$(cat <<EOF
,
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer \${env:${github_pat_env_var}}"
      }
    }
EOF
)
  fi

  if [ "$with_mempalace" -eq 1 ]; then
    vscode_mempalace_server_block=$(cat <<EOF
,
    "mempalace-cloud": {
      "type": "http",
      "url": "https://api.mempalace.cloud/mcp"
    }
EOF
)
  fi

  cat > "$repo_root/.vscode/mcp.json" <<EOF
{
  "servers": {
    "openaiDeveloperDocs": {
      "type": "http",
      "url": "https://developers.openai.com/mcp"
    },
    "context7": {
      "command": "npx",
      "args": [
        "-y",
        "@upstash/context7-mcp"
      ]
    },
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ]
    },
    "memory": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-memory"
      ],
      "env": {
        "MEMORY_FILE_PATH": "\${workspaceFolder}/.ai/memory.json"
      }
    },
    "sequential-thinking": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ]
    }${vscode_github_server_block}${vscode_mempalace_server_block}
  }
}
EOF
}

while (($#)); do
  case "$1" in
    --memory-dir)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--memory-dir requires a path' >&2
        exit 1
      fi
      memory_dir="$2"
      shift 2
      ;;
    --github-pat-env-var)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--github-pat-env-var requires a name' >&2
        exit 1
      fi
      github_pat_env_var="$2"
      shift 2
      ;;
    --prompt-github-pat)
      prompt_github_pat=1
      shift
      ;;
    --write-vscode-workspace-config)
      write_vscode_workspace_config=1
      shift
      ;;
    --install-vscode-extension)
      install_vscode_extension=1
      shift
      ;;
    --skip-rules)
      skip_rules=1
      shift
      ;;
    --skip-skills)
      skip_skills=1
      shift
      ;;
    --skip-agents)
      skip_agents=1
      shift
      ;;
    --skip-codex-memories)
      skip_codex_memories=1
      shift
      ;;
    --with-hooks)
      with_hooks=1
      shift
      ;;
    --with-learn-eval-cron)
      with_learn_eval_cron=1
      shift
      ;;
    --with-mempalace)
      with_mempalace=1
      shift
      ;;
    --with-qwen36-local)
      with_qwen36_local=1
      shift
      ;;
    --qwen36-skip-build)
      qwen36_skip_build=1
      shift
      ;;
    --qwen36-skip-model)
      qwen36_skip_model=1
      shift
      ;;
    --skip-github)
      skip_github=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command node
require_command npm
require_command npx
require_command codex

if [ "$install_vscode_extension" -eq 1 ]; then
  require_command code
fi

if [ -z "$memory_dir" ]; then
  memory_dir="$HOME/.ai/codex"
fi

codex_home="${CODEX_HOME:-$HOME/.codex}"
codex_config_file="$codex_home/config.toml"
codex_global_agents_file="$codex_home/AGENTS.md"
codex_rule_docs_dir="$codex_home/rules-md"
codex_skills_dir="$codex_home/skills"
codex_agents_dir="$codex_home/agents"
codex_hooks_dir="$codex_home/hooks"
codex_hooks_file="$codex_home/hooks.json"
codex_cron_dir="$codex_home/cron"
codex_learnings_dir="$codex_home/learnings"

choose_github_pat_env_var
install_specify_cli

mkdir -p "$memory_dir"
mkdir -p "$codex_home" "$codex_learnings_dir"
memory_dir="$(cd "$memory_dir" && pwd)"
memory_file="$memory_dir/memory.json"
shell_startup_file="$(detect_shell_startup_file)"

configure_mcp_server openaiDeveloperDocs --url https://developers.openai.com/mcp
configure_mcp_server context7 -- npx -y @upstash/context7-mcp
configure_mcp_server memory --env MEMORY_FILE_PATH="$memory_file" -- npx -y @modelcontextprotocol/server-memory
configure_mcp_server sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
configure_mcp_server playwright -- npx @playwright/mcp@latest

if [ "$skip_github" -eq 0 ]; then
  if [ "$prompt_github_pat" -eq 1 ]; then
    if [ ! -t 0 ]; then
      printf 'Cannot prompt for %s without an interactive terminal.\n' "$github_pat_env_var" >&2
      exit 1
    fi

    printf 'Enter GitHub PAT for %s: ' "$github_pat_env_var" >&2
    read -r -s github_pat_value
    printf '\n' >&2

    if [ -z "$github_pat_value" ]; then
      printf 'GitHub PAT cannot be empty when --prompt-github-pat is used.\n' >&2
      exit 1
    fi

    persist_env_var_to_startup_file "$github_pat_env_var" "$github_pat_value" "$shell_startup_file"
    export "$github_pat_env_var=$github_pat_value"
  fi

  configure_mcp_server github --url https://api.githubcopilot.com/mcp/ --bearer-token-env-var "$github_pat_env_var"

  if [ -z "${!github_pat_env_var-}" ]; then
    printf 'Warning: %s is not set in this shell. GitHub MCP is configured, but auth only works when that env var exists before starting codex.\n' "$github_pat_env_var" >&2
  fi
fi

if [ "$with_mempalace" -eq 1 ]; then
  upsert_http_mcp_server_config "$codex_config_file" "mempalace-cloud" "https://api.mempalace.cloud/mcp"
fi

if [ "$write_vscode_workspace_config" -eq 1 ]; then
  write_vscode_workspace_config
fi

if [ "$skip_codex_memories" -eq 0 ]; then
  enable_codex_feature memories
fi

if [ "$skip_rules" -eq 0 ]; then
  install_codex_rule_templates "$codex_rule_docs_dir" "$codex_global_agents_file"
fi

if [ "$with_mempalace" -eq 1 ]; then
  install_codex_mempalace_protocol "$codex_global_agents_file"
fi

if [ "$skip_skills" -eq 0 ]; then
  install_codex_skill_templates "$codex_skills_dir"
fi

if [ "$skip_agents" -eq 0 ]; then
  install_codex_agent_templates "$codex_agents_dir"
fi

if [ "$with_hooks" -eq 1 ]; then
  install_codex_hook_templates "$codex_hooks_dir" "$codex_hooks_file"
fi

if [ "$with_learn_eval_cron" -eq 1 ]; then
  install_codex_learn_eval_cron "$codex_cron_dir" "$codex_learnings_dir"
fi

if [ "$with_qwen36_local" -eq 1 ]; then
  install_qwen36_local
fi

if [ "$install_vscode_extension" -eq 1 ]; then
  code --install-extension openai.chatgpt
fi

printf '\nSetup complete.\n\n'
printf 'Codex config: %s\n' "$codex_config_file"
printf 'Global memory file: %s\n' "$memory_file"
if [ "$skip_github" -eq 0 ]; then
  printf 'GitHub env var: %s\n' "$github_pat_env_var"
fi
if [ "$skip_codex_memories" -eq 0 ]; then
  printf 'Codex native memories: enabled\n'
fi
if [ "$skip_rules" -eq 0 ]; then
  printf 'Codex global AGENTS: %s\n' "$codex_global_agents_file"
  printf 'Codex rule fragments: %s\n' "$codex_rule_docs_dir"
fi
if [ "$skip_skills" -eq 0 ]; then
  printf 'Codex skills: %s\n' "$codex_skills_dir"
fi
if [ "$skip_agents" -eq 0 ]; then
  printf 'Codex custom agents: %s\n' "$codex_agents_dir"
fi
if [ "$with_hooks" -eq 1 ]; then
  printf 'Codex hooks: %s\n' "$codex_hooks_file"
  printf 'Codex learnings: %s\n' "$codex_learnings_dir"
fi
if [ "$with_learn_eval_cron" -eq 1 ]; then
  printf 'Codex learn-eval scheduler assets: %s\n' "$codex_cron_dir"
fi
if [ "$with_mempalace" -eq 1 ]; then
  printf 'MemPalace MCP: mempalace-cloud (%s)\n' "https://api.mempalace.cloud/mcp"
  printf 'MemPalace protocol: %s\n' "$codex_global_agents_file"
fi
if [ "$with_qwen36_local" -eq 1 ]; then
  printf 'Qwen3.6 local coding worker: %s\n' "$HOME/.local/bin/qwen36-code"
fi
if [ "$write_vscode_workspace_config" -eq 1 ]; then
  printf 'Workspace VS Code MCP file: %s\n' "$repo_root/.vscode/mcp.json"
fi
if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
  printf 'GitHub PAT saved to: %s\n' "$shell_startup_file"
fi
printf '\nConfigured MCP servers:\n'
codex mcp list

cat <<'EOF'

Next steps:
1. Start a fresh `codex --search` session.
2. If you use GitHub MCP, make sure the configured PAT env var exists before starting Codex.
3. Reload VS Code if it was already open.
4. In Codex, try `$session-handoff`, `$review`, `$quality-gate`, or `$mine-learnings` to verify the installed skills.
5. If you enabled hooks, restart Codex so the experimental hook config is picked up.
6. If you enabled monthly learn-eval, check the scheduler entry or run the installed script once manually.
7. In the Codex sidebar, test `memory`, `context7`, `sequential-thinking`, and `openaiDeveloperDocs`.
EOF

if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
  cat <<EOF

GitHub PAT note:
- Open a new terminal or run `source ${shell_startup_file}` before starting a new Codex session outside this script.
EOF
fi

if [ "$with_mempalace" -eq 1 ]; then
  cat <<'EOF'

MemPalace note:
- The hosted `mempalace-cloud` MCP is configured globally, but OAuth still needs a login step.
- Run `codex mcp login mempalace-cloud` in a fresh terminal to complete MemPalace auth.
- Codex does not auto-save to MemPalace; ask it explicitly to save important decisions or lessons.
EOF
fi
