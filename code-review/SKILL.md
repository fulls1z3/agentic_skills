---
name: code-review
description: Use when the user asks to review a diff, check a PR, sanity-check a branch, assess commit/PR readiness, find bugs/regressions/missing tests, review PR comments, or fix issues found during review. Performs execution-grade review with fix-first policy, specialist dispatch, adversarial pass, and configurable second opinion.
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

## Principles
- Fix what is safe. Escalate only when behavior intent is unclear, fix is security/concurrency-sensitive, change is broad, or user-visible behavior would change.
- Token-aware: graduated depth by risk.
- Same-session self-review is weaker — say so.
- No finding cap.
- Green tests ≠ safe. Races, stale reads, enum gaps, silent corruption, bad retry logic survive CI.

---

## Step 0: Detect base branch

```bash
eval $(bash code-review/bin/detect_base.sh)
echo "BASE_BRANCH: $BASE_BRANCH"
```

---

## Step 1: Check diff exists

```bash
git fetch origin "$BASE_BRANCH" --quiet 2>/dev/null || true
git diff "origin/$BASE_BRANCH...HEAD" --stat
```

If no meaningful diff: `Nothing to review — no branch diff against $BASE_BRANCH.` Stop.

---

## Step 2: Gather context artefacts

```bash
eval $(bash code-review/bin/gather_context.sh "$BASE_BRANCH")
```

Produces: `/tmp/code-review/{diff.patch,changed_files.txt,diff_stat.txt,pr.json,commits.txt,diff_total.txt,uncommitted.txt}`

Read:

* `/tmp/code-review/pr.json`
* `/tmp/code-review/commits.txt`
* `/tmp/code-review/uncommitted.txt`

If uncommitted changes exist, note them.

---

## Step 3: Determine intent and scope

From:

* branch name
* commits (`/tmp/code-review/commits.txt`)
* PR title/body (`/tmp/code-review/pr.json`)
* `TODOS.md` if present

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

---

## Step 4: Classify risk and build review plan

```bash
eval $(bash code-review/bin/detect_scope.sh "$BASE_BRANCH")
```

Reads context from `/tmp/code-review/`. Writes:

* `/tmp/code-review/context.json`
* `/tmp/code-review/review_plan.json`

Load plan:

```bash
cat /tmp/code-review/review_plan.json
```

Risk levels:

* **LOW** — comments, copy, doc-only, trivial non-behavioral refactor
* **MEDIUM** — backend logic, API changes, persistence, state transitions, jobs, retries, validation, non-trivial frontend
* **HIGH** — auth/authz, migrations, money/payments, shell/tool execution, destructive writes, CI/CD, concurrency, security, LLM output persisted/executed

Print: `Risk Level: <RISK>`

Execution matrix (from `review_plan.json`):

| Component                    | LOW (tiny) | LOW      | MEDIUM    | MED_SHARP | HIGH |
| ---------------------------- | ---------- | -------- | --------- | --------- | ---- |
| Main structured review       | ✓          | ✓        | ✓         | ✓         | ✓    |
| Selected specialists         | —          | if scope | ✓         | ✓         | ✓    |
| Red-team specialist          | —          | —        | if behav. | ✓         | ✓    |
| Local adversarial synthesis  | ✓          | ✓        | ✓         | ✓         | ✓    |
| Second opinion (structured)  | —          | —        | —         | ✓         | ✓    |
| Second opinion (adversarial) | —          | —        | —         | —         | ✓    |
| Second opinion offer         | —          | —        | if finds  | —         | —    |

---

## Step 5: Main structured review

Read:

* `code-review/checklist.md`

Review diff (`/tmp/code-review/diff.patch`) and directly related code. Read outside diff when needed.

Finding contract — for every finding:

* severity: `BLOCKER | WARNING | NIT`
* confidence: `high | medium | low`
* file:line
* summary
* why it matters
* recommended fix
* source: `main-review`

Do not report speculation as fact. Do not suppress risk because tests pass. Use WebSearch when framework behavior is uncertain.

---

## Step 6: Specialist dispatch

### 6.1 Read contract

```bash
cat code-review/specialists/CONTRACT.md
```

### 6.2 Select specialists

From `review_plan.json -> run_specialists[]`. Skip all for very tiny diffs.

Print:

* `Specialists Dispatched: [...]`
* `Specialists Skipped: [...] (reason)`

### 6.3 Dispatch in parallel

Launch all via Agent tool in a single message. Each specialist must:

1. Read `code-review/specialists/CONTRACT.md` and its own specialist file
2. Read `/tmp/code-review/diff.patch` and nearby code
3. Output JSONL only, or `NO FINDINGS`

### 6.4 Merge and deduplicate

Parse JSONL, dedupe by fingerprint, tag multi-confirmed, keep best evidence.

---

## Step 7: Local adversarial review

### 7.1 Red-team specialist

Run when `review_plan.json -> run_red_team = true`.

Dispatch:

* `code-review/specialists/red-team.md`
* `code-review/specialists/CONTRACT.md`

Pass diff path `/tmp/code-review/diff.patch`. Output JSONL.

### 7.2 Local adversarial synthesis

Always runs. Explicitly interrogate:

* What breaks on retry?
* What breaks on concurrent requests?
* What breaks under partial failure?
* What breaks if external deps return garbage or timeout?
* What breaks on empty state / first run / stale state?
* What breaks even if CI is green?

Source: `claude-adversarial`.

---

## Step 8: PR comment triage (lazy-loaded)

```bash
eval $(bash code-review/bin/pr_comment_count.sh)
```

* No PR → skip
* `COMMENT_COUNT=0` → skip
* Comments exist → read `code-review/pr-comments.md`, classify, triage

---

## Step 9: Independent second opinion

### 9.1 When to run

From `review_plan.json -> second_opinion_mode`:

* `none` → skip
* `offer-if-findings` → plain MEDIUM: after full report, if BLOCKER or WARNING findings exist, present interactive offer
* `structured` → MEDIUM_SHARP: run Step 9.4 automatically
* `structured+adversarial` → HIGH: run Steps 9.4 and 9.5 automatically

Also read:

* `review_plan.json -> second_opinion_tool_required`

### 9.2 Resolve config

```bash
eval $(bash code-review/bin/resolve_second_opinion.sh)
# SO_TOOL, SO_TIMEOUT, MODEL_FLAG now set
```

If `SO_TOOL=none`:

* Continue without second opinion
* Record that independent evaluator did not run
* If `second_opinion_tool_required=true`, PR readiness ≤ `READY WITH WARNINGS`

### 9.3 Plain MEDIUM interactive offer

After the initial findings, if:

* `second_opinion_mode=offer-if-findings`
* and BLOCKER or WARNING findings exist

prompt the user:

```text
This is a medium-risk diff with findings. An independent $SO_TOOL review may still catch something I missed.

1) Yes — run second opinion now
2) No — current review is enough
3) Chat first — discuss findings before deciding
```

Behavior:

* **1** → proceed to Step 9.4 (structured only, no adversarial). Do not re-run earlier steps.
* **2** → finalize report, skip second opinion.
* **3** → finalize current report without second opinion. Do not claim resumable execution as guaranteed. If the user later asks for a second opinion, re-run the second-opinion path using the current branch state and available artefacts.

### 9.4 Structured review

```bash
bash code-review/bin/run_second_opinion_structured.sh "$BASE_BRANCH"
# Output: /tmp/code-review/so_structured.txt
```

Timeout: `$SO_TIMEOUT` on the Bash call.

Parse output:

* `[P1]` or `BLOCKER` found → gate FAIL
* otherwise → gate PASS

Preserve full output for report.

### 9.5 Adversarial review (HIGH only)

```bash
bash code-review/bin/run_second_opinion_adversarial.sh "$BASE_BRANCH"
# Output: /tmp/code-review/so_adversarial.txt
```

Timeout: `$SO_TIMEOUT`.

### 9.6 Distraction detection

Scan output for:

* `.claude/skills`
* `SKILL.md`
* `agents/`
* prompt templates

If detected: warn, do not count as valid second opinion.

### 9.7 Merge findings

Dedupe against existing findings, mark overlap as multi-confirmed, auto-fix safe issues, report unresolved.

---

## Step 10: Fix-first execution

Read:

* `code-review/fix-policy.md`

### 10.1 Collect and classify

Merge all findings from:

* main review
* specialists
* red-team
* adversarial
* PR comments
* second opinion

Classify each:

* `AUTO-FIX`
* `MANUAL`
* `REPORT-ONLY`

### 10.2 Apply and escalate

* **AUTO-FIX**: apply directly, record file:line and what changed
* **MANUAL**: present to user with evidence and recommended fix
* **REPORT-ONLY**: include in unresolved issues

Do not commit.
Do not push.

### 10.3 Validate

Rerun focused validation where relevant:

* targeted tests
* lint
* typecheck

If you say “safe”, cite the line.
If you say “tested”, name the test.

---

## Step 11: Final report

Read:

* `code-review/output-format.md`

Include PR comment summary only if comment triage ran.

Verdict rules:

* Commit readiness: `READY | READY WITH WARNINGS | NOT READY`
* PR readiness: `READY | READY WITH WARNINGS | NOT READY`
* Review strength: `WEAK | STANDARD | STRONG`

Review strength:

* `WEAK` = same session likely wrote and reviewed
* `STANDARD` = strong review, no valid independent second opinion where required
* `STRONG` = review + local adversarial + valid second opinion where required

Hard rule:

* if `second_opinion_tool_required=true` and second opinion did not run successfully, PR readiness ≤ `READY WITH WARNINGS`, review strength ≠ `STRONG`

Weak-review warning:
`This change should get an independent second-pass review. Same-agent self-review is not strong enough here.`

Cross-model synthesis (if second opinion ran):

* tool used
* high-confidence overlap
* unique-to-Claude
* unique-to-second-opinion
* whether it materially changed the assessment

---

## Suppressions

* Harmless redundancy that aids readability
* “Add a comment for this threshold” style noise
* Tighter-assertion nitpicks when behavior is already covered
* Consistency-only suggestions with no correctness payoff
* Regex edge cases that cannot occur in real input
* Harmless no-ops
* Anything already addressed in the diff

---

## Error handling

* No diff → stop with clear message
* Specialist failure → continue with others, record it
* Red-team failure → continue, record it
* Second opinion tool missing → continue, reduce confidence as required
* Second opinion timeout → continue with main review, record timeout
* Second opinion auth failure → continue, record failure
* PR comments unavailable → continue without comment triage
