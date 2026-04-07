# Fix Policy

**Guardrail: Do not modify any source file during review.** The review system identifies and recommends fixes — it does not apply them.

---

## RECOMMEND-FIX — when the fix is:
- local, mechanical, low ambiguity, low blast radius, easily verifiable
- does not require product/domain judgment

Examples: dead code, unused imports, stale comments, simple guards, missing null/type checks,
obvious enum propagation, missing eager loading, repeated lookup → indexed map, missing local
validation, docs updated to match code changed in this branch.

Include a specific recommended change and expected validation (test/lint/typecheck to run).

---

## ESCALATE — when:
- behavior intent is unclear
- auth/authz semantics are unclear
- migration sequencing matters
- concurrency fix could change business logic
- architecture decision required
- change would be broad or alter user-visible behavior

Report clearly with enough context for the developer to resolve.

---

## DEFER — when:
- issue is real but fix is non-trivial
- safe implementation needs broader follow-up
- fix belongs in a dedicated branch or ticket

---

## Classification rules
- keep recommendations scoped to review findings
- avoid opportunistic cleanup
- if a fix is broader than expected, downgrade to ESCALATE
- do not commit, push, or modify files
