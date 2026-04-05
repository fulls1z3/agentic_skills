---
name: code-review
description: >-
  Use ONLY when the user has a git diff, open PR, or branch divergence to review.
  Triggers on: "review my PR / diff / branch", "check this branch against main",
  "is this commit/PR ready to merge", "review these PR comments", "fix issues from my review".
  Do NOT trigger for: general code questions, single-file analysis without a diff,
  broad codebase exploration, writing tasks, planning, or anything without an explicit
  diff/PR/branch scope. Requires a git repository with branch divergence to function.
  Performs execution-grade diff review with specialist dispatch,
  red-team adversarial specialist, and config-driven second opinion (Codex/Gemini).
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - WebSearch
  - Agent
---

# Code Review Skill

## Scope

**This skill reviews git diffs, branches, and PRs.** It is not a general code assistant.

Stop immediately and do not proceed if any of these are true:
- No git repository is present in CWD
- The user is asking about a single file or snippet without any branch / diff context
- The request is a writing, planning, refactoring, or exploration task — not a review of committed or staged changes
- There is no branch divergence (checked in Step 3 — "Nothing to review" is a valid outcome)

---

## Principles
- Find what is unsafe. Recommend specific fixes. Escalate only when behavior intent is unclear, fix is security/concurrency-sensitive, change is broad, or user-visible behavior would change.
- Token-aware: graduated depth by risk.
- Same-session self-review is weaker — say so.
- No finding cap.
- Green tests ≠ safe. Races, stale reads, enum gaps, silent corruption, bad retry logic survive CI.

---

## Execution model

Each invocation is a fresh run. No state is carried over from a prior conversation or prior review. `gather_context.sh` creates a unique per-invocation artifact directory (`/tmp/code-review-<project-key>-<pid>/`) and prints `ARTEFACTS_DIR=<path>`. The orchestrator captures this value and passes it as an env var prefix to every downstream script. Do not assume artifacts from a previous invocation are present or valid.

The final report must not include open-ended continuation hooks ("next move", "shall I…", "want me to…"). End at the last reviewed line. The user decides what happens next.

### Script output convention

All `scripts/` emit `KEY=VALUE` lines to stdout. The standard extraction pattern is:

```bash
_OUT=$(bash code-review/scripts/<script>.sh [args])
VAR=$(printf '%s\n' "$_OUT" | grep '^VAR=' | cut -d= -f2-)
```

`# → VAR1, VAR2` after a script call means: extract those variables from `_OUT` using the pattern above.

---

## Routing

`review_plan.yaml` pre-computed by `detect_scope.sh`. Steps 7–12 consume it directly.

- **Models:** all specialists → `model: "haiku"`. Exceptions: security → sonnet on HIGH + auth/trust/shell signal; red-team → sonnet on HIGH.
- **Cheap lane:** very-tiny/low → main only. Non-sharp cap=1, testing default, override by stronger signal.
- **Pre-filter (9.2):** launch from `run_specialists[]` on ≥1 BLOCKER/WARNING in domain; else skip unless HIGH (delta≥40) or MEDIUM_SHARP (diff≥80).
- **Second opinion (12):** `SO_TOOL=none` → skip. Gate: reject `P1`/`BLOCKER` prefix; discard skill-internal refs.

---

## Step 1: Detect base branch

```bash
# Anchor CWD to repo root once — all relative paths in later steps depend on this.
cd "$(git rev-parse --show-toplevel)"
_OUT=$(bash code-review/scripts/detect_base.sh)
# → BASE_BRANCH, MERGE_BASE
```

---

## Step 2: Load prior state

```bash
_OUT=$(bash code-review/scripts/load_prior_state.sh)
# → PRIOR_STATE_EXISTS, PRIOR_HEAD_COMMIT, PRIOR_FINGERPRINTS_FILE
```

Decision tree (execute in order, stop at first match):

1. `PRIOR_STATE_EXISTS=false` → `REVIEW_MODE=full`. Continue to Step 3.

2. `PRIOR_STATE_EXISTS=true`:

   a. **Anchor reachability** — use `-e` (object exists), not `-t` (avoids HEAD pipe):
      ```bash
      git cat-file -e "$PRIOR_HEAD_COMMIT" 2>/dev/null
      ```
      Non-zero exit (shallow clone, force-push, history rewrite) →
      `REVIEW_MODE=full-fallback`, clear `PRIOR_HEAD_COMMIT`. Continue to Step 3.

   b. **HEAD match** — compare against current HEAD:
      ```bash
      CURRENT_HEAD=$(git rev-parse HEAD)
      ```
      If `CURRENT_HEAD == PRIOR_HEAD_COMMIT` → `REVIEW_MODE=incremental`. Continue to Step 3.
      Reviewability is decided at Step 5 (`gen_incremental.sh`), which checks tracked changes
      AND untracked reviewable files. Do NOT short-circuit to no-change here.

   c. Otherwise → `REVIEW_MODE=incremental`. Continue to Step 3.

Keep `PRIOR_FINGERPRINTS_FILE` for Step 13.

---

## Step 3: Check diff exists

```bash
git fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true
git diff "$MERGE_BASE"...HEAD --stat
```

If no meaningful diff: `Nothing to review — no branch diff against $BASE_BRANCH.` Stop.

---

## Step 4: Gather context artefacts

```bash
_OUT=$(bash code-review/scripts/gather_context.sh "$BASE_BRANCH")
# → ARTEFACTS_DIR, DIFF_TOTAL, TRANSITION_STATE
```

Produces: `$ARTEFACTS_DIR/{diff.patch,changed_files.txt,pr.json,commits.txt,diff_total.txt,uncommitted.txt,transition_state.txt}`

Read:

* `$ARTEFACTS_DIR/pr.json`
* `$ARTEFACTS_DIR/commits.txt`
* `$ARTEFACTS_DIR/uncommitted.txt`

If uncommitted changes exist, note them.

**Transition state:** If `TRANSITION_STATE=true`, the repo has bulk staged deletions + untracked replacements (typical of skill rewrites or directory renames). Report this as a first-class BLOCKER in Step 8. Keep Review Summary to ≤2 paragraphs — state the blocker, list deferred findings in the table, do not re-derive branch history.

---

## Step 5: Generate incremental diff (incremental mode only)

Skip this step if `REVIEW_MODE=full` or `REVIEW_MODE=full-fallback`.

```bash
_OUT=$(ARTEFACTS_DIR="$ARTEFACTS_DIR" PRIOR_HEAD_COMMIT="$PRIOR_HEAD_COMMIT" \
  bash code-review/scripts/gen_incremental.sh)
# → INCREMENTAL_CHANGED_COUNT, INCREMENTAL_DIFF_TOTAL, INCREMENTAL_REVIEWABLE
```

**Reviewability gate:** If `INCREMENTAL_REVIEWABLE=false`, the incremental diff has zero changed files. Switch to no-change/carry-forward — do not continue to Step 6:
```
INCREMENTAL_EMPTY: no reviewable changes since prior review at <PRIOR_HEAD_COMMIT>
Prior fingerprints: <count> unresolved findings carried forward
```
Then call the persistence script and STOP:
```bash
REVIEW_MODE="no-change" bash code-review/scripts/write_review_state.sh
```

If `INCREMENTAL_REVIEWABLE=true`, continue to Step 6. Step 8 uses `incremental_diff.patch`.

---

## Step 6: Determine intent and scope

From:

* branch name
* commits (`$ARTEFACTS_DIR/commits.txt`)
* PR title/body (`$ARTEFACTS_DIR/pr.json`)
* `TODOS.md`, `PLAN.md`, or `SPEC.md` if present at repo root

```text
Intent: <one line>
Delivered: <one line>
```

If mismatch, flag it.

Scope check:

* `CLEAN` — diff matches task
* `DRIFT DETECTED` — out-of-scope edits
* `REQUIREMENTS MISSING` — partial implementation, missing tests/docs/config

Informational. Continue regardless.

### Plan Coverage

Check for actionable items in this order: PR body checkbox list (`- [ ]`/`- [x]`), `TODOS.md`, `PLAN.md`, `SPEC.md` at repo root. Use the **first** source that yields ≥2 items. Do not merge across sources. **If no source yields ≥2 items, skip this section entirely — no penalty.**

Item extraction rules:
- PR body: count only `- [ ]` / `- [x]` checkbox lines.
- TODOS.md / PLAN.md / SPEC.md: count only markdown list lines starting with `- `, `* `, or a digit followed by `.` (e.g. `1.`). Ignore prose, headers, and code blocks.

For each item (up to 10): grep key nouns/verbs against `$ARTEFACTS_DIR/diff.patch` only. No extra file reads. Assign:

* `DONE` — item keywords clearly present in diff
* `PARTIAL` — some signal, coverage looks incomplete
* `NOT DONE` — no signal in diff
* `CHANGED` — diff contradicts or replaces the stated intent

Output one line per item. Surface `NOT DONE` / `PARTIAL` items in Review Summary only when they look like real gaps — not explicit future-work markers ("stretch goal", "follow-up", "next sprint", "nice to have", "later", "deferred", "out of scope", "phase 2", "backlog", "v2").

---

## Step 7: Classify risk and build review plan

```bash
_OUT=$(ARTEFACTS_DIR="$ARTEFACTS_DIR" REVIEW_MODE="$REVIEW_MODE" \
  bash code-review/scripts/detect_scope.sh "$BASE_BRANCH")
# → RISK, MEDIUM_SHARP
```

Reads context from `$ARTEFACTS_DIR/`. Writes:

* `$ARTEFACTS_DIR/review_plan.yaml`

Read `$ARTEFACTS_DIR/review_plan.yaml`. Use the Routing section above as the execution contract.

Print: `Risk Level: <RISK>`

---

## Step 8: Main structured review

Read:

* `code-review/checklist.md`

Review diff and directly related code. Read outside diff when needed.

* **full mode**: `$ARTEFACTS_DIR/diff.patch` (merge_base..HEAD)
* **incremental mode**: `$ARTEFACTS_DIR/incremental_diff.patch` (prior_head..HEAD)

Finding contract — for every finding:

* severity: `BLOCKER | WARNING | NIT`
* confidence: `high | medium | low`
  - `high`: concrete and diff-evidenced; reproducible without significant inference
  - `medium`: real issue but requires inference, framework knowledge, or uncertain context
  - `low`: speculative or heuristic-only; not directly demonstrated by the diff
* file:line
* summary
* why it matters
* recommended fix
* source: `main-review`

Do not report speculation as fact. Do not suppress risk because tests pass. Use WebSearch when framework behavior is uncertain.

---

## Step 9: Specialist dispatch

### 9.1 Read contract

```bash
cat code-review/specialists/CONTRACT.md
```

### 9.2 Select specialists — pre-filter gate

Apply the pre-filter (Routing > Pre-filter above): use domain hits from Step 8 findings, launch rules, and caps. Candidates come from `review_plan.yaml -> run_specialists[]`.

When `review_plan.yaml -> orchestration_mode = large-pr`, dispatch specialists sequentially.

Print to execution log (not to the report): `Specialists Dispatched: [<name> (<reason>)]` and `Specialists Skipped: [<name> (<reason>)]`.

### 9.3 Dispatch (parallel in normal mode; sequential in large-pr mode)

**Model param:** Set `model` in each Agent tool call per Routing > Models. Execution requirement.

**Hotspot slice:** Before dispatching, prepare domain-filtered slices to reduce specialist token cost.

```bash
DIFF_SRC=$([ "$REVIEW_MODE" = "incremental" ] \
  && echo "$ARTEFACTS_DIR/incremental_diff.patch" \
  || echo "$ARTEFACTS_DIR/diff.patch")

_slice() {
  awk -v p="$1" '
    /^diff --git /{if(m)printf"%s",b;m=($0~p);b=$0"\n";next}
    !m && /^[+-][^+-]/{if($0~p)m=1}
    {b=b$0"\n"}
    END{if(m)printf"%s",b}
  ' "$DIFF_SRC" >"$2"
  [ -s "$2" ] || cp "$DIFF_SRC" "$2"
}

_slice 'auth|session|token|permission|role|subprocess|shell|exec([^u]|$)|sql|crypt|sanitiz' "$ARTEFACTS_DIR/security_slice.patch"
_slice 'test|spec|mock|stub|fixture' "$ARTEFACTS_DIR/testing_slice.patch"
_slice 'migration|schema|\.sql' "$ARTEFACTS_DIR/data-migration_slice.patch"
_slice 'openapi|swagger|graphql|\.proto|/api/v' "$ARTEFACTS_DIR/api-contract_slice.patch"
_slice 'query|index|cache|render|route|controller' "$ARTEFACTS_DIR/performance_slice.patch"
cp "$DIFF_SRC" "$ARTEFACTS_DIR/maintainability_slice.patch"
cp "$DIFF_SRC" "$ARTEFACTS_DIR/red-team_slice.patch"

# Bounded-read meta: emit per-slice budget signals
_SLICE_BUDGET=800

_meta() {
  local name="$1"
  local f="$ARTEFACTS_DIR/${name}_slice.patch"
  local meta="$ARTEFACTS_DIR/${name}_slice.meta"
  local _lc
  _lc=$(wc -l < "$f" | tr -d ' ')
  if [ "$_lc" -gt "$_SLICE_BUDGET" ]; then
    printf 'SLICE_LINES=%d\nSLICE_BOUNDED=true\nREAD_FIRST_LINES=%d\n' "$_lc" "$_SLICE_BUDGET" > "$meta"
  else
    printf 'SLICE_LINES=%d\nSLICE_BOUNDED=false\n' "$_lc" > "$meta"
  fi
}

for _s in security testing data-migration api-contract performance maintainability red-team; do
  _meta "$_s"
done
```

**Normal mode:** Launch all via Agent tool in a single message. When `RISK=HIGH` and `run_second_opinion=true`, include a Bash call in the same message (timeout=330000 to allow 5-minute tool timeout):

```bash
ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="$DIFF_SRC" bash second-opinion/scripts/run.sh
```

Step 12 reads its artifacts; does not re-invoke.

Each specialist must:

1. Read `code-review/specialists/CONTRACT.md` and its own specialist file only
2. Read its slice: `$ARTEFACTS_DIR/<name>_slice.patch`
3. Output YAML findings list only, or `NO FINDINGS`

**Context restrictions:** Each prompt includes exactly: CONTRACT.md path, specialist file path, `<name>_slice.patch` path, one-line scope note (`Scope: <N> files, <M> lines, risk: <RISK>`). Nothing else. Do NOT pass: PR metadata, other specialist files, SKILL.md, README.md, CLAUDE.md, full `$ARTEFACTS_DIR` path, `.claude/` contents.

**Bounded-read:** Before dispatching each specialist, read `$ARTEFACTS_DIR/<name>_slice.meta`. If `SLICE_BOUNDED=true`, append to the specialist prompt: `"Slice is <SLICE_LINES> lines. Read only the first <READ_FIRST_LINES> lines for detailed review. Then run grep '^diff --git' on the slice to identify remaining files and read selectively as needed to verify concrete findings."` If `SLICE_BOUNDED=false`, no additional instruction.

**Nearby-code rule:** read slice first; read outside only to verify a concrete finding — smallest possible scope.

### 9.4 Merge and deduplicate

Parse YAML, dedupe by fingerprint, tag multi-confirmed, keep best evidence.

Multi-confirmed findings (identified by ≥2 independent sources): upgrade confidence to at least `medium`. Upgrade to `high` if both sources assessed it with high-confidence evidence or the combined evidence is concrete and diff-evidenced.

---

## Step 10: Red-team adversarial review

Run when `review_plan.yaml -> run_red_team = true`.

Dispatch:

* `code-review/specialists/red-team.md`
* `code-review/specialists/CONTRACT.md`

Pass diff path `$ARTEFACTS_DIR/diff.patch`. Output YAML (per CONTRACT.md).

---

## Step 11: PR comment triage (lazy-loaded)

```bash
_OUT=$(bash code-review/scripts/pr_comment_count.sh)
# → PR_NUMBER, COMMENT_COUNT
```

* No PR → skip
* `COMMENT_COUNT=0` → skip
* Comments exist → read `code-review/pr-comments.md`, classify, triage

---

## Step 12: Independent second opinion

### 12.1 Check routing

Read `$ARTEFACTS_DIR/review_plan.yaml`. No prompts, no pauses, no user input.

* `run_second_opinion = false` → skip silently, go to Step 13

### 12.2 Invoke or read artifacts

**HIGH:** already launched at 9.3 — skip to 12.3.

**MEDIUM_SHARP:** invoke now (timeout=330000 to allow 5-minute tool timeout):

```bash
DIFF_SRC=$([ "$REVIEW_MODE" = "incremental" ] \
  && echo "$ARTEFACTS_DIR/incremental_diff.patch" \
  || echo "$ARTEFACTS_DIR/diff.patch")

_OUT=$(ARTEFACTS_DIR="$ARTEFACTS_DIR" DIFF_PATCH="$DIFF_SRC" bash second-opinion/scripts/run.sh)
# → SO_TOOL, SO_MODEL, SO_STRUCTURED_STATUS
```

`SO_TOOL=none` → emit `SECOND_OPINION_SKIPPED: tool=none`. Apply gate rules per Routing.

### 12.3 Merge findings

Read `$ARTEFACTS_DIR/so_structured.yaml`.

- `SO_STRUCTURED_STATUS=ran` — YAML contains findings (or `[]` with PASS signal). Merge normally.
- `SO_STRUCTURED_STATUS=raw-only` — YAML is `[]` but raw output exists. Read `$ARTEFACTS_DIR/so_structured.txt` and extract findings manually.
- `SO_STRUCTURED_STATUS=timed-out` — tool exceeded 5-minute timeout. YAML is `[]`, raw output may be partial. Note timeout in report. Do not claim second opinion findings.
- `SO_STRUCTURED_STATUS=failed` — tool crashed or capture failed. Continue without second opinion findings.

Before merging, enforce proof-shape rule on SO findings:
```bash
bash code-review/scripts/downgrade_blockers.sh "$ARTEFACTS_DIR/so_structured.yaml"
```

Dedupe by fingerprint, mark multi-confirmed. If an external BLOCKER lacks a concrete proof shape in its `why`/`summary` (no failing scenario, exploit path, or concrete input→failure), downgrade to WARNING before adding to the finding set.

---

## Step 13: Findings classification and recommendations

Read:

* `code-review/fix-policy.md`

### 13.1 Collect and deduplicate

Merge all findings from:

* main review
* specialists
* red-team
* PR comments
* second opinion (prefer normalized YAML from `$ARTEFACTS_DIR/so_structured.yaml`; fall back to raw `.txt` if absent or empty)

Deduplicate by fingerprint. Findings seen by multiple sources: annotate as multi-confirmed.

**Confidence normalization (required):** For every finding in the merged set, if `confidence` is absent or not one of `high | medium | low`, assign `confidence: medium`. Apply before Step 14. Multi-confirmed findings then follow Step 9.4 upgrade rules.

**BLOCKER proof enforcement (required):** For every BLOCKER in the merged set (from any source — main-review, specialists, red-team, second opinion), verify the `why` or `summary` names a concrete proof shape: failing scenario, exploit path, or concrete input→failure. If absent and `why` is fewer than 8 words, downgrade to WARNING. Apply before Step 14.

### 13.2 Classify for reporting

Classify each finding using `fix-policy.md`. Do not modify any source file. Do not commit. Do not push.

### 13.3 Classify against prior state

Always runs (full, incremental, and full-fallback mode). On the first run `PRIOR_FINGERPRINTS_FILE` is empty — all findings are classified as new.

```bash
if [ "$REVIEW_MODE" = "incremental" ]; then
  _CHANGED_FILES="$ARTEFACTS_DIR/incremental_changed_files.txt"
  _DIFF_LINE_COUNT="${INCREMENTAL_DIFF_TOTAL:-0}"
else
  _CHANGED_FILES="$ARTEFACTS_DIR/changed_files.txt"
  _DIFF_LINE_COUNT="${DIFF_TOTAL:-0}"
fi

_OUT=$(
  ARTEFACTS_DIR="$ARTEFACTS_DIR" \
  PRIOR_FINGERPRINTS_FILE="${PRIOR_FINGERPRINTS_FILE:-}" \
  REVIEW_MODE="$REVIEW_MODE" \
  INCREMENTAL_CHANGED_FILES="$_CHANGED_FILES" \
  DIFF_LINE_COUNT="$_DIFF_LINE_COUNT" \
  bash code-review/scripts/classify_findings.sh
)
# → CLASSIFY_NEW, CLASSIFY_FIXED, CLASSIFY_STILL_UNRESOLVED, CLASSIFY_STALE
```

---

## Step 14: Final report

Read `code-review/output-format.md`. It is the single source of truth for report structure, section rules, scoring model, and severity language.

### 14.1 Write report

Follow the template and section rules in `output-format.md`. Required sections:

* **Review Summary** — 2–4 paragraphs: what the change does, what works, what is risky; end with explicit merge stance ("Safe to merge" / "Merge with caveats" / "Not safe to merge yet")
* **Key Changes** — 3–6 bullets of high-signal implementation context; omit if diff is trivial
* **Issues Found** — 0–4 bullets naming the most critical findings before the table; write "No actionable findings in this diff." when clean
* **Confidence Score: X/5** — per scoring model in `output-format.md`; why not higher; what would increase confidence; add "Corroborated by second opinion." if SO ran and confirmed a finding
* **Key Findings** — markdown table (Type, Confidence, File, Summary, Recommendation, Status); Status is `unresolved` or `deferred`; Confidence column shows `high`/`medium` per finding (never embed confidence in Summary cell); annotate SO-confirmed findings as `(multi-confirmed)` in Summary cell; treat absent or unrecognized `confidence` as `medium`; suppress `low`-confidence findings from this table entirely
* **Important Files Changed** — omit if fewer than 3 files; each row: file + one-line editorial answering "what changed and why it matters"
* **Last reviewed** — sha and ISO timestamp

End the report at the last reviewed line. No continuation hooks.

### 14.2 Write report artifact

Write the full report to `$ARTEFACTS_DIR/report.md`. Same content as stdout.

### 14.3 Write inline comments artifact

Per `pr-comments.md` Inline Comment Policy. Append each to `$ARTEFACTS_DIR/inline_comments.txt` as pipe-delimited: `path/to/file|42|**[BLOCKER]** summary — fix`.

---

## Step 15: Post PR review

```bash
_OUT=$(ARTEFACTS_DIR="$ARTEFACTS_DIR" bash code-review/scripts/post_pr_review.sh)
# → PR_COMMENT_POSTED, PR_INLINE_COUNT
```

If `PR_COMMENT_POSTED=false`: no PR detected or gh unavailable — CLI output from Step 14 is the only delivery. Continue normally.

---

## Step 16: Persist review state

After the final report is complete, write `findings.yaml` to `$ARTEFACTS_DIR`, then call the persistence script.

### 16.1 Write findings.yaml

Write **all deduplicated findings from Step 13.1** (main-review, specialists, red-team, SO, PR comments) to `$ARTEFACTS_DIR/findings.yaml` as a YAML list:
```yaml
- severity: BLOCKER
  confidence: high
  file: "src/auth/login.ts:42"
  summary: "No rate limit on login"
  source: main-review
  fingerprint: "BLOCKER|src/auth/login.ts:42|No rate limit on login"
```

Then normalize any missing confidence fields and enforce proof-shape rule:
```bash
bash code-review/scripts/normalize_confidence.sh "$ARTEFACTS_DIR/findings.yaml"
bash code-review/scripts/downgrade_blockers.sh "$ARTEFACTS_DIR/findings.yaml"
```

### 16.2 Invoke write_review_state.sh

**no-change mode** (called from Step 5 early exit — no ARTEFACTS_DIR needed):
```bash
REVIEW_MODE="no-change" bash code-review/scripts/write_review_state.sh
```

**Normal mode** (full / incremental / full-fallback):
```bash
ARTEFACTS_DIR="$ARTEFACTS_DIR" \
SPECIALISTS_RUN="<comma-separated names or empty>" \
BASE_BRANCH="$BASE_BRANCH" \
STARTED_AT="<ISO timestamp>" \
REVIEW_MODE="$REVIEW_MODE" \
bash code-review/scripts/write_review_state.sh
```

The script prints `REVIEW_STATE_WRITTEN: <path>` or `REVIEW_STATE_WARNING: ...`. Always exits 0 — a failed write never blocks the review.

---

## Suppressions

Suppress: harmless redundancy, "add a comment" noise, tighter-assertion nitpicks when behavior is covered, consistency-only suggestions, regex edge cases that cannot occur, harmless no-ops, anything already addressed in diff.

---

## Error handling

Any specialist/red-team/second-opinion/PR-comment failure → continue with remaining sources, record the failure, reduce confidence if warranted. No diff → stop.
