# Code Review Checklist

Review diff against detected base. Cite file:line. Flag real problems only; skip anything addressed in the diff.

Per finding: severity (BLOCKER/WARNING/NIT) · confidence (high/medium/low) · file:line · summary · why · fix.
**BLOCKER proof required** — `why` must name a concrete proof shape: failing scenario, exploit path, or concrete input→failure. Cannot supply it → downgrade to WARNING.
No cap. No praise.

---

## Pass 1 — Critical

### SQL & Data Safety
- string interpolation in SQL
- non-atomic check-then-write
- validation-bypassing writes
- partial multi-step writes without transaction or compensation
- N+1 in obvious hot paths

### Race Conditions & Concurrency
- duplicate-create races
- stale-read state transitions
- retry-unsafe writes / double-submit
- missing idempotency where branch makes it relevant

### LLM / Tool Output Trust
- model/tool output used in DB, queries, paths, shell, or HTML without validation
- model/tool output accepted without type/shape checks
- model-generated URLs fetched without allowlist
- stored prompt injection via persisted model content

### Injection
- shell/subprocess with interpolated or untrusted values
- eval/exec of untrusted or model-produced code
- unsafe path construction → execution
- XSS: unsafe rendering of user-controlled HTML
- env vars passed to subprocess contain user-controlled values (`PATH`, env-dict poisoning)
- second-order injection: value stored safely but later interpolated into query/shell/template

### Enum / Status / Type Completeness
New enum/status/type/value → trace all consumers, validators, serializers, switch/case, UI/API callers. Read outside diff.

### Auth / Authorization
- missing auth middleware
- authz too late / ownership check missing
- route reachable by wrong actor
- token/session expiry or revocation ignored
- resource fetched by user-supplied ID without ownership check (IDOR)
- privilege-escalating fields (`role`, `isAdmin`, `userId`) accepted in request body

### Secrets & Defaults
- hardcoded credentials, tokens, or API keys in diff
- sensitive values logged, returned in error responses, or embedded in URLs
- config committed with environment-specific values (dev URLs, local credentials)
- new endpoint missing rate limiting or auth when similar existing endpoints have both
- verbose error detail (stack trace, SQL, internal paths) returned to caller

### Migration / Rollout Safety
- destructive schema change without compatibility phase
- code/schema gap during rolling deploy
- implied backfill missing
- lock-heavy operations on production

### Contract Drift
- response/request shape drift
- changed error/status semantics
- renamed/removed fields without compatibility
- docs/tests proving old contract

---

## Pass 2 — Actionable

### Async / Sync
- blocking sync I/O in async path
- CPU-heavy work in latency-sensitive request path

### Prompt / Tool Contract
- prompts describing unavailable tools
- duplicated limits/constraints likely to drift

### Completeness
- obvious partial implementation (happy path only)
- missing failure/cleanup path
- missing tests/docs/config implied by the change

### Type Coercion at Boundaries
- type drift across language/serialization boundaries
- numeric/string ambiguity causing key mismatch

### Frontend Efficiency
- O(n×m) lookups in render loops
- DB-filterable work done in memory

### CI / Release Surface
- changed release behavior without matching workflow
- artifact/version/path inconsistencies
