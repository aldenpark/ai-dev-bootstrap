#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

memory_dir="$repo_root/.ai"
github_pat_env_var="GITHUB_MCP_PAT"
skip_github=0
prompt_github_pat=0
skip_playwright=0

usage() {
  cat <<'EOF'
Usage: ./claude/scripts/install-claude-mcp-setup.sh [options]

Options:
  --memory-dir PATH              Override the Memory MCP directory.
  --github-pat-env-var NAME      Env var name used by the GitHub MCP.
  --prompt-github-pat            Prompt for the GitHub PAT and save it to the detected shell startup file.
  --skip-github                  Skip GitHub MCP configuration.
  --skip-playwright              Skip Playwright MCP configuration.
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
  local marker_begin="# >>> claude-github-pat >>>"
  local marker_end="# <<< claude-github-pat <<<"
  local escaped_value
  local temp_file

  escaped_value="$(escape_for_single_quotes "$env_value")"
  touch "$startup_file"
  temp_file="$(mktemp)"
  trap 'rm -f "$temp_file"' EXIT

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
  trap - EXIT
}

write_claude_mcp_config() {
  # Collect server blocks into an array, then join with commas.
  # This avoids fragile comma placement when optional servers are skipped.
  local -a server_blocks=()

  server_blocks+=("$(cat <<JSONEOF
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": "$memory_file"
      }
    }
JSONEOF
)")

  server_blocks+=("$(cat <<'JSONEOF'
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
JSONEOF
)")

  server_blocks+=("$(cat <<'JSONEOF'
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
JSONEOF
)")

  if [ "$skip_playwright" -eq 0 ]; then
    server_blocks+=("$(cat <<'JSONEOF'
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
JSONEOF
)")
  fi

  if [ "$skip_github" -eq 0 ]; then
    server_blocks+=("$(cat <<JSONEOF
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer \${$github_pat_env_var}"
      }
    }
JSONEOF
)")
  fi

  # Join blocks with ",\n"
  local joined=""
  for i in "${!server_blocks[@]}"; do
    if [ "$i" -gt 0 ]; then
      joined+=$',\n'
    fi
    joined+="${server_blocks[$i]}"
  done

  # Write project-level .mcp.json (preferred for per-repo config)
  cat > "$repo_root/.mcp.json" <<EOF
{
  "mcpServers": {
$joined
  }
}
EOF

  printf 'Wrote Claude MCP config to: %s\n' "$repo_root/.mcp.json"
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
    --skip-github)
      skip_github=1
      shift
      ;;
    --skip-playwright)
      skip_playwright=1
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

mkdir -p "$memory_dir"
memory_dir="$(cd "$memory_dir" && pwd)"
memory_file="$memory_dir/memory.json"
shell_startup_file="$(detect_shell_startup_file)"

if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
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

write_claude_mcp_config

# Update .vscode/mcp.json for VS Code Claude extension compatibility
mkdir -p "$repo_root/.vscode"

# Build VS Code inputs block
if [ "$skip_github" -eq 0 ]; then
  vscode_inputs_block='  "inputs": [
    {
      "type": "promptString",
      "id": "github_mcp_pat",
      "description": "GitHub PAT for the remote GitHub MCP server",
      "password": true
    }
  ],'
else
  vscode_inputs_block='  "inputs": [],'
fi

# Build VS Code server blocks array, then join with commas
vscode_servers=()

vscode_servers+=("$(cat <<JSONEOF
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": "$memory_file"
      }
    }
JSONEOF
)")

vscode_servers+=("$(cat <<'JSONEOF'
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
JSONEOF
)")

vscode_servers+=("$(cat <<'JSONEOF'
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
JSONEOF
)")

if [ "$skip_playwright" -eq 0 ]; then
  vscode_servers+=("$(cat <<'JSONEOF'
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
JSONEOF
)")
fi

vscode_servers+=("$(cat <<'JSONEOF'
    "openaiDeveloperDocs": {
      "type": "http",
      "url": "https://developers.openai.com/mcp"
    }
JSONEOF
)")

if [ "$skip_github" -eq 0 ]; then
  vscode_servers+=("$(cat <<'JSONEOF'
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer ${input:github_mcp_pat}"
      }
    }
JSONEOF
)")
fi

# Join blocks with ",\n"
vscode_joined=""
for i in "${!vscode_servers[@]}"; do
  if [ "$i" -gt 0 ]; then
    vscode_joined+=$',\n'
  fi
  vscode_joined+="${vscode_servers[$i]}"
done

cat > "$repo_root/.vscode/mcp.json" <<EOF
{
${vscode_inputs_block}
  "servers": {
$vscode_joined
  }
}
EOF

printf '\nSetup complete.\n\n'
printf 'Repo root: %s\n' "$repo_root"
printf 'Memory file: %s\n' "$memory_file"
printf 'Claude MCP config: %s\n' "$repo_root/.mcp.json"
printf 'VS Code MCP config: %s\n' "$repo_root/.vscode/mcp.json"

if [ "$skip_github" -eq 0 ]; then
  printf 'GitHub env var: %s\n' "$github_pat_env_var"
  if [ "$prompt_github_pat" -eq 1 ]; then
    printf 'GitHub PAT saved to: %s\n' "$shell_startup_file"
  fi
fi

cat <<'EOF'

Next steps:
1. Open this repo in VS Code with the Claude extension.
2. Start a fresh Claude Code session in this workspace.
3. Verify MCP servers load: memory, context7, sequential-thinking, and playwright.
4. Test with: "Use sequential-thinking to break down a small task into phases."
5. Test with: "Use memory to store a test decision."
EOF

if [ "$skip_github" -eq 0 ] && [ "$prompt_github_pat" -eq 1 ]; then
  cat <<EOF

GitHub PAT note:
- Open a new terminal or run \`source ${shell_startup_file}\` before starting a new Claude session outside this script.
EOF
fi
