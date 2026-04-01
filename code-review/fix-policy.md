# Fix Policy

## AUTO-FIX — apply directly when the fix is:
- local, mechanical, low ambiguity, low blast radius, easily verifiable
- does not require product/domain judgment

Examples: dead code, unused imports, stale comments, simple guards, missing null/type checks,
obvious enum propagation, missing eager loading, repeated lookup → indexed map, missing local
validation, docs updated to match code changed in this branch.

---

## MANUAL — do not fix blindly when:
- behavior intent is unclear
- auth/authz semantics are unclear
- migration sequencing matters
- concurrency fix could change business logic
- architecture decision required
- change would be broad or change user-visible behavior

Report clearly instead.

---

## REPORT-ONLY — use when:
- issue is real but fix is non-trivial
- safe implementation needs broader follow-up
- fix belongs in a dedicated branch

---

## Rules for applying fixes
- keep fixes scoped to review findings
- avoid opportunistic cleanup
- rerun focused validation after changes
- do not commit or push
- if a fix grows broader than expected, downgrade to MANUAL

---

## Test auto-fix guardrails

Small test additions allowed only when ALL are true:
- missing test covers an actually untested unhappy path
- that unhappy path is inside the changed boundary
- expected behavior is clear from production code
- test is small, local, non-speculative
- test does not expand scope into broader hardening

Do NOT add tests for: speculative edge cases, broad hardening, deep matrix coverage,
architecture-level concerns, ambiguous behavior.