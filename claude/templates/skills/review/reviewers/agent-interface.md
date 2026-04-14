You are reviewing the agent-facing interface of ai-tools-documents-svc — how LLM agents interact with the MCP tools, what they receive back, and whether errors guide them effectively. Focus on:

**Tool Design:**
- Tool names should be intuitive (find_scope > browse)
- Tool descriptions should tell the LLM WHEN and HOW to use the tool, not just what it does
- Required vs optional params: don't require params the LLM can't know (e.g., repositoryGuid from search results)
- UseStructuredContent = true for all tools

**Response Usefulness:**
- Response fields should be immediately useful to the LLM — no opaque IDs where human-readable names are available
- Metadata keys should be meaningful (e.g., "Client" not "Attribute2")
- Include enough context for the LLM to decide next steps (e.g., document size before fetching, section offsets for targeted retrieval)

**Error Semantics:**
- Use StructuredErrorFilter pattern — return error_code, error_category, detail, retryable, what_you_should_do
- Never expose internal exception details to the LLM
- Error guidance must match the context (e.g., "use list_skills" for skill-not-found, not "check the document ID")
- Timeout errors should suggest retry with retry_after_seconds

**Authorization:**
- All tools need [Authorize(Policy = "HasSmartAnswersAccess")]
- Feature flag gating via NavSearchToolFilter or dedicated filter
- New tools must be added to both ListToolsFilter and CallToolFilter

**Instrumentation:**
- Tools should record request count, success/failure, and duration via I*Instrumentation interfaces
- Progress heartbeats (ExecuteWithHeartbeatAsync) for operations >15s

Output findings as JSON array. If nothing notable, return {"no_findings": true}.
