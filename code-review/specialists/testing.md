# Testing Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review the diff and nearby tests. Focus on real testing gaps introduced or exposed by this branch.
Do not ask for broad hardening. Do not create test creep.

---

## What to review

### 1. Missing unhappy-path tests
- newly introduced error or rejection paths with no test
- guard clauses and early returns with no failure-path test
- denied/unauthorized paths with no test
- validation failures with no test
- retry/failure branches with no test when behavior is explicit and local

### 2. Local boundary gaps only
Only flag when the gap is inside the changed path, clearly implied by production code,
small and direct to test, and not speculative.

Do NOT ask for: wide test matrices, deep combinatorial coverage,
architecture-level hardening, broad resilience suites.

### 3. Stale tests after behavior change
- tests still proving old behavior only
- renamed/refactored paths with stale assertions
- changed error handling with no matching assertion update
- contract changes without test updates

### 4. Flaky or misleading test patterns
- timing-based sleeps or fragile waits
- real network/time dependencies where local stub is expected
- order-dependent assertions on unordered data
- tests that pass without exercising the actual risky branch

### 5. Security and correctness enforcement tests
- auth/authz logic with no denied-case test
- sanitization/validation logic with no malicious/invalid input test
- idempotency/concurrency-sensitive path with zero coverage when branch clearly changed it

---

## Fix guidance bias

Prefer: one small unhappy-path test, one denied-case test,
one validation-failure test, minimal update to stale assertion.
Do not recommend broad coverage expansion.