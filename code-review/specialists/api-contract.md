# API Contract Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review the diff (`/tmp/code-review/diff.patch`) and surrounding request/response handling code. Focus on compatibility, caller breakage, contract drift, and documentation mismatch.

---

## What to review

### 1. Breaking contract changes
- removed or renamed response fields
- changed field type/nullability
- new required request params
- changed status codes or method/path
- changed auth requirements

### 2. Hidden compatibility drift
- serializer changes not reflected in docs/spec/tests
- frontend/backend mismatch on field shape
- optional field becoming effectively required
- enum/status exposed through API but not fully handled

### 3. Error response consistency
- new endpoint using different error envelope
- validation errors with wrong status
- internal errors leaked directly

### 4. Versioning and rollout
- breaking changes with no versioning/compatibility story
- old clients plausibly broken
- webhook/event payload changes without compatibility thought

### 5. Documentation drift
- spec/docs/examples now stale
- docs missing newly required behavior

### 6. Consumer completeness
Read outside the diff when needed: frontend callers, SDK/client usage, tests asserting old contract, serializers, allowlists for new enum/status values.

---

## Fix guidance bias

Prefer: preserve old field/path if cheap, add compatibility alias,
keep field optional where possible, align serializer + parser + docs/tests,
add explicit version boundary if truly breaking.