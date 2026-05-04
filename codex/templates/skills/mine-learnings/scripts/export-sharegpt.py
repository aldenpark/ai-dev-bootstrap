#!/usr/bin/env python3
"""Export Codex archived sessions to a ShareGPT-like JSONL format."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def build_parser() -> argparse.ArgumentParser:
    home = Path.home()
    parser = argparse.ArgumentParser(
        description="Export Codex archived sessions into ShareGPT-style JSONL."
    )
    parser.add_argument(
        "--archived-dir",
        default=home / ".codex" / "archived_sessions",
        type=Path,
        help="Directory containing archived Codex session JSONL files.",
    )
    parser.add_argument(
        "--only-mined",
        type=Path,
        help="Optional learnings.jsonl file. If provided, only export sessions referenced there.",
    )
    parser.add_argument(
        "--project-filter",
        help="Only export sessions whose cwd contains this substring.",
    )
    parser.add_argument(
        "--out",
        required=True,
        type=Path,
        help="Output JSONL path.",
    )
    return parser


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


def load_allowed_sessions(path: Path | None) -> set[str] | None:
    if path is None:
        return None
    allowed: set[str] = set()
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            try:
                record = json.loads(raw_line)
            except json.JSONDecodeError:
                continue
            session_id = record.get("session_id")
            if isinstance(session_id, str) and session_id:
                allowed.add(session_id)
    return allowed


def parse_session(path: Path) -> dict[str, Any] | None:
    session_id = ""
    timestamp = ""
    cwd = ""
    conversations: list[dict[str, str]] = []

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
                    conversations.append({"from": "human", "value": text})
                elif role == "assistant":
                    conversations.append({"from": "gpt", "value": text})
            elif payload_type == "function_call":
                name = payload.get("name", "unknown")
                arguments = payload.get("arguments", "")
                conversations.append(
                    {
                        "from": "gpt",
                        "value": f"<tool_call name=\"{name}\">\n{arguments}\n</tool_call>",
                    }
                )
            elif payload_type == "function_call_output":
                output = str(payload.get("output", "")).strip()
                if output:
                    conversations.append(
                        {"from": "gpt", "value": f"<tool_output>\n{output}\n</tool_output>"}
                    )

    if not session_id or not conversations:
        return None

    return {
        "id": session_id,
        "timestamp": timestamp,
        "cwd": cwd,
        "conversations": conversations,
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    archived_dir: Path = args.archived_dir
    allowed_sessions = load_allowed_sessions(args.only_mined)

    args.out.parent.mkdir(parents=True, exist_ok=True)

    if not archived_dir.exists():
        args.out.write_text("", encoding="utf-8")
        return 0

    records: list[dict[str, Any]] = []
    for path in sorted(archived_dir.glob("*.jsonl")):
        record = parse_session(path)
        if not record:
            continue
        if allowed_sessions is not None and record["id"] not in allowed_sessions:
            continue
        if args.project_filter and args.project_filter not in record.get("cwd", ""):
            continue
        records.append(record)

    with args.out.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record) + "\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
