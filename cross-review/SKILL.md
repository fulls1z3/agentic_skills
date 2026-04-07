---
name: cross-review
description: >-
  Runs cross-review (Codex or Gemini) on a prepared diff artifact: invokes
  the tool, parses raw output to normalized YAML findings, and emits status
  signals. Invoked by change-review; standalone use requires ARTEFACTS_DIR
  already populated with diff.patch.
allowed-tools:
  - Bash
---

# cross-review

## Purpose

This skill owns the complete cross-review pipeline:

1. **Tool invocation** — Codex or Gemini, structured pass
2. **Parsing** — raw tool output normalized to YAML findings
3. **Artifact output** — `cross_review_structured.yaml` (and raw `.txt` trail)

When invoked by `change-review`, routing decisions are made by the caller. This skill only executes the cross-review work it is asked to do.

## Entry point

```bash
ARTEFACTS_DIR="$ARTEFACTS_DIR" bash cross-review/scripts/run.sh
# → CROSS_REVIEW_TOOL, CROSS_REVIEW_MODEL, CROSS_REVIEW_STATUS
```

Required env: `ARTEFACTS_DIR` (must contain `diff.patch`).

**Bash timeout:** set to at least 330000ms (5.5 minutes) to accommodate the 5-minute tool timeout.

Stdout signals: `CROSS_REVIEW_TOOL` (`none`/`codex`/`gemini`), `CROSS_REVIEW_MODEL`, `CROSS_REVIEW_STATUS`.

Artifacts written to `$ARTEFACTS_DIR`: `cross_review_structured.txt` (raw), `cross_review_structured.yaml` (normalized YAML findings), `cross_review_status.txt` (status signal).

## Configuration

Env-only. No config files.

| Env var | Values | Default |
|---------|--------|---------|
| `CROSS_REVIEW_TOOL` | `none` / `codex` / `gemini` | `none` |
| `CROSS_REVIEW_MODEL` | model name string (optional) | tool default |
| `CROSS_REVIEW_TIMEOUT` | seconds | `300` |

## Timeout policy

Both Codex and Gemini get 5 minutes (`CROSS_REVIEW_TIMEOUT=300`, overridable via env). Enforced in `run.sh` via GNU `timeout`/`gtimeout` or portable background+guard fallback. If the tool exceeds the timeout:

- `CROSS_REVIEW_STATUS=timed-out`
- Partial raw output preserved if available
- `cross_review_structured.yaml` written as `[]` if structured extraction did not complete

## Status semantics

`CROSS_REVIEW_STATUS` values (non-overlapping):

| Status | Meaning |
|---|---|
| `ran` | Tool ran, parser extracted findings OR explicit PASS/no-findings signal detected |
| `raw-only` | Tool ran, raw output exists (>0 bytes), but parser extracted no structured findings — caller should read `cross_review_structured.txt` |
| `failed` | Tool exited non-zero, OR tool exited 0 but produced 0-byte output (capture failure) |
| `timed-out` | Tool exceeded timeout (5 minutes default) |
| `skipped` | Tool configured as `none` or tool binary not installed |

## Error handling

`run.sh` always exits 0 — failures are surfaced via `CROSS_REVIEW_STATUS` signals, not non-zero exits. This ensures the calling skill can always continue. `structured.sh` may exit non-zero; `run.sh` absorbs those exits.

## Artifact binding

Each run is bound to exactly one `$ARTEFACTS_DIR`. Only these are valid evidence for that run:

- `cross_review_structured.txt` — raw tool output
- `cross_review_structured.yaml` — parsed YAML findings
- `cross_review_status.txt` — status signal
- stdout `KEY=VALUE` signals from `run.sh`

Do NOT use prior task output, prior background run output, terminal traces from earlier runs, or ambiguous UI/task history as evidence for the current run.

## Report format (standalone only)

When run outside of `change-review`, follow `change-review/output-format.md`. Sections in order:

1. **Review Summary** — 2–4 paragraphs: what the diff does, what the cross-review found, explicit merge stance ("Safe to merge" / "Merge with caveats" / "Not safe to merge yet")
2. **Key Changes** — 3–6 bullets of high-signal implementation context; omit if diff is trivial
3. **Issues Found** — 0–4 bullets naming the most critical findings; write "No actionable findings." when clean
4. **Confidence Score: X/5** — why not higher; what would increase confidence; note `tool: {CROSS_REVIEW_TOOL}` in the rationale line
5. **Key Findings** — table with columns: Type, Confidence, File, Summary, Recommendation, Status; suppress `low`-confidence rows; show `medium`/`high` in Confidence column
6. **Important Files Changed** — omit if fewer than 3 files; one-line editorial per file
7. **Last reviewed** — sha, ISO timestamp, `tool: {CROSS_REVIEW_TOOL}`

The report must be synthesized exclusively from the current run's artifacts in `$ARTEFACTS_DIR`. Do not reference or incorporate findings from any other source.

When invoked by `change-review`, this skill does not produce a report — it writes normalized YAML findings to `$ARTEFACTS_DIR` for `change-review` to merge and annotate.
