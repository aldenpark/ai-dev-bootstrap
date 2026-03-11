#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

memory_dir="$repo_root/.ai"
github_pat_env_var="GITHUB_MCP_PAT"
install_vscode_extension=0
skip_github=0
prompt_github_pat=0

usage() {
  cat <<'EOF'
Usage: ./scripts/install-codex-mcp-setup.sh [options]

Options:
  --memory-dir PATH              Override the Memory MCP directory.
  --github-pat-env-var NAME      Env var name used by the GitHub MCP.
  --prompt-github-pat            Prompt for the GitHub PAT and save it to the detected shell startup file.
  --install-vscode-extension     Install the VS Code Codex extension.
  --skip-github                  Skip GitHub MCP configuration.
  -h, --help                     Show this help message.
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
    --install-vscode-extension)
      install_vscode_extension=1
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

mkdir -p "$memory_dir"
memory_dir="$(cd "$memory_dir" && pwd)"
memory_file="$memory_dir/memory.json"
shell_startup_file="$(detect_shell_startup_file)"

mkdir -p "$repo_root/.vscode"

configure_mcp_server openaiDeveloperDocs --url https://developers.openai.com/mcp
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

if [ "$skip_github" -eq 0 ]; then
  vscode_inputs_block='  "inputs": [
    {
      "type": "promptString",
      "id": "github_mcp_pat",
      "description": "GitHub PAT for the remote GitHub MCP server",
      "password": true
    }
  ],'
  vscode_github_server_block=',
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${input:github_mcp_pat}"
      }
    }'
else
  vscode_inputs_block='  "inputs": [],'
  vscode_github_server_block=''
fi

cat > "$repo_root/.vscode/mcp.json" <<EOF
{
${vscode_inputs_block}
  "servers": {
    "openaiDeveloperDocs": {
      "type": "http",
      "url": "https://developers.openai.com/mcp"
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
        "MEMORY_FILE_PATH": "$memory_file"
      }
    },
    "sequential-thinking": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sequential-thinking"
      ]
    }
${vscode_github_server_block}
  }
}
EOF

if [ ! -f "$repo_root/.vscode/extensions.json" ]; then
  cat > "$repo_root/.vscode/extensions.json" <<'EOF'
{
  "recommendations": [
    "openai.chatgpt"
  ]
}
EOF
fi

if [ "$install_vscode_extension" -eq 1 ]; then
  code --install-extension openai.chatgpt
fi

printf '\nSetup complete.\n\n'
printf 'Repo root: %s\n' "$repo_root"
printf 'Memory file: %s\n' "$memory_file"
printf 'GitHub env var: %s\n' "$github_pat_env_var"
if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
  printf 'GitHub PAT saved to: %s\n' "$shell_startup_file"
fi
printf '\nConfigured MCP servers:\n'
codex mcp list

cat <<'EOF'

Next steps:
1. Start a fresh `codex --search` session.
2. If you use GitHub MCP, make sure the PAT env var exists before starting Codex.
3. Reload VS Code if it was already open.
4. In the Codex sidebar, test `memory`, `sequential-thinking`, and `openaiDeveloperDocs`.
EOF

if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
  cat <<EOF

GitHub PAT note:
- Open a new terminal or run `source ${shell_startup_file}` before starting a new Codex session outside this script.
EOF
fi
