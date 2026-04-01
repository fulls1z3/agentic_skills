# Code Review Checklist

Review the branch diff against the detected base branch.
Be specific. Cite file:line where possible.
Only flag real problems. Skip anything already addressed in the diff.

For every finding:
- severity: BLOCKER / WARNING / NIT
- confidence: high / medium / low
- file:line
- summary, why it matters, recommended fix

Do not cap findings. Do not praise. Do not hide uncertainty behind confident wording.

---

## Pass 1 — Critical

### SQL & Data Safety
- string interpolation in SQL
- non-atomic check-then-write flows
- validation-bypassing writes
- partial multi-step writes with no transaction or compensation path
- N+1 queries in obvious hot paths

### Race Conditions & Concurrency
- duplicate-create races
- stale-read state transitions
- retry-unsafe write flows
- double-submit hazards
- missing idempotency where branch makes it relevant
- unsafe rendering of user-controlled HTML

### LLM / Tool Output Trust Boundary
- model/tool output written to DB without validation
- structured model/tool output accepted without type/shape checks
- model-generated URLs fetched without allowlist/blocklist
- model/tool output used in shell/path/HTML/query contexts unsafely
- stored prompt injection risk via persisted model content

### Shell / Command Injection
- shell execution with interpolated values
- os.system/subprocess misuse
- eval/exec of untrusted or model-produced code
- unsafe path construction flowing into execution

### Enum / Status / Type Completeness
When diff introduces a new enum/status/type/value:
- trace all consumers, validators, serializers, allowlists, switch/case branches, UI/API callers
Requires reading outside the diff.

### Auth / Authorization
- missing auth middleware
- authz too late in flow
- ownership checks missing
- route/handler reachable by wrong actor
- token/session expiry or revocation ignored

### Migration / Rollout Safety
- destructive schema changes without compatibility phase
- code/schema incompatibility during rolling deploy
- backfill implied but missing
- lock-heavy operations likely to hurt production

### Contract Drift
- response/request shape drift
- changed error/status semantics
- renamed/removed fields without compatibility story
- docs/tests/specs still proving old contract

---

## Pass 2 — Actionable

### Async / Sync Mixing
- blocking sync I/O in async path
- blocking sleep in async code
- CPU-heavy work in latency-sensitive request path

### Field / Schema Name Safety
- wrong field names in ORM/query code
- stale selected-field usage
- mismatch between code and current schema assumptions

### Prompt / Tooling Contract Issues
- prompts describing tools not actually available
- mismatched indexing assumptions
- duplicated limits/constraints likely to drift

### Completeness Gaps
- obvious 80% implementation
- happy path only
- missing failure/cleanup path
- missing supporting docs/config/tests directly implied by the change

### Time Window Safety
- misleading daily/hourly window assumptions
- related features using incompatible windows for same concept

### Type Coercion at Boundaries
- type drift across language/serialization boundaries
- hashing/digest inputs not normalized before serialization
- numeric/string ambiguity causing key mismatch

### View / Frontend Efficiency
- inline styles in hot render paths
- O(n*m) lookups in render/view loops
- DB-filterable work done in memory without good reason

### CI / Distribution / Release Surface
- changed release behavior without matching workflow changes
- artifact/version/path inconsistencies
- missing idempotency or target coverage in publish flow