# Output Format

Use this structure exactly.

```
Review Report: <TOTAL_FOUND> findings, <TOTAL_FIXED> fixed, <TOTAL_REMAINING> remaining

Scope Check: <CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING>
Risk Level: <LOW / MEDIUM / HIGH>
Intent: <one line>
Delivered: <one line>

---

Specialist Dispatch
Dispatched: <comma-separated names or none>
Skipped: <name (reason), name (reason), ... or none>

---

BLOCKERS

1. [BLOCKER][<confidence>] <file:line> — <summary>
   Why it matters: <impact>
   Recommended fix: <fix>
   Status: <fixed / unresolved / reported-only / not-safe-to-auto-fix>
   Source: <main-review / specialist-name / claude-adversarial / second-opinion / multi-confirmed / pr-comments>

---

WARNINGS

1. [WARNING][<confidence>] <file:line> — <summary>
   Why it matters: <impact>
   Recommended fix: <fix>
   Status: <fixed / unresolved / reported-only / not-safe-to-auto-fix>
   Source: <...>

---

NITS

1. [NIT][<confidence>] <file:line> — <summary>
   Recommended fix: <fix>
   Status: <fixed / unresolved>
   Source: <...>

---

Applied Fixes

1. <file:line> — <what was changed>

---

Second Opinion
Tool: <codex / gemini / none / unavailable>
Status: <ran / skipped-low-risk / skipped-medium-non-sharp / offered-declined / offered-discuss / unavailable / failed>
Structured review gate: <PASS / FAIL / n/a>
Adversarial summary: <summary or n/a>
Additional findings: <count>
Additional fixes applied: <count>

---

PR Comments
Total reviewed: <n>
Valid actionable: <n>
Already fixed: <n>
False positive: <n>
Opinionated non-blocking: <n>
Fixed from comments: <n>
Replied: <n>

---

Missing Tests / Validation
- <item>

---

Unresolved Issues
1. <issue>

---

Verdict
Commit readiness: <READY / READY WITH WARNINGS / NOT READY>
PR readiness: <READY / READY WITH WARNINGS / NOT READY>
Review strength: <WEAK / STANDARD / STRONG>

Next move
<one concrete recommendation>
```

---

## Rules

- No arbitrary cap on findings
- Include all grounded findings
- Fixed items stay visible in the report
- Unresolved items must be explicit
- If no findings, say so plainly
- Omit PR Comments section only if comment triage never ran
- Second Opinion status `offered-discuss`: plain MEDIUM where second opinion was offered but discussion was chosen first. Do not claim resumable execution as guaranteed.