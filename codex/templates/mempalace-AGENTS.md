# MemPalace Cloud Memory Protocol

If `mempalace-cloud` is configured, use its `mempalace_*` tools as the
cross-session memory system.

## Recall First

Before answering about a person, project, past decision, or prior event, check
MemPalace first. Start with `mempalace_list_wings`, then use
`mempalace_search` or `mempalace_kg_query` to pull the relevant memory.

If MemPalace has nothing useful, say that directly. Do not invent memory.

## Save After Important Work

After a significant debugging session, design decision, or reusable lesson,
save it to MemPalace with the smallest fitting tool:

- `mempalace_kg_add` for atomic facts or durable preferences
- `mempalace_diary_write` for dated events and outcomes
- `mempalace_add_drawer` for larger chunks worth retrieving later

Use concise, reusable facts rather than transcript dumps. The user reviews
captures in MemPalace later.

## Connection Check

If you are unsure the memory system is connected, call `mempalace_status`.

Codex does not auto-save MemPalace memories. Save them explicitly when the
work is important enough to remember later.
