# Output Format

Authoritative format and conventions for all change-review reports. Applies to CLI output and GitHub PR comments.

---

## Confidence Score

| Score | Meaning |
|-------|---------|
| 5/5 | Very strong — no blockers, no significant warnings |
| 4/5 | Solid — minor issues only, no blocking concerns |
| 3/5 | Caution — meaningful warnings requiring attention |
| 2/5 | Risky — blockers present or high-risk issues unresolved |
| 1/5 | Not ready — major concerns, incomplete, or fundamentally unsound |

Cap rules:
- Cross-review was warranted by risk but could not run (`CROSS_REVIEW_TOOL=none`): cap at 3/5.
- Cross-review ran and confirmed a BLOCKER: annotate finding as `(multi-confirmed)`; score stays at 2/5 or lower.

Present the score as: score, one sentence on why not higher, one sentence on what would increase confidence. If the diff is clean, omit "what would increase confidence."

---

## Severity Language

| Level | Use when |
|-------|----------|
| BLOCKER | Correctness bug, security vulnerability, data loss risk, broken contract — blocks merge |
| WARNING | Real risk that doesn't block merge outright; should be addressed before or shortly after merge |
| NIT | Style, minor inconsistency, low-priority suggestion — omit if nothing is actionable |

BLOCKER summaries must be evidence-first: state the failure scenario or exploit path, not just the vulnerability class. A BLOCKER without a concrete proof shape (failing scenario, exploit path, concrete input→failure) must appear as WARNING.

---

## Report template

````
### Review Summary

<2–4 paragraphs: what the change does, what is stable, what is risky or incomplete.
Lead with the change — not the file list.
End with explicit merge stance: one of "Safe to merge", "Merge with caveats", or "Not safe to merge yet".
Transition-state reviews: ≤2 paragraphs. State the blocker. Do not re-derive branch history.>

---

### Key Changes

- <high-signal implementation bullet>
- <high-signal implementation bullet>
<!-- 3–6 bullets. Only changes that matter to the reviewer. Skip if diff is trivial. -->

---

### Issues Found

<!-- 0–4 bullets calling out the most important findings before the table.
     If there are no actionable findings, write: No actionable findings in this diff. -->

---

### Confidence Score: X/5

<Why not higher. What would increase confidence.>

---

### Key Findings

| Type | Confidence | File | Summary | Recommendation | Status |
|------|-----------|------|---------|---------------|--------|
| BLOCKER | high | `path/to/file:42` | summary | fix | unresolved |
| WARNING | medium | `path/to/file:10` | summary | fix | deferred |

---

### Important Files Changed

| File | What changed and why it matters |
|------|---------------------------------|
| `path/to/file` | one-line editorial |

---

<sub>Last reviewed: `{sha}` · {ISO timestamp}</sub>
````

---

## Section rules

### Review Summary

Sharp prose. Lead with what the change does, then what is working, then what is risky or missing. 2–4 paragraphs maximum. Not a file enumeration. End with an explicit merge stance (see Merge Stance below).

### Key Changes

3–6 bullets covering only the high-signal implementation changes that give the reviewer orientation context. This is not a findings section — it is background. Omit if the diff is trivial (fewer than ~20 meaningful lines). Never replicate finding content here.

### Issues Found

0–4 bullets that surface the most critical finding(s) before the table. This section orients the reader before they hit the full table. When there are no actionable findings, state exactly: "No actionable findings in this diff." Do not list things here that are not also in the Key Findings table.

### Confidence Score

Present as: score line, one sentence on why not higher, one sentence on what would increase confidence. If the diff is clean, omit the "what would increase confidence" sentence.

### Key Findings

One row per finding. Type values: `BLOCKER`, `WARNING`, `NIT`. Status values: `unresolved` or `deferred` only. When multiple sources independently identified a finding, add `(multi-confirmed)` to the Summary cell.

Per-finding confidence rendering:
- `low`: omit from table entirely — do not render
- `medium`: include; show `medium` in Confidence column
- `high`: include; show `high` in Confidence column
- absent or unrecognized: treat as `medium`

Confidence appears as its own column — do not embed it in the Summary cell.

Omit NIT rows if nothing warrants reviewer attention.

### Important Files Changed

Omit if fewer than 3 changed files. Omit trivial files. Each row: file path in first column, a tight one-line editorial in the second answering "what changed and why this file matters." No multi-sentence prose. No diff recap.

### Carry-forward / Prior Findings

Include only when there are prior findings to surface (incremental or no-change mode). Compact format — prefer a single sentence or a compact bullet list. Clearly distinguish:
- **New** — not seen in prior review
- **Fixed** — present before, gone now
- **Still unresolved** — same fingerprint, still present
- **Carried forward** — prior findings on unchanged files, not re-reviewed this run

### No-change / carry-forward compact output

When `REVIEW_MODE=no-change` or when an incremental run has zero new findings:
- Do not emit full report ceremony
- Emit a compact block (3–6 lines max):
  - One line: what mode this is and why
  - One line: number of prior unresolved findings carried forward (if any)
  - One line: last reviewed sha reference
- No Key Changes, no Issues Found, no Confidence Score unless something changed

### Last reviewed

Always include: sha and ISO timestamp.

---

## Merge Stance

The Review Summary must end with exactly one of:

| Phrase | When to use |
|--------|-------------|
| **Safe to merge** | No BLOCKERs, no meaningful WARNINGs requiring action before merge |
| **Merge with caveats** | WARNINGs present that should be addressed before or shortly after merge; no BLOCKERs |
| **Not safe to merge yet** | One or more unresolved BLOCKERs present |

Do not use any other phrasing for the merge stance. Do not hedge or qualify the phrase. If an unresolved BLOCKER exists, the stance is "Not safe to merge yet" — period.

---

## Multi-confirmed annotation

When both main review and cross-review independently identify the same finding, annotate as `(multi-confirmed)` in the Summary cell of Key Findings. No separate cross-review section.

---

## Tone and formatting

- Prose-first. Lead with what the change does, not a file enumeration.
- No Mermaid diagrams.
- No orchestration dumps (specialist dispatch tables, routing plan details).
- No mutation language: no "Applied fixes", "Fixed during review".
- Do not report speculation as fact.
- Do not suppress findings because tests pass.
- End at the last reviewed line — no open-ended continuation hooks.
- No contradiction between sections: if merge stance is "Safe to merge", the Key Findings table must be empty or contain only NITs. If Issues Found says "no actionable findings", the Key Findings table must be empty.

---

## PR comment body

Use the same structure and voice as the full report, but slightly tighter:
- Review Summary: 2–3 paragraphs max (not 4)
- Key Changes: include only if it meaningfully helps the reviewer; otherwise omit
- Issues Found: always include (even as "No actionable findings" when clean)
- Confidence Score: keep; compress rationale to one sentence total
- Key Findings table: identical structure including Confidence column
- Important Files Changed: omit unless there are ≥3 files and at least one merits editorial comment
- Last reviewed: always include

---

## General rules

- No arbitrary cap on findings
- Unresolved findings must be visible
- Confidence column is always present in the Key Findings table when there are findings
