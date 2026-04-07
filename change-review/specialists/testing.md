# Testing Specialist

Read `change-review/specialists/CONTRACT.md` first.

Focus on testing gaps introduced or exposed by this branch. No broad coverage expansion.

---

## What to review

### Missing unhappy-path tests
- new error/rejection/denial/validation paths with no test
- guard clauses / early returns with no failure-path test
- retry/failure branches with no test when behavior is explicit

### Local boundary gaps
Flag only when inside the changed path, clearly implied, small and direct. No broad coverage expansion.

### Stale tests
- tests still proving old behavior after refactor
- changed error handling / contract without test update

### Flaky / misleading tests
- timing-based sleeps / real network deps where stub expected
- order-dependent assertions on unordered data
- tests passing without exercising the risky branch

### Security / correctness tests
- auth/authz with no denied-case test
- sanitization/validation with no malicious-input test
- idempotency/concurrency changed but zero coverage

---

## Fix bias

One small unhappy-path test, one denied-case test, minimal stale-assertion update.
