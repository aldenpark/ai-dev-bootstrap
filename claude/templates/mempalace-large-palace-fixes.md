# MemPalace Fixes

## Fix 0: MCP server fails with `MCP error -32000: Connection closed` in venv-heavy workspaces

**Problem:** The plugin's `.mcp.json` uses bare `python3`, which resolves to whatever is first on `$PATH`. In workspaces with an activated `.venv` (e.g., Poetry projects), `python3` points to the venv Python, which doesn't have `mempalace` installed. The MCP server immediately crashes with `ModuleNotFoundError: No module named 'mempalace'`, surfacing as a generic connection error.

**Diagnosis:**

```bash
# See which python3 the plugin is using:
which python3
# If it points to a .venv, that's the problem.

# Confirm mempalace is installed under system python:
/usr/bin/python3 -c "import mempalace; print(mempalace.__file__)"
```

**Fix:** Edit both plugin config files to use the absolute path to system Python:

```bash
# Find the files:
~/.claude/plugins/cache/mempalace/mempalace/<version>/.mcp.json
~/.claude/plugins/marketplaces/mempalace/.claude-plugin/.mcp.json

# In both, change:
#   "command": "python3"
# to:
#   "command": "/usr/bin/python3"
```

Then click **Reconnect** on the plugin in Claude Code (or restart).

**Caveat:** These are plugin-managed files — a plugin update may overwrite them. A more durable fix would be `pipx install mempalace` or `uv tool install mempalace` and pointing the command to that isolated venv's python.

---

## Fix 1–7: Large-Palace Patches (>30k drawers)

Patches for palaces with >30k drawers. Both are site-packages edits — overwritten on `pip install --upgrade`. Keep this file until upstream merges PR #803 or #851.

## How to find the files

```bash
python3 -c "import mempalace.miner; print(mempalace.miner.__file__)"
python3 -c "import mempalace.mcp_server; print(mempalace.mcp_server.__file__)"
```

---

## Fix 1: miner.py — `status()` SQLite variable limit

**Problem:** `mempalace status` (CLI) crashes with `chromadb.errors.InternalError: too many SQL variables`. The `status()` function fetches all metadata in a single ChromaDB query, exceeding SQLite's ~32,766 variable limit.

Ref: https://github.com/MemPalace/mempalace/issues/802

**Find this block in `miner.py`:**

```python
    # Count by wing and room
    total = col.count()
    r = col.get(limit=total, include=["metadatas"]) if total else {"metadatas": []}
    metas = r["metadatas"]
```

**Replace with:**

```python
    # Count by wing and room (paginated to avoid SQLite variable limit)
    total = col.count()
    metas = []
    if total:
        chunk = 5000
        offset = 0
        while offset < total:
            print(f"\r  Loading metadata… {offset}/{total}", end="", flush=True)
            r = col.get(limit=chunk, offset=offset, include=["metadatas"])
            metas.extend(r["metadatas"])
            offset += chunk
        print(f"\r  Loading metadata… {total}/{total}  ")
```

---

## Fix 2: mcp_server.py — MCP connection timeout on large palaces

**Problem:** The MCP server's `tool_status()`, `tool_list_wings()`, `tool_list_rooms()`, and `tool_get_taxonomy()` all call `_get_cached_metadata()` which fetches **every** metadata record in batches of 1000. At 376k drawers this takes ~282 seconds. Claude Code kills the connection long before that finishes, producing `MCP error -32000: Connection closed`.

**Root cause:** 376 sequential ChromaDB queries with 1000-batch pages, 5-second cache TTL, and all four tools duplicate the same full scan just to aggregate wing/room counts.

### Step 1: Patch `_fetch_all_metadata` batch size and add counts helpers

**Find this block:**

```python
def _fetch_all_metadata(col, where=None):
    """Paginate col.get() to avoid the 10K silent truncation limit."""
    total = col.count()
    all_meta = []
    offset = 0
    while offset < total:
        kwargs = {"include": ["metadatas"], "limit": 1000, "offset": offset}
        if where:
            kwargs["where"] = where
        batch = col.get(**kwargs)
        if not batch["metadatas"]:
            break
        all_meta.extend(batch["metadatas"])
        offset += len(batch["metadatas"])
    return all_meta


_metadata_cache = None
_metadata_cache_time = 0
_METADATA_CACHE_TTL = 5.0  # seconds
```

**Replace with:**

```python
def _fetch_all_metadata(col, where=None):
    """Paginate col.get() to avoid the 10K silent truncation limit."""
    total = col.count()
    all_meta = []
    offset = 0
    while offset < total:
        kwargs = {"include": ["metadatas"], "limit": 10000, "offset": offset}
        if where:
            kwargs["where"] = where
        batch = col.get(**kwargs)
        if not batch["metadatas"]:
            break
        all_meta.extend(batch["metadatas"])
        offset += len(batch["metadatas"])
    return all_meta


def _fetch_wing_room_counts(col):
    """Aggregate wing/room counts without loading full metadata into memory."""
    total = col.count()
    wing_counts = {}
    room_counts = {}
    taxonomy = {}
    offset = 0
    while offset < total:
        batch = col.get(include=["metadatas"], limit=10000, offset=offset)
        if not batch["metadatas"]:
            break
        for m in batch["metadatas"]:
            w = m.get("wing", "unknown")
            r = m.get("room", "unknown")
            wing_counts[w] = wing_counts.get(w, 0) + 1
            room_counts[r] = room_counts.get(r, 0) + 1
            if w not in taxonomy:
                taxonomy[w] = {}
            taxonomy[w][r] = taxonomy[w].get(r, 0) + 1
        offset += len(batch["metadatas"])
    return wing_counts, room_counts, taxonomy


_metadata_cache = None
_metadata_cache_time = 0
_counts_cache = None
_counts_cache_time = 0
_METADATA_CACHE_TTL = 5.0  # seconds
_COUNTS_CACHE_TTL = 120.0  # seconds — counts change slowly
```

### Step 2: Add `_get_cached_counts` after `_get_cached_metadata`

**Find this block (the end of `_get_cached_metadata`):**

```python
    result = _fetch_all_metadata(col, where=where)
    if where is None:
        _metadata_cache = result
        _metadata_cache_time = now
    return result
```

**Add immediately after it:**

```python


def _get_cached_counts(col):
    """Return cached wing/room/taxonomy counts (120s TTL)."""
    global _counts_cache, _counts_cache_time
    now = time.time()
    if _counts_cache is not None and (now - _counts_cache_time) < _COUNTS_CACHE_TTL:
        return _counts_cache
    result = _fetch_wing_room_counts(col)
    _counts_cache = result
    _counts_cache_time = now
    return result
```

### Step 3: Rewrite `tool_status()`

**Replace:**

```python
def tool_status():
    col = _get_collection()
    if not col:
        return _no_palace()
    count = col.count()
    wings = {}
    rooms = {}
    result = {
        "total_drawers": count,
        "wings": wings,
        "rooms": rooms,
        "palace_path": _config.palace_path,
        "protocol": PALACE_PROTOCOL,
        "aaak_dialect": AAAK_SPEC,
    }
    try:
        all_meta = _get_cached_metadata(col)
        for m in all_meta:
            w = m.get("wing", "unknown")
            r = m.get("room", "unknown")
            wings[w] = wings.get(w, 0) + 1
            rooms[r] = rooms.get(r, 0) + 1
    except Exception as e:
        logger.exception("tool_status metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

**With:**

```python
def tool_status():
    col = _get_collection()
    if not col:
        return _no_palace()
    count = col.count()
    result = {
        "total_drawers": count,
        "wings": {},
        "rooms": {},
        "palace_path": _config.palace_path,
        "protocol": PALACE_PROTOCOL,
        "aaak_dialect": AAAK_SPEC,
    }
    try:
        wing_counts, room_counts, _ = _get_cached_counts(col)
        result["wings"] = wing_counts
        result["rooms"] = room_counts
    except Exception as e:
        logger.exception("tool_status metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

### Step 4: Rewrite `tool_list_wings()`

**Replace:**

```python
def tool_list_wings():
    col = _get_collection()
    if not col:
        return _no_palace()
    wings = {}
    result = {"wings": wings}
    try:
        all_meta = _get_cached_metadata(col)
        for m in all_meta:
            w = m.get("wing", "unknown")
            wings[w] = wings.get(w, 0) + 1
    except Exception as e:
        logger.exception("tool_list_wings metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

**With:**

```python
def tool_list_wings():
    col = _get_collection()
    if not col:
        return _no_palace()
    result = {"wings": {}}
    try:
        wing_counts, _, _ = _get_cached_counts(col)
        result["wings"] = wing_counts
    except Exception as e:
        logger.exception("tool_list_wings metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

### Step 5: Rewrite `tool_list_rooms()`

**Replace:**

```python
def tool_list_rooms(wing: str = None):
    try:
        wing = _sanitize_optional_name(wing, "wing")
    except ValueError as e:
        return {"error": str(e)}
    col = _get_collection()
    if not col:
        return _no_palace()
    rooms = {}
    result = {"wing": wing or "all", "rooms": rooms}
    try:
        where = {"wing": wing} if wing else None
        all_meta = _fetch_all_metadata(col, where=where)
        for m in all_meta:
            r = m.get("room", "unknown")
            rooms[r] = rooms.get(r, 0) + 1
    except Exception as e:
        logger.exception("tool_list_rooms metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

**With:**

```python
def tool_list_rooms(wing: str = None):
    try:
        wing = _sanitize_optional_name(wing, "wing")
    except ValueError as e:
        return {"error": str(e)}
    col = _get_collection()
    if not col:
        return _no_palace()
    result = {"wing": wing or "all", "rooms": {}}
    try:
        if wing:
            _, _, taxonomy = _get_cached_counts(col)
            result["rooms"] = taxonomy.get(wing, {})
        else:
            _, room_counts, _ = _get_cached_counts(col)
            result["rooms"] = room_counts
    except Exception as e:
        logger.exception("tool_list_rooms metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
    return result
```

### Step 6: Rewrite `tool_get_taxonomy()`

**Replace:**

```python
def tool_get_taxonomy():
    col = _get_collection()
    if not col:
        return _no_palace()
    taxonomy = {}
    result = {"taxonomy": taxonomy}
    try:
        all_meta = _get_cached_metadata(col)
        for m in all_meta:
            w = m.get("wing", "unknown")
            r = m.get("room", "unknown")
            if w not in taxonomy:
                taxonomy[w] = {}
            taxonomy[w][r] = taxonomy[w].get(r, 0) + 1
    except Exception as e:
        logger.exception("tool_get_taxonomy metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
```

**With:**

```python
def tool_get_taxonomy():
    col = _get_collection()
    if not col:
        return _no_palace()
    result = {"taxonomy": {}}
    try:
        _, _, taxonomy = _get_cached_counts(col)
        result["taxonomy"] = taxonomy
    except Exception as e:
        logger.exception("tool_get_taxonomy metadata fetch failed")
        result["error"] = str(e)
        result["partial"] = True
```

### Step 7: Invalidate counts cache on reconnect

**In `tool_reconnect()`, find:**

```python
    global _collection_cache, _palace_db_inode, _palace_db_mtime
    _collection_cache = None
    _palace_db_inode = 0
    _palace_db_mtime = 0.0
```

**Replace with:**

```python
    global _collection_cache, _palace_db_inode, _palace_db_mtime, _metadata_cache, _counts_cache
    _collection_cache = None
    _palace_db_inode = 0
    _palace_db_mtime = 0.0
    _metadata_cache = None
    _counts_cache = None
```

---

## Also patch: closet_llm.py

**Find:**

```python
    all_data = drawers_col.get(limit=total, include=["documents", "metadatas"])
    by_source = {}
    for doc_id, doc, meta in zip(all_data["ids"], all_data["documents"], all_data["metadatas"]):
```

**Replace with:**

```python
    # Paginate to avoid SQLite variable limit on large palaces
    all_ids, all_docs, all_metas = [], [], []
    chunk = 5000
    offset = 0
    while offset < total:
        batch = drawers_col.get(limit=chunk, offset=offset, include=["documents", "metadatas"])
        all_ids.extend(batch["ids"])
        all_docs.extend(batch["documents"])
        all_metas.extend(batch["metadatas"])
        offset += chunk
    by_source = {}
    for doc_id, doc, meta in zip(all_ids, all_docs, all_metas):
```
