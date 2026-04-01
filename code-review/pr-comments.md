# PR Comment and Review Reply Policy

This skill inspects and responds to PR review comments when a PR exists and comments exist.

Goal: treat reviewer comments as additional review input, fix valid ones when safe,
reply with evidence, avoid vague "fixed" or "will do" noise.

---

## Sources

If GitHub PR exists and comments exist, inspect:
- line comments, review comments, top-level PR comments
- bot comments (greptile, automated reviewers, CI annotations) separately if relevant

---

## Classification

**VALID_ACTIONABLE** — real issue still exists. Fix if safe, else report in unresolved issues.

**VALID_ALREADY_FIXED** — issue was real, current branch already addresses it. Reply with evidence.

**FALSE_POSITIVE** — comment misunderstood code or is factually wrong. Reply with evidence, not vibes.

**OPINIONATED_NON_BLOCKING** — reasonable preference or style suggestion. Do not pollute main review unless it masks a real bug.

**SUPPRESSED** — known low-value repeated bot noise. Skip.

---

## Reply policy

Replies must include: direct answer, evidence, file/line or commit reference when possible.
Avoid: "done", "fixed", "good catch" with no evidence, defensive essays.

**Fix reply:** Fixed in current branch. What changed: <one line>. Why: <one line>. Evidence: <file:line or commit>.

**Already fixed:** Already addressed. Evidence: <file:line or commit>. Why this resolves it: <one line>.

**False positive:** Not a bug. Evidence: <file:line>. Why: <one line>.

**Opinionated:** Acknowledged. Non-blocking unless it exposes a real correctness or maintainability issue.

---

## Fix-first integration

If a valid comment points to a correctness issue, security issue, contract drift,
migration risk, missing unhappy-path handling, or obvious maintainability bug —
merge it into the main review findings and fix if safe.

---

## Output integration

Include in final report:
- Total reviewed, valid actionable, already fixed, false positive, opinionated non-blocking, fixed from comments, replied