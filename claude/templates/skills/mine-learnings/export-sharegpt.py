#!/usr/bin/env python3
"""Export Claude Code session transcripts to ShareGPT format for fine-tuning.

ShareGPT format is the standard input format for most fine-tuning frameworks
(Axolotl, LLaMA-Factory, Unsloth, etc.):

    {
      "id": "session-id",
      "conversations": [
        {"from": "system", "value": "..."},      # optional
        {"from": "human", "value": "..."},
        {"from": "gpt",   "value": "..."},
        ...
      ]
    }

Tool uses and tool results are kept inline so the model learns the full
trajectory, not just the prose turns.

Usage:
    python3 export-sharegpt.py [options]

    # Export all sessions with at least 4 messages
    python3 export-sharegpt.py --out ~/.claude/learnings/sharegpt.jsonl

    # Only sessions from a specific project substring
    python3 export-sharegpt.py --project-filter SymanticSearch \\
        --out /tmp/symantic.jsonl

    # Only sessions that have learnings extracted (cross-reference JSONL)
    python3 export-sharegpt.py \\
        --only-mined ~/.claude/learnings/learnings.jsonl \\
        --out ~/.claude/learnings/sharegpt-mined.jsonl
"""

import argparse
import json
import sys
from pathlib import Path

CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"


def render_content(content):
    """Flatten Claude's content blocks into a single string preserving tool use structure."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        if btype == "text":
            parts.append(block.get("text", ""))
        elif btype == "tool_use":
            name = block.get("name", "")
            inp = block.get("input", {})
            try:
                inp_str = json.dumps(inp, indent=2)
            except Exception:
                inp_str = str(inp)
            parts.append(f"<tool_use name=\"{name}\">\n{inp_str}\n</tool_use>")
        elif btype == "tool_result":
            c = block.get("content", "")
            if isinstance(c, list):
                c = "\n".join(
                    b.get("text", "") for b in c if isinstance(b, dict) and b.get("type") == "text"
                )
            err = " error=true" if block.get("is_error") else ""
            parts.append(f"<tool_result{err}>\n{c}\n</tool_result>")
        elif btype == "thinking":
            # Keep thinking blocks — they're valuable training signal
            parts.append(f"<thinking>\n{block.get('thinking', '')}\n</thinking>")
    return "\n".join(p for p in parts if p).strip()


def parse_session(filepath):
    """Parse a session JSONL into a ShareGPT conversation."""
    conversations = []
    for line in filepath.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = entry.get("type")
        if msg_type not in ("user", "assistant"):
            continue
        msg = entry.get("message") or {}
        if not isinstance(msg, dict):
            continue
        rendered = render_content(msg.get("content", ""))
        if not rendered:
            continue
        role = "human" if msg_type == "user" else "gpt"
        conversations.append({"from": role, "value": rendered})

    if not conversations:
        return None

    project = filepath.parent.name
    if project.startswith("-"):
        project = project.replace("-", "/")

    return {
        "id": filepath.stem,
        "project": project,
        "source": "claude-code",
        "conversations": conversations,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--min-messages", type=int, default=4,
                        help="Minimum conversation turns to include (default: 4)")
    parser.add_argument("--project-filter", help="Only include sessions from projects matching this substring")
    parser.add_argument("--only-mined", help="Path to learnings.jsonl — only export sessions that have learnings mined")
    parser.add_argument("--max-sessions", type=int, default=0, help="Cap number of sessions (0 = no cap)")
    args = parser.parse_args()

    mined_ids = None
    if args.only_mined:
        mined_ids = set()
        p = Path(args.only_mined).expanduser()
        if p.exists():
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    mined_ids.add(json.loads(line).get("session_id", ""))
                except Exception:
                    continue

    if not CLAUDE_PROJECTS_DIR.exists():
        print(f"No projects dir at {CLAUDE_PROJECTS_DIR}", file=sys.stderr)
        sys.exit(1)

    session_files = [p for p in CLAUDE_PROJECTS_DIR.rglob("*.jsonl") if "subagents" not in str(p)]
    session_files.sort(key=lambda p: p.stat().st_mtime, reverse=True)

    out_path = Path(args.out).expanduser()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    written = skipped = 0
    with out_path.open("w", encoding="utf-8") as out:
        for sf in session_files:
            if mined_ids is not None and sf.stem not in mined_ids:
                skipped += 1
                continue
            if args.project_filter and args.project_filter not in str(sf):
                skipped += 1
                continue
            conv = parse_session(sf)
            if not conv or len(conv["conversations"]) < args.min_messages:
                skipped += 1
                continue
            out.write(json.dumps(conv, ensure_ascii=False) + "\n")
            written += 1
            if args.max_sessions and written >= args.max_sessions:
                break

    print(f"Wrote {written} sessions to {out_path} (skipped {skipped})", file=sys.stderr)


if __name__ == "__main__":
    main()
