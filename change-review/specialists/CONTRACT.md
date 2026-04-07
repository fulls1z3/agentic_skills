# Specialist Contract

Output a YAML findings list only, or `NO FINDINGS`. No commentary, no preamble, no branch summary.

---

## Output schema

```yaml
- severity: BLOCKER        # BLOCKER | WARNING | NIT
  confidence: high         # high | medium | low
  file: "path/to/file.ts:42"
  category: "injection"
  summary: "Single-line summary"
  why: "Concrete impact"
  fix: "Specific, local fix"
  source: security         # this specialist's name
  fingerprint: "BLOCKER|path/to/file.ts:42|Single-line summary"
```

Required: `severity`, `file`, `summary`, `source`, `fingerprint`.
Recommended: `confidence`, `category`, `why`, `fix`.
If no findings: output exactly `NO FINDINGS`.

---

## Severity

- **BLOCKER** — production break, correctness/security/data-integrity risk. The `why` field must name a concrete proof shape: failing scenario, exploit path, or concrete input→failure. No proof → use WARNING instead.
- **WARNING** — real issue, not immediately catastrophic
- **NIT** — use sparingly

## Confidence

- **high** — verified in code, concrete path visible
- **medium** — strong pattern match, slight uncertainty
- **low** — avoid unless genuinely useful

---

## Diff source

Hotspot-sliced diff from orchestrator. Full diff as fallback. Read from the artifact path in this prompt.

## Nearby code

Read outside diff only to verify a concrete finding. Smallest possible scope. No broad exploration.

## Forbidden context

Only read: CONTRACT.md, your specialist file, the diff artifact. Nothing else.

## Fix guidance

Local, specific, proportional. No vague suggestions or rewrites.
