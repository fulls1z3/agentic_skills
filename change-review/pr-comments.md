# PR Comment and Review Reply Policy

This skill inspects and responds to PR review comments when a PR exists and comments exist.

Goal: treat reviewer comments as additional review input, surface valid ones as findings,
reply with evidence, avoid vague "fixed" or "will do" noise.

---

## Sources

If GitHub PR exists and comments exist, inspect:
- line comments, review comments, top-level PR comments
- bot comments (greptile, automated reviewers, CI annotations) separately if relevant

---

## Classification

**VALID_ACTIONABLE** — real issue still exists. Report as a finding in Open Findings.

**VALID_ALREADY_FIXED** — issue was real, current branch already addresses it. Reply with evidence.

**FALSE_POSITIVE** — comment misunderstood code or is factually wrong. Reply with evidence, not vibes.

**OPINIONATED_NON_BLOCKING** — reasonable preference or style suggestion. Do not pollute main review unless it masks a real bug.

**SUPPRESSED** — known low-value repeated bot noise. Skip.

---

## Reply policy

Replies must include: direct answer, evidence, file/line or commit reference when possible.
Avoid: "done", "fixed", "good catch" with no evidence, defensive essays.

**Already fixed:** Already addressed. Evidence: <file:line or commit>. Why this resolves it: <one line>.

**False positive:** Not a bug. Evidence: <file:line>. Why: <one line>.

**Opinionated:** Acknowledged. Non-blocking unless it exposes a real correctness or maintainability issue.

---

## Finding integration

If a valid comment points to a correctness issue, security issue, contract drift,
migration risk, missing unhappy-path handling, or obvious maintainability bug —
merge it into the main review findings. Classify and report per `fix-policy.md`.

---

## Inline Comment Policy

Authoritative source for inline PR comment rules. Other files reference this section only.

- BLOCKER: always posted (cap-exempt)
- WARNING: top 5 by confidence
- Same-file: max 2 per file (all severities)
- Scope: concrete `file:line` required — omit architectural concerns without one
- Priority: BLOCKERs first, then WARNING by confidence
- Overflow: remaining findings appear in Key Findings table only
- No NIT inline comments

