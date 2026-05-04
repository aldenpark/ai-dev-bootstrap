#!/usr/bin/env python3
"""Stop hook that drafts reusable Codex skills from qualifying archived sessions."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


MIN_USER_TURNS = int(os.environ.get("AUTO_SKILL_MIN_USER_TURNS", "6"))
MIN_TOOL_CALLS = int(os.environ.get("AUTO_SKILL_MIN_TOOL_CALLS", "8"))
AUTO_SKILL_MODEL = os.environ.get("AUTO_SKILL_MODEL", "gpt-5.4-mini")
AUTO_SKILL_SYNC = os.environ.get("AUTO_SKILL_DRAFT_SYNC", "0") == "1"
CODEX_HOME = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
CODEX_BIN = os.environ.get("AUTO_SKILL_DRAFT_CODEX_BIN", "codex")
DRAFTS_DIR = Path(
    os.environ.get("AUTO_SKILL_DRAFTS_DIR", str(CODEX_HOME / "learnings" / "skill-drafts"))
)
REJECTED_LOG = DRAFTS_DIR / ".rejected.log"
CANDIDATES_FILE = CODEX_HOME / "learnings" / "skill-draft-candidates.jsonl"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--background", action="store_true")
    parser.add_argument("--transcript", type=Path)
    parser.add_argument("--session-id")
    parser.add_argument("--cwd")
    parser.add_argument("--draft-path", type=Path)
    parser.add_argument("--model", default=AUTO_SKILL_MODEL)
    return parser


def emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload))
    return 0


def extract_text_blocks(content: Any) -> list[str]:
    texts: list[str] = []
    if not isinstance(content, list):
        return texts
    for item in content:
        if not isinstance(item, dict):
            continue
        text = item.get("text")
        if isinstance(text, str) and text.strip():
            texts.append(" ".join(text.split()))
    return texts


def slugify(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = value.strip("-")
    return value or "skill-draft"


def summarize_transcript(path: Path) -> tuple[int, int, list[str], list[str]]:
    user_turns = 0
    tool_calls = 0
    user_messages: list[str] = []
    tool_names: list[str] = []

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            raw_line = raw_line.strip()
            if not raw_line:
                continue
            try:
                event = json.loads(raw_line)
            except json.JSONDecodeError:
                continue

            if event.get("type") != "response_item":
                continue

            payload = event.get("payload") or {}
            if not isinstance(payload, dict):
                continue

            payload_type = payload.get("type")
            if payload_type == "message" and payload.get("role") == "user":
                texts = extract_text_blocks(payload.get("content"))
                if texts:
                    user_turns += 1
                    user_messages.extend(texts)
            elif payload_type == "function_call":
                tool_calls += 1
                name = payload.get("name")
                if isinstance(name, str) and name:
                    tool_names.append(name)

    return user_turns, tool_calls, user_messages, tool_names


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload) + "\n")


def append_rejection(session_id: str, reason: str) -> None:
    DRAFTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M%S")
    with REJECTED_LOG.open("a", encoding="utf-8") as handle:
        handle.write(f"{timestamp}\t{session_id}\t{reason.strip()}\n")


def build_prompt(transcript_path: Path, session_id: str) -> str:
    return f"""You are analyzing a Codex session transcript to decide if the workflow is worth preserving as a reusable skill.

Read the transcript at {transcript_path}. Apply these tests:
1. Did the session establish a repeatable procedure instead of a one-off fix?
2. Did it involve non-obvious steps, knowledge, or gotchas that would save future-you time?
3. Does it generalize beyond this single task?

If ANY answer is no, output exactly:
NOT_WORTH_DRAFTING
and one short reason on the next line.

If all answers are yes, output a valid `SKILL.md` draft in this format:

---
name: suggested-name
description: One line under 120 chars explaining when to use this skill.
---

# Skill Title

## When to use
- Specific triggers

## Process
1. ...
2. ...
3. ...

## Gotchas
- Non-obvious things the session surfaced

Source session: {session_id}

Output ONLY the skill markdown or the NOT_WORTH_DRAFTING result. No preamble."""


def run_codex_draft(
    transcript_path: Path, session_id: str, cwd: str, draft_path: Path, model: str
) -> int:
    prompt = build_prompt(transcript_path, session_id)
    output_path = draft_path.with_suffix(".tmp")

    command = [
        CODEX_BIN,
        "--disable",
        "codex_hooks",
        "-m",
        model,
        "exec",
        "--ephemeral",
        "--skip-git-repo-check",
        "-C",
        str(Path.home()),
        "-o",
        str(output_path),
        prompt,
    ]

    result = subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    if result.returncode != 0 or not output_path.exists():
        return 1

    output = output_path.read_text(encoding="utf-8", errors="replace").strip()
    output_path.unlink(missing_ok=True)
    if not output:
        return 1

    if output.splitlines()[0].strip() == "NOT_WORTH_DRAFTING":
        reason = output.splitlines()[1].strip() if len(output.splitlines()) > 1 else "not provided"
        append_rejection(session_id, reason)
        return 0

    draft_path.parent.mkdir(parents=True, exist_ok=True)
    draft_path.write_text(output.rstrip() + "\n", encoding="utf-8")

    append_jsonl(
        CANDIDATES_FILE,
        {
            "session_id": session_id,
            "cwd": cwd,
            "transcript_path": str(transcript_path),
            "draft_path": str(draft_path),
            "created_at": datetime.now(timezone.utc).isoformat(),
            "source": "auto-skill-draft-hook",
        },
    )
    return 0


def queue_draft_job(
    transcript_path: Path, session_id: str, cwd: str, draft_path: Path, model: str
) -> None:
    args = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--background",
        "--transcript",
        str(transcript_path),
        "--session-id",
        session_id,
        "--cwd",
        cwd,
        "--draft-path",
        str(draft_path),
        "--model",
        model,
    ]

    if AUTO_SKILL_SYNC:
        subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        return

    subprocess.Popen(
        args,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def handle_background(args: argparse.Namespace) -> int:
    if not args.transcript or not args.draft_path:
        return 1
    return run_codex_draft(
        transcript_path=args.transcript,
        session_id=args.session_id or args.transcript.stem,
        cwd=args.cwd or "",
        draft_path=args.draft_path,
        model=args.model,
    )


def main() -> int:
    args = build_parser().parse_args()
    if args.background:
        return handle_background(args)

    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        return emit({"continue": True})

    if hook_input.get("stop_hook_active") is True:
        return emit({"continue": True})

    transcript_path = hook_input.get("transcript_path")
    session_id = hook_input.get("session_id", "")
    cwd = hook_input.get("cwd", "")

    if not transcript_path:
        return emit({"continue": True})

    path = Path(transcript_path)
    if not path.exists():
        return emit({"continue": True})

    DRAFTS_DIR.mkdir(parents=True, exist_ok=True)
    CANDIDATES_FILE.parent.mkdir(parents=True, exist_ok=True)

    if (DRAFTS_DIR / ".disabled").exists():
        return emit({"continue": True})

    user_turns, tool_calls, user_messages, tool_names = summarize_transcript(path)
    if user_turns < MIN_USER_TURNS or tool_calls < MIN_TOOL_CALLS:
        return emit({"continue": True})

    session_suffix = session_id or path.stem
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d-%H%M%S")
    description_seed = user_messages[0] if user_messages else f"Session from {cwd or path.parent}"
    draft_path = DRAFTS_DIR / f"{timestamp}-{slugify(description_seed)[:48]}-{session_suffix}.md"

    if any(candidate.name.endswith(f"-{session_suffix}.md") for candidate in DRAFTS_DIR.glob(f"*-{session_suffix}.md")):
        return emit({"continue": True})

    top_tools = [name for name, _ in Counter(tool_names).most_common(5)]
    queue_draft_job(path, session_suffix, cwd, draft_path, AUTO_SKILL_MODEL)

    return emit(
        {
            "continue": True,
            "systemMessage": (
                f"Queued Codex skill-draft pass for {session_suffix}"
                + (f" using {', '.join(top_tools)}" if top_tools else "")
            ),
        }
    )


if __name__ == "__main__":
    raise SystemExit(main())
