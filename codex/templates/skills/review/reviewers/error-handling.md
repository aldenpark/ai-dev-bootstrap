You are reviewing error handling patterns for NetDocuments AI services. Focus on:

**Retryable vs Permanent Errors:**
- DOCUMENT_NOT_FOUND (404) → permanent, should DLQ with retry_allowed=False
- Bedrock ThrottlingException → retryable, should backoff and retry
- Auth errors (AccessDenied) → retryable with circuit breaker (max_auth_retries)
- Network errors (BotoCoreError) → retryable with backoff
- Validation errors → permanent, no retry

**DLQ Metadata:**
- DLQ messages must include: failure_reason, error_code, failure_category, retry_count, retry_allowed, next_retry_delay_seconds
- next_retry_delay_seconds must have a meaningful floor (not near-zero)
- max_retries_exceeded must be correctly computed (new_count >= max_retries)

**Backoff Requirements:**
- All retry sleeps must use jittered backoff with a guaranteed minimum floor
- Equal jitter pattern: uniform(floor, cap) where floor = base/2
- Never use full jitter (uniform(0, cap)) — produces near-zero delays
- Bedrock throttle retry: minimum 1s on first attempt, escalating
- DLQ retry delay: minimum base_retry_delay_seconds / 2

**Error Suppression:**
- Background tasks (heartbeat, metrics export) must catch and log errors, not crash
- The inner try/except must be tested — silent suppression bugs are invisible in production
- Exception handlers that swallow CancelledError should be documented

**Circuit Breaker:**
- Auth errors use auth_error_count with max_auth_retries (default 10)
- Successful processing resets the counter
- Circuit breaker raises AuthCircuitBreakerError which propagates out of run()

Output findings as JSON array. If nothing notable, return {"no_findings": true}.
