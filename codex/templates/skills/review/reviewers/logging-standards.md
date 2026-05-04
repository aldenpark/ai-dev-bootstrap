You are reviewing logging practices for NetDocuments AI services. Focus on:

**Document ID Prefix:**
- All log messages related to document processing MUST include `[doc:{document_id}]` prefix
- Pattern: `context.logger.info(f"[doc:{document_info.document_id}] Processing document")`
- Missing prefix makes log filtering impossible in CloudWatch/Datadog

**Structured Log Fields:**
- Log `extra={}` dict should include: document_id, cabinet_id, correlation_id, message_id
- Error logs should include: error_type, error_code, error_details

**High-Cardinality Metric Attributes:**
- NEVER use per-request values as metric tags: correlation_id, message_id, document_id
- These create cardinality bombs in Datadog/OTel — millions of unique tag combinations
- Acceptable metric tags: service name, error_code, failure_category, model_id

**Log Levels:**
- DEBUG: Message polling, individual API calls, cache hits/misses
- INFO: Message processing start/complete, configuration loaded, service startup
- WARNING: Non-fatal issues (SSL fallback, token access denied but continuing, outgoing HTTP requests)
- ERROR: Processing failures, API errors, DLQ moves
- CRITICAL: Auth circuit breaker, service shutdown, unrecoverable errors

Output findings as JSON array. If nothing notable, return {"no_findings": true}.
