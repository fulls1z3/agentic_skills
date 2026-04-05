---
name: second-opinion
description: >-
  Runs a config-driven second opinion (Codex or Gemini) on a prepared diff
  artifact: resolves config, invokes the external tool, parses raw output to
  normalized YAML findings, and emits status signals. Invoked by code-review;
  standalone use requires ARTEFACTS_DIR already populated with diff.patch.
allowed-tools:
  - Bash
---

# second-opinion

## Purpose

This skill owns the complete second-opinion pipeline:

1. **Config resolution** — env var → repo-local → global → defaults
2. **Tool invocation** — Codex or Gemini, structured pass
3. **Parsing** — raw tool output normalized to YAML findings
4. **Artifact output** — `so_structured.yaml` (and raw `.txt` trail)

When invoked by `code-review`, routing decisions are made by the caller. This skill only executes the second-opinion work it is asked to do.

## Entry point

```bash
ARTEFACTS_DIR="$ARTEFACTS_DIR" bash second-opinion/scripts/run.sh
# → SO_TOOL, SO_MODEL, SO_STRUCTURED_STATUS
```

Required env: `ARTEFACTS_DIR` (must contain `diff.patch`).

**Bash timeout:** set to at least 330000ms (5.5 minutes) to accommodate the 5-minute tool timeout.

Stdout signals: `SO_TOOL` (`none`/`codex`/`gemini`), `SO_MODEL`, `SO_STRUCTURED_STATUS`.

Artifacts written to `$ARTEFACTS_DIR`: `so_config.sh`, `so_structured.txt` (raw), `so_structured.yaml` (normalized YAML findings), `so_status.txt` (status signal).

## Config resolution

`SECOND_OPINION_CONFIG` env → repo-local (`.claude/` / `.agents/`) → global (`~/.claude/` / `~/.agents/`) → built-in defaults. See `second-opinion/scripts/resolve.sh` for authoritative resolution order.

Config fields: `tool` (`none` / `codex` / `gemini`, default `none`), `model` (optional, passed as flag when set).

## Timeout policy

Both Codex and Gemini get 5 minutes (`SO_TIMEOUT=300`, overridable via env). Enforced in `run.sh` via GNU `timeout`/`gtimeout` or portable background+guard fallback. If the tool exceeds the timeout:

- `SO_STRUCTURED_STATUS=timed-out`
- Partial raw output preserved if available
- `so_structured.yaml` written as `[]` if structured extraction did not complete

## Status semantics

`SO_STRUCTURED_STATUS` values (non-overlapping):

| Status | Meaning |
|---|---|
| `ran` | Tool ran, parser extracted findings OR explicit PASS/no-findings signal detected |
| `raw-only` | Tool ran, raw output exists (>0 bytes), but parser extracted no structured findings — caller should read `so_structured.txt` |
| `failed` | Tool exited non-zero, OR tool exited 0 but produced 0-byte output (capture failure) |
| `timed-out` | Tool exceeded timeout (5 minutes default) |
| `skipped` | Tool configured as `none` or tool binary not installed |

## Error handling

`run.sh` always exits 0 — failures are surfaced via `SO_STRUCTURED_STATUS` signals, not non-zero exits. This ensures the calling skill can always continue. Inner scripts (`resolve.sh`, `structured.sh`) may exit non-zero; `run.sh` absorbs those exits.

## Artifact binding

Each run is bound to exactly one `$ARTEFACTS_DIR`. Only these are valid evidence for that run:

- `so_config.sh` — resolved config
- `so_structured.txt` — raw tool output
- `so_structured.yaml` — parsed YAML findings
- `so_status.txt` — status signal
- stdout `KEY=VALUE` signals from `run.sh`

Do NOT use prior task output, prior background run output, terminal traces from earlier runs, or ambiguous UI/task history as evidence for the current run.

## Report format (standalone only)

When run outside of `code-review`, follow `code-review/output-format.md`. Sections in order:

1. **Review Summary** — 2–4 paragraphs: what the diff does, what the second opinion found, explicit merge stance ("Safe to merge" / "Merge with caveats" / "Not safe to merge yet")
2. **Key Changes** — 3–6 bullets of high-signal implementation context; omit if diff is trivial
3. **Issues Found** — 0–4 bullets naming the most critical findings; write "No actionable findings." when clean
4. **Confidence Score: X/5** — why not higher; what would increase confidence; note `tool: {SO_TOOL}` in the rationale line
5. **Key Findings** — table with columns: Type, Confidence, File, Summary, Recommendation, Status; suppress `low`-confidence rows; show `medium`/`high` in Confidence column
6. **Important Files Changed** — omit if fewer than 3 files; one-line editorial per file
7. **Last reviewed** — sha, ISO timestamp, `tool: {SO_TOOL}`

The report must be synthesized exclusively from the current run's artifacts in `$ARTEFACTS_DIR`. Do not reference or incorporate findings from any other source.

When invoked by `code-review`, this skill does not produce a report — it writes normalized YAML findings to `$ARTEFACTS_DIR` for `code-review` to merge and annotate.
