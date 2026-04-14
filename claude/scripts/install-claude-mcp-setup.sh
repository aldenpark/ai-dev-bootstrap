#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

memory_dir=""
github_pat=""
skip_github=0
skip_playwright=0
install_global=0
skip_rules=0
skip_skills=0
with_mempalace=0
with_caveman=0
with_atlassian=0
with_ado=0
ado_org=""

usage() {
  cat <<'EOF'
Usage: ./claude/scripts/install-claude-mcp-setup.sh [options]

Options:
  --global                       Install MCP servers to user-level config (available in all projects).
  --memory-dir PATH              Override the Memory MCP directory.
  --github-pat TOKEN              GitHub Personal Access Token for GitHub MCP server.
  --skip-github                  Skip GitHub MCP configuration.
  --skip-playwright              Skip Playwright MCP configuration.
  --skip-rules                   Skip installing global rules (~/.claude/rules/).
  --skip-skills                  Skip installing skills (~/.claude/skills/).
  --with-mempalace               Install MemPalace plugin (memory palace for Claude).
  --with-caveman                 Install Caveman plugin (terse output, ~75% token savings).
  --with-atlassian               Add Atlassian MCP (Jira, Confluence, Compass via OAuth).
  --with-ado                     Add Azure DevOps MCP (work items, repos, PRs).
  --ado-org NAME                 Azure DevOps org name (e.g. netdocuments).
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

build_server_blocks() {
  # Builds MCP server block JSON fragments into the global SERVER_BLOCKS array.
  # Caller must declare: local -a SERVER_BLOCKS=()
  SERVER_BLOCKS+=("$(cat <<JSONEOF
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_FILE_PATH": "$memory_file"
      }
    }
JSONEOF
)")

  SERVER_BLOCKS+=("$(cat <<'JSONEOF'
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
JSONEOF
)")

  SERVER_BLOCKS+=("$(cat <<'JSONEOF'
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
JSONEOF
)")

  if [ "$skip_playwright" -eq 0 ]; then
    SERVER_BLOCKS+=("$(cat <<'JSONEOF'
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
JSONEOF
)")
  fi

  if [ "$skip_github" -eq 0 ]; then
    SERVER_BLOCKS+=("$(cat <<JSONEOF
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer $github_pat"
      }
    }
JSONEOF
)")
  fi
}

join_blocks() {
  # Joins SERVER_BLOCKS array elements with ",\n"
  local joined=""
  for i in "${!SERVER_BLOCKS[@]}"; do
    if [ "$i" -gt 0 ]; then
      joined+=$',\n'
    fi
    joined+="${SERVER_BLOCKS[$i]}"
  done
  printf '%s' "$joined"
}

write_claude_mcp_config() {
  local -a SERVER_BLOCKS=()
  build_server_blocks
  local joined
  joined="$(join_blocks)"

  cat > "$repo_root/.mcp.json" <<EOF
{
  "mcpServers": {
$joined
  }
}
EOF

  printf 'Wrote Claude MCP config to: %s\n' "$repo_root/.mcp.json"
}

merge_json_mcpservers() {
  # Merges mcpServers into an existing JSON settings file using python3.
  # Usage: merge_json_mcpservers <target_file> <key_name> <servers_json>
  local target_file="$1"
  local key_name="$2"
  local servers_json="$3"

  python3 -c "
import json, sys, os

target = sys.argv[1]
key = sys.argv[2]
servers = json.loads(sys.argv[3])

if os.path.exists(target):
    with open(target) as f:
        data = json.load(f)
else:
    data = {}

if key not in data:
    data[key] = {}
data[key].update(servers)

with open(target, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$target_file" "$key_name" "$servers_json"
}

build_servers_json() {
  # Builds a JSON object of MCP server configs suitable for merging.
  local -a parts=()

  parts+=("$(cat <<JSONEOF
"memory": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-memory"],
  "env": {
    "MEMORY_FILE_PATH": "$memory_file"
  }
}
JSONEOF
)")

  parts+=("$(cat <<'JSONEOF'
"context7": {
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp"]
}
JSONEOF
)")

  parts+=("$(cat <<'JSONEOF'
"sequential-thinking": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
}
JSONEOF
)")

  if [ "$skip_playwright" -eq 0 ]; then
    parts+=("$(cat <<'JSONEOF'
"playwright": {
  "command": "npx",
  "args": ["@playwright/mcp@latest"]
}
JSONEOF
)")
  fi

  if [ "$skip_github" -eq 0 ]; then
    parts+=("$(cat <<JSONEOF
"github": {
  "type": "http",
  "url": "https://api.githubcopilot.com/mcp/",
  "headers": {
    "Authorization": "Bearer $github_pat"
  }
}
JSONEOF
)")
  fi

  local joined=""
  for i in "${!parts[@]}"; do
    if [ "$i" -gt 0 ]; then
      joined+=","
    fi
    joined+="${parts[$i]}"
  done
  printf '{%s}' "$joined"
}

claude_mcp_set_json() {
  # Idempotent add via JSON. Usage: claude_mcp_set_json <name> <json>
  local name="$1" json="$2"
  claude mcp remove -s user "$name" 2>/dev/null || true
  claude mcp add-json -s user "$name" "$json"
}

write_global_claude_config() {
  require_command claude

  # Use add-json for all servers — avoids argument-ordering issues with `claude mcp add`
  claude_mcp_set_json memory "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@modelcontextprotocol/server-memory\"],\"env\":{\"MEMORY_FILE_PATH\":\"$memory_file\"}}"

  claude_mcp_set_json context7 '{"type":"stdio","command":"npx","args":["-y","@upstash/context7-mcp"]}'

  claude_mcp_set_json sequential-thinking '{"type":"stdio","command":"npx","args":["-y","@modelcontextprotocol/server-sequential-thinking"]}'

  if [ "$skip_playwright" -eq 0 ]; then
    claude_mcp_set_json playwright '{"type":"stdio","command":"npx","args":["@playwright/mcp@latest"]}'
  fi

  if [ "$skip_github" -eq 0 ]; then
    claude_mcp_set_json github "{\"type\":\"http\",\"url\":\"https://api.githubcopilot.com/mcp/\",\"headers\":{\"Authorization\":\"Bearer ${github_pat}\"}}"
  fi

  printf 'Added MCP servers to Claude Code (user scope).\n'
}

write_global_vscode_config() {
  local vscode_settings
  case "$(uname)" in
    Darwin)
      vscode_settings="$HOME/Library/Application Support/Code/User/settings.json"
      ;;
    Linux)
      vscode_settings="$HOME/.config/Code/User/settings.json"
      ;;
    *)
      printf 'Unsupported OS for VS Code global config. Skipping.\n' >&2
      return
      ;;
  esac

  local servers_json
  servers_json="$(build_servers_json)"

  mkdir -p "$(dirname "$vscode_settings")"
  merge_json_mcpservers "$vscode_settings" "mcp" "$servers_json"
  printf 'Merged MCP servers into: %s\n' "$vscode_settings"
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
    --global)
      install_global=1
      shift
      ;;
    --github-pat)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--github-pat requires a token' >&2
        exit 1
      fi
      github_pat="$2"
      shift 2
      ;;
    --skip-github)
      skip_github=1
      shift
      ;;
    --skip-playwright)
      skip_playwright=1
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
    --with-mempalace)
      with_mempalace=1
      shift
      ;;
    --with-caveman)
      with_caveman=1
      shift
      ;;
    --with-atlassian)
      with_atlassian=1
      shift
      ;;
    --with-ado)
      with_ado=1
      shift
      ;;
    --ado-org)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--ado-org requires an org name' >&2
        exit 1
      fi
      ado_org="$2"
      shift 2
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

# Ensure pyenv is available if installed (scripts may not inherit shell init)
if [ -d "$HOME/.pyenv" ] && ! command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
fi

# Install spec-kit CLI (specify) via uv if not already present
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

# Resolve GitHub PAT: flag > env var > existing config > prompt > skip
if [ "$skip_github" -eq 0 ] && [ -z "$github_pat" ]; then
  if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
    github_pat="$GITHUB_PERSONAL_ACCESS_TOKEN"
  elif [ -n "${GITHUB_PAT:-}" ]; then
    github_pat="$GITHUB_PAT"
  else
    # Check if already configured in ~/.claude.json
    existing_pat="$(python3 -c "
import json, os, sys
p = os.path.expanduser('~/.claude.json')
if os.path.exists(p):
    d = json.load(open(p))
    h = d.get('mcpServers',{}).get('github',{}).get('headers',{}).get('Authorization','')
    if h.startswith('Bearer '):
        print(h[7:])
" 2>/dev/null || true)"
    if [ -n "$existing_pat" ]; then
      github_pat="$existing_pat"
      printf 'Found existing GitHub PAT in ~/.claude.json.\n'
    else
      printf '\nGitHub MCP requires a Personal Access Token.\n'
      printf 'Create one at: https://github.com/settings/personal-access-tokens/new\n'
      printf 'Enter GitHub PAT (or press Enter to skip GitHub MCP): '
      read -r github_pat
      if [ -z "$github_pat" ]; then
        printf 'Skipping GitHub MCP.\n'
        skip_github=1
      else
        # Persist PAT to shell profile so future runs detect it
        shell_profile="$HOME/.zprofile"
        if ! grep -q 'GITHUB_PAT' "$shell_profile" 2>/dev/null; then
          printf '\nexport GITHUB_PAT="%s"\n' "$github_pat" >> "$shell_profile"
          printf 'Saved GITHUB_PAT to %s\n' "$shell_profile"
        fi
      fi
    fi
  fi
fi

# Default memory_dir based on install scope
if [ -z "$memory_dir" ]; then
  if [ "$install_global" -eq 1 ]; then
    memory_dir="$HOME/.ai"
  else
    memory_dir="$repo_root/.ai"
  fi
fi

mkdir -p "$memory_dir"
memory_dir="$(cd "$memory_dir" && pwd)"
memory_file="$memory_dir/memory.json"

if [ "$install_global" -eq 1 ]; then
  write_global_claude_config
  write_global_vscode_config

  # Install global CLAUDE.md rules
  global_claude_md="$HOME/.claude/CLAUDE.md"
  template_claude_md="$script_dir/../templates/global-CLAUDE.md"
  if [ -f "$template_claude_md" ]; then
    mkdir -p "$(dirname "$global_claude_md")"
    cp "$template_claude_md" "$global_claude_md"
    printf 'Installed global Claude rules to: %s\n' "$global_claude_md"
  else
    printf 'WARNING: Template not found at %s — skipping global CLAUDE.md\n' "$template_claude_md" >&2
  fi

  # Install modular rules
  if [ "$skip_rules" -eq 0 ]; then
    template_rules_dir="$script_dir/../templates/rules"
    target_rules_dir="$HOME/.claude/rules"
    if [ -d "$template_rules_dir" ]; then
      mkdir -p "$target_rules_dir"
      for rule_file in "$template_rules_dir"/*.md; do
        [ -f "$rule_file" ] || continue
        cp "$rule_file" "$target_rules_dir/$(basename "$rule_file")"
      done
      printf 'Installed rules to: %s\n' "$target_rules_dir"
    else
      printf 'WARNING: Rules templates not found at %s — skipping\n' "$template_rules_dir" >&2
    fi
  fi

  # Install skills
  if [ "$skip_skills" -eq 0 ]; then
    template_skills_dir="$script_dir/../templates/skills"
    target_skills_dir="$HOME/.claude/skills"
    if [ -d "$template_skills_dir" ]; then
      mkdir -p "$target_skills_dir"
      for skill_dir in "$template_skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        mkdir -p "$target_skills_dir/$skill_name"
        cp "$skill_dir"SKILL.md "$target_skills_dir/$skill_name/SKILL.md" 2>/dev/null || true
      done
      printf 'Installed skills to: %s\n' "$target_skills_dir"
    else
      printf 'WARNING: Skills templates not found at %s — skipping\n' "$template_skills_dir" >&2
    fi
  fi

  # Optional: Install MemPalace plugin
  if [ "$with_mempalace" -eq 1 ]; then
    printf '\nInstalling MemPalace plugin...\n'
    if command -v claude >/dev/null 2>&1; then
      claude plugin marketplace add MemPalace/mempalace 2>/dev/null || true
      claude plugin install mempalace@mempalace 2>&1 || {
        printf 'WARNING: MemPalace plugin install failed. Install manually:\n' >&2
        printf '  claude plugin marketplace add MemPalace/mempalace\n' >&2
        printf '  claude plugin install mempalace@mempalace\n' >&2
      }
    fi
    if command -v pip3 >/dev/null 2>&1; then
      pip3 install --user mempalace 2>&1 || {
        printf 'WARNING: MemPalace pip install failed. Install manually: pip3 install mempalace\n' >&2
      }
    fi
    printf 'MemPalace install attempted. Run "mempalace init" in your project to set up.\n'
  fi

  # Optional: Install Caveman plugin
  if [ "$with_caveman" -eq 1 ]; then
    printf '\nInstalling Caveman plugin...\n'
    if command -v claude >/dev/null 2>&1; then
      claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null || true
      claude plugin install caveman@caveman 2>&1 || {
        printf 'WARNING: Caveman plugin install failed. Install manually:\n' >&2
        printf '  claude plugin marketplace add JuliusBrussee/caveman\n' >&2
        printf '  claude plugin install caveman@caveman\n' >&2
      }
    fi
    printf 'Caveman install attempted. Use "/caveman" in a session to activate terse mode.\n'
  fi

  # Optional: Add Atlassian MCP (Jira, Confluence, Compass)
  if [ "$with_atlassian" -eq 1 ]; then
    printf '\nAdding Atlassian MCP server...\n'
    if command -v claude >/dev/null 2>&1; then
      claude mcp remove -s user atlassian 2>/dev/null || true
      claude mcp add --transport http -s user atlassian https://mcp.atlassian.com/v1/mcp 2>&1 || {
        printf 'WARNING: Atlassian MCP add failed. Add manually:\n' >&2
        printf '  claude mcp add --transport http --scope user atlassian https://mcp.atlassian.com/v1/mcp\n' >&2
      }
      printf 'Atlassian MCP added. Auth is required on first use:\n'
      printf '  1. Restart Claude Code (or start a new session)\n'
      printf '  2. Run /mcp — you will see atlassian listed as needing auth\n'
      printf '  3. /mcp will walk you through the OAuth 2.1 flow (opens browser)\n'
      printf '  Once authenticated, you get tools for Jira, Confluence, and Compass.\n'
    else
      printf 'WARNING: claude CLI not found — cannot add Atlassian MCP.\n' >&2
      printf 'Add manually: claude mcp add --transport http --scope user atlassian https://mcp.atlassian.com/v1/mcp\n' >&2
    fi
  fi

  # Optional: Add Azure DevOps MCP (work items, repos, PRs)
  if [ "$with_ado" -eq 1 ]; then
    printf '\nAdding Azure DevOps MCP server...\n'

    # Resolve ADO org name: flag > prompt
    if [ -z "$ado_org" ]; then
      printf 'Enter Azure DevOps org name (e.g. netdocuments): '
      read -r ado_org
      if [ -z "$ado_org" ]; then
        printf 'Skipping Azure DevOps MCP — no org name provided.\n'
        with_ado=0
      fi
    fi

    if [ "$with_ado" -eq 1 ]; then
      if command -v claude >/dev/null 2>&1; then
        claude mcp remove -s user azure-devops 2>/dev/null || true
        claude mcp add -s user azure-devops -- npx -y @azure-devops/mcp "$ado_org" 2>&1 || {
          printf 'WARNING: Azure DevOps MCP add failed. Add manually:\n' >&2
          printf '  claude mcp add --scope user azure-devops -- npx -y @azure-devops/mcp %s\n' "$ado_org" >&2
        }
        printf 'Azure DevOps MCP added for org: %s\n' "$ado_org"
      else
        printf 'WARNING: claude CLI not found — cannot add Azure DevOps MCP.\n' >&2
        printf 'Add manually: claude mcp add --scope user azure-devops -- npx -y @azure-devops/mcp %s\n' "$ado_org" >&2
      fi
    fi
  fi

  printf '\nGlobal setup complete.\n\n'
  printf 'Memory file: %s\n' "$memory_file"
  printf 'Claude config: %s\n' "$HOME/.claude.json"
  printf 'Global rules: %s\n' "$HOME/.claude/CLAUDE.md"

  case "$(uname)" in
    Darwin) printf 'VS Code settings: %s\n' "$HOME/Library/Application Support/Code/User/settings.json" ;;
    Linux) printf 'VS Code settings: %s\n' "$HOME/.config/Code/User/settings.json" ;;
  esac

  if [ "$skip_rules" -eq 0 ]; then
    printf 'Rules: %s\n' "$HOME/.claude/rules/"
  fi

  if [ "$skip_skills" -eq 0 ]; then
    printf 'Skills: %s\n' "$HOME/.claude/skills/"
  fi

  if [ "$skip_github" -eq 0 ]; then
    printf 'GitHub MCP: configured with PAT\n'
  fi

  if [ "$with_mempalace" -eq 1 ]; then
    printf 'MemPalace: installed\n'
  fi

  if [ "$with_caveman" -eq 1 ]; then
    printf 'Caveman: installed\n'
  fi

  if [ "$with_atlassian" -eq 1 ]; then
    printf 'Atlassian MCP: added (auth required on first use via /mcp)\n'
  fi

  if [ "$with_ado" -eq 1 ]; then
    printf 'Azure DevOps MCP: configured\n'
  fi

  cat <<'EOF'

Next steps:
1. Open any project in VS Code or start Claude Code in any directory.
2. MCP servers should be available globally: memory, context7, sequential-thinking, playwright, and github.
3. Test with: "Use sequential-thinking to break down a small task into phases."
4. Test with: "Use memory to store a test decision."
5. For spec-driven development, install spec-kit CLI separately: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
EOF

else
  write_claude_mcp_config

  # Update .vscode/mcp.json for VS Code Claude extension compatibility
  mkdir -p "$repo_root/.vscode"

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

  if [ "$skip_github" -eq 0 ]; then
    vscode_servers+=("$(cat <<JSONEOF
    "github": {
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": {
        "Authorization": "Bearer $github_pat"
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
    printf 'GitHub MCP: configured with PAT\n'
  fi

  cat <<'EOF'

Next steps:
1. Open this repo in VS Code with the Claude extension.
2. Start a fresh Claude Code session in this workspace.
3. Verify MCP servers load: memory, context7, sequential-thinking, playwright, and github.
4. Test with: "Use sequential-thinking to break down a small task into phases."
5. Test with: "Use memory to store a test decision."
6. For spec-driven development, install spec-kit CLI separately: uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
EOF
fi
