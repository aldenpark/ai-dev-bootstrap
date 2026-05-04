#!/usr/bin/env python3
"""Extract recent Codex sessions that are likely to contain durable learnings."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    home = Path.home()
    return argparse.ArgumentParser().parse_args()


def build_parser() -> argparse.ArgumentParser:
    home = Path.home()
    parser = argparse.ArgumentParser(
        description="Extract unprocessed Codex archived sessions worth mining."
    )
    parser.add_argument(
        "--archived-dir",
        default=home / ".codex" / "archived_sessions",
        type=Path,
        help="Directory containing archived Codex session JSONL files.",
    )
    parser.add_argument(
        "--processed-file",
        default=home / ".codex" / "learnings" / ".processed-sessions",
        type=Path,
        help="File containing processed session IDs, one per line.",
    )
    parser.add_argument(
        "--max-sessions",
        default=20,
        type=int,
        help="Maximum number of sessions to emit.",
    )
    parser.add_argument(
        "--min-user-turns",
        default=4,
        type=int,
        help="Minimum number of user turns required.",
    )
    parser.add_argument(
        "--min-tool-calls",
        default=3,
        type=int,
        help="Minimum number of tool calls required.",
    )
    parser.add_argument(
        "--max-characters",
        default=12000,
        type=int,
        help="Maximum transcript characters to emit per session.",
    )
    return parser


def load_processed_sessions(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return {
        line.strip()
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip()
    }


def extract_text_blocks(content: Any) -> list[str]:
    texts: list[str] = []
    if not isinstance(content, list):
        return texts
    for item in content:
        if not isinstance(item, dict):
            continue
        text = item.get("text")
        if isinstance(text, str) and text.strip():
            texts.append(text.strip())
    return texts


def shorten(text: str, limit: int) -> str:
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[: limit - 3].rstrip() + "..."


def parse_session(path: Path, max_characters: int) -> dict[str, Any] | None:
    session_id = ""
    timestamp = ""
    cwd = ""
    user_turns = 0
    tool_calls = 0
    transcript_lines: list[str] = []

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            try:
                event = json.loads(raw_line)
            except json.JSONDecodeError:
                continue

            event_type = event.get("type")
            payload = event.get("payload") or {}

            if event_type == "session_meta" and isinstance(payload, dict):
                session_id = payload.get("id", session_id)
                timestamp = payload.get("timestamp", timestamp)
                cwd = payload.get("cwd", cwd)
                continue

            if event_type != "response_item" or not isinstance(payload, dict):
                continue

            payload_type = payload.get("type")

            if payload_type == "message":
                role = payload.get("role")
                text = "\n".join(extract_text_blocks(payload.get("content")))
                if not text:
                    continue
                if role == "user":
                    user_turns += 1
                    transcript_lines.append(f"User: {text}")
                elif role == "assistant":
                    transcript_lines.append(f"Assistant: {text}")
            elif payload_type == "function_call":
                tool_calls += 1
                name = payload.get("name", "unknown")
                arguments = payload.get("arguments", "")
                transcript_lines.append(
                    f"Tool call [{name}]: {shorten(str(arguments), 240)}"
                )
            elif payload_type == "function_call_output":
                output = payload.get("output", "")
                transcript_lines.append(
                    f"Tool output: {shorten(str(output), 300)}"
                )

    if not session_id:
        session_id = path.stem

    transcript = "\n".join(transcript_lines)
    if len(transcript) > max_characters:
        transcript = transcript[: max_characters - 3].rstrip() + "..."

    return {
        "session_id": session_id,
        "timestamp": timestamp,
        "cwd": cwd,
        "source_file": str(path),
        "user_turns": user_turns,
        "tool_calls": tool_calls,
        "transcript": transcript,
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    archived_dir: Path = args.archived_dir
    processed = load_processed_sessions(args.processed_file)

    if not archived_dir.exists():
        print("[]")
        return 0

    sessions: list[dict[str, Any]] = []
    paths = sorted(archived_dir.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)

    for path in paths:
        parsed = parse_session(path, args.max_characters)
        if not parsed:
            continue
        if parsed["session_id"] in processed:
            continue
        if parsed["user_turns"] < args.min_user_turns:
            continue
        if parsed["tool_calls"] < args.min_tool_calls:
            continue
        if not parsed["transcript"].strip():
            continue

        sessions.append(parsed)
        if len(sessions) >= args.max_sessions:
            break

    print(json.dumps(sessions, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
