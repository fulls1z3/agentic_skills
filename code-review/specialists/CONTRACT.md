# Specialist Contract

Every specialist follows this contract.

Do not output commentary. Do not output preamble. Do not summarize the branch.
Output JSONL findings only, or `NO FINDINGS`.

---

## Output schema

One JSON object per line:
```json
{"severity":"BLOCKER|WARNING|NIT","confidence":"high|medium|low","path":"file","line":123,"category":"...","summary":"...","why":"...","fix":"...","fingerprint":"file:line:category","specialist":"..."}
```

Required: severity, confidence, path, category, summary, why, fix, specialist.
Optional: line, fingerprint.

If `fingerprint` is omitted, caller computes `path:line:category` or `path:category`.

If no findings: output exactly `NO FINDINGS`.

---

## Severity

- **BLOCKER** — plausible production break, concrete correctness/security/data integrity risk
- **WARNING** — real issue, should likely be fixed before PR, not immediately catastrophic
- **NIT** — use sparingly, only for low-risk clearly useful cleanup

## Confidence

- **high** — verified in code, concrete path or failure mode visible
- **medium** — strong pattern match, likely real, slight uncertainty
- **low** — avoid unless genuinely useful, low-confidence noise is expensive

---

## Diff source

Read from `/tmp/code-review/diff.patch` unless the orchestrator passes a different path.

---

## Fix guidance

Recommend fixes that are local, specific, realistic, and proportional.
Avoid vague "improve this", giant rewrites, or style-only feedback.