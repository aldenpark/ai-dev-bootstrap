#!/usr/bin/env python3
"""Extract conversation transcripts from Claude Code session JSONL files.

Reads all session files, extracts user/assistant text exchanges,
and outputs structured JSON summaries for each session.

Usage:
    python3 extract-sessions.py [--processed-file PATH] [--min-messages N] [--project-filter SUBSTR]

Output: JSON array to stdout, one object per session with:
  - session_id, project_path, message_count, first_prompt, transcript
"""

import argparse
import json
import os
import sys
from pathlib import Path


CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"


def extract_text_from_content(content):
    """Pull plain text from message content (string or content blocks)."""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    parts.append(block.get("text", ""))
                elif block.get("type") == "tool_use":
                    name = block.get("name", "")
                    inp = block.get("input", {})
                    # Summarize tool use compactly
                    if name in ("Read", "Glob", "Grep"):
                        target = inp.get("file_path") or inp.get("pattern") or ""
                        parts.append(f"[Tool: {name} {target}]")
                    elif name == "Edit":
                        fp = inp.get("file_path", "")
                        parts.append(f"[Tool: Edit {fp}]")
                    elif name == "Write":
                        fp = inp.get("file_path", "")
                        parts.append(f"[Tool: Write {fp}]")
                    elif name == "Bash":
                        cmd = inp.get("command", "")[:120]
                        parts.append(f"[Tool: Bash `{cmd}`]")
                    else:
                        parts.append(f"[Tool: {name}]")
                elif block.get("type") == "tool_result":
                    # Skip tool results - they're verbose
                    if block.get("is_error"):
                        c = block.get("content", "")
                        if isinstance(c, str):
                            parts.append(f"[Error: {c[:150]}]")
        return "\n".join(parts).strip()
    return ""


def parse_session(filepath):
    """Parse a session JSONL file into a structured dict."""
    messages = []
    session_id = filepath.stem
    project_path = ""

    # Derive project path from parent dir name
    parent = filepath.parent.name
    if parent.startswith("-"):
        project_path = parent.replace("-", "/")

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
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

            msg = entry.get("message", {})
            if not isinstance(msg, dict):
                continue

            content = msg.get("content", "")
            text = extract_text_from_content(content)
            if not text:
                continue

            role = "user" if msg_type == "user" else "assistant"
            timestamp = entry.get("timestamp", "")

            messages.append({
                "role": role,
                "text": text[:2000],  # Cap individual message length
                "timestamp": timestamp,
            })

    if not messages:
        return None

    # Build a compact transcript
    transcript_parts = []
    for m in messages:
        prefix = "U" if m["role"] == "user" else "A"
        transcript_parts.append(f"[{prefix}]: {m['text']}")

    transcript = "\n\n".join(transcript_parts)

    # Cap total transcript size (target ~25k chars for Claude processing)
    if len(transcript) > 25000:
        transcript = transcript[:25000] + "\n\n[...truncated...]"

    first_prompt = ""
    for m in messages:
        if m["role"] == "user":
            first_prompt = m["text"][:300]
            break

    user_count = sum(1 for m in messages if m["role"] == "user")

    return {
        "session_id": session_id,
        "project_path": project_path,
        "message_count": len(messages),
        "user_message_count": user_count,
        "first_prompt": first_prompt,
        "transcript": transcript,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--processed-file", help="Path to file listing already-processed session IDs")
    parser.add_argument("--min-messages", type=int, default=4,
                        help="Minimum messages to include a session (default: 4)")
    parser.add_argument("--project-filter", help="Only include sessions from projects matching this substring")
    parser.add_argument("--max-sessions", type=int, default=50,
                        help="Max sessions to output (default: 50)")
    args = parser.parse_args()

    # Load already-processed IDs
    processed = set()
    if args.processed_file and os.path.exists(args.processed_file):
        with open(args.processed_file) as f:
            for line in f:
                processed.add(line.strip())

    # Find all session JSONL files
    session_files = []
    if CLAUDE_PROJECTS_DIR.exists():
        for jsonl in CLAUDE_PROJECTS_DIR.rglob("*.jsonl"):
            # Skip subagent files
            if "subagents" in str(jsonl):
                continue
            session_files.append(jsonl)

    # Sort by modification time (newest first)
    session_files.sort(key=lambda p: p.stat().st_mtime, reverse=True)

    results = []
    for sf in session_files:
        sid = sf.stem
        if sid in processed:
            continue

        if args.project_filter:
            if args.project_filter not in str(sf):
                continue

        session = parse_session(sf)
        if not session:
            continue
        if session["message_count"] < args.min_messages:
            continue

        results.append(session)
        if len(results) >= args.max_sessions:
            break

    json.dump(results, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
