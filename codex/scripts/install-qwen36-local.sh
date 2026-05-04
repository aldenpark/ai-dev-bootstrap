#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

skip_build=0
skip_model=0
skip_codex_assets=0
model_dir="$HOME/models/qwen3.6-35b-a3b"
llama_src_dir="$HOME/src/llama.cpp"
model_file="Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
model_url="https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf?download=true"

usage() {
  cat <<'EOF'
Usage: ./codex/scripts/install-qwen36-local.sh [options]

Installs the local Qwen3.6 coding-worker setup:

- qwen36-server and qwen36-code in ~/.local/bin
- qwen36-coder skill in ~/.codex/skills
- local Qwen coding rule in ~/.codex/rules-md and ~/.codex/AGENTS.md
- CUDA llama.cpp build when nvcc is available, CPU build otherwise
- Qwen3.6-35B-A3B UD-IQ4_NL GGUF model download with resume support

Options:
  --model-dir PATH       Where to store the GGUF model. Default: ~/models/qwen3.6-35b-a3b
  --llama-src-dir PATH   Where to clone/build llama.cpp. Default: ~/src/llama.cpp
  --skip-build           Do not build llama.cpp or link llama-server/llama-cli.
  --skip-model           Do not download the GGUF model.
  --skip-codex-assets    Do not install Codex skill/rule/global instruction assets.
  -h, --help             Show this help message.
EOF
}

require_command() {
  local name="$1"

  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$name" >&2
    exit 1
  fi
}

copy_tree_contents() {
  local source_dir="$1"
  local target_dir="$2"
  local path

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
sections = [path.read_text(encoding="utf-8").strip() for path in sorted(rules_dir.glob("*.md"))]
output_path.write_text(
    template.replace("{{RULES_SECTIONS}}", "\n\n".join(sections).strip()).rstrip() + "\n",
    encoding="utf-8",
)
PY
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

install_codex_assets() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local rendered_agents_file

  copy_tree_contents "$repo_root/codex/templates/qwen36/bin" "$HOME/.local/bin"
  chmod +x "$HOME/.local/bin/qwen36-server" "$HOME/.local/bin/qwen36-code"

  if [ "$skip_codex_assets" -eq 1 ]; then
    return
  fi

  copy_tree_contents "$repo_root/codex/templates/qwen36/skills" "$codex_home/skills"
  copy_tree_contents "$repo_root/codex/templates/qwen36/rules" "$codex_home/rules-md"

  rendered_agents_file="$(mktemp)"
  render_codex_global_agents "$repo_root/codex/templates/global-AGENTS.md" "$codex_home/rules-md" "$rendered_agents_file"
  replace_managed_block_in_file \
    "$codex_home/AGENTS.md" \
    "<!-- >>> ai-dev-bootstrap codex global instructions >>>" \
    "<!-- <<< ai-dev-bootstrap codex global instructions <<< -->" \
    "$rendered_agents_file"
  rm -f "$rendered_agents_file"
}

install_cmake_if_needed() {
  if command -v cmake >/dev/null 2>&1; then
    return
  fi

  if command -v uv >/dev/null 2>&1 || [ -x "$HOME/.local/bin/uv" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    uv tool install cmake
    return
  fi

  printf 'Missing cmake. Install cmake or uv, then rerun this script.\n' >&2
  exit 1
}

build_llama_cpp() {
  local cmake_cuda_flag="-DGGML_CUDA=OFF"

  require_command git
  require_command g++
  install_cmake_if_needed

  mkdir -p "$(dirname "$llama_src_dir")" "$HOME/.local/bin"

  if [ ! -d "$llama_src_dir/.git" ]; then
    git clone --depth 1 https://github.com/ggml-org/llama.cpp "$llama_src_dir"
  else
    git -C "$llama_src_dir" pull --ff-only
  fi

  if command -v nvcc >/dev/null 2>&1; then
    cmake_cuda_flag="-DGGML_CUDA=ON"
  else
    printf 'WARNING: nvcc not found; building CPU-only llama.cpp.\n' >&2
  fi

  cmake -S "$llama_src_dir" -B "$llama_src_dir/build" "$cmake_cuda_flag" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$llama_src_dir/build" --config Release -j "$(nproc)" --target llama-server llama-cli

  ln -sf "$llama_src_dir/build/bin/llama-server" "$HOME/.local/bin/llama-server"
  ln -sf "$llama_src_dir/build/bin/llama-cli" "$HOME/.local/bin/llama-cli"
}

download_model() {
  local target="$model_dir/$model_file"

  require_command curl
  mkdir -p "$model_dir"

  if [ -s "$target" ]; then
    printf 'Model already exists: %s\n' "$target"
    return
  fi

  curl -L --fail --continue-at - --speed-limit 1024 --speed-time 60 \
    --retry 10 --retry-delay 5 --output "$target" "$model_url"
}

while (($#)); do
  case "$1" in
    --model-dir)
      [ "$#" -ge 2 ] || { printf '%s\n' '--model-dir requires a path' >&2; exit 1; }
      model_dir="$2"
      shift 2
      ;;
    --llama-src-dir)
      [ "$#" -ge 2 ] || { printf '%s\n' '--llama-src-dir requires a path' >&2; exit 1; }
      llama_src_dir="$2"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    --skip-model)
      skip_model=1
      shift
      ;;
    --skip-codex-assets)
      skip_codex_assets=1
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

install_codex_assets

if [ "$skip_build" -eq 0 ]; then
  build_llama_cpp
fi

if [ "$skip_model" -eq 0 ]; then
  download_model
fi

printf '\nQwen3.6 local coding setup complete.\n\n'
printf 'Server wrapper: %s\n' "$HOME/.local/bin/qwen36-server"
printf 'Coding worker: %s\n' "$HOME/.local/bin/qwen36-code"
printf 'Model path: %s\n' "$model_dir/$model_file"
printf '\nStart manually:\n'
printf '  QWEN36_CTX=8192 qwen36-server\n'
printf '\nOne-shot coding draft:\n'
printf "  qwen36-code -f path/to/file 'Draft the smallest patch for ...'\n"
