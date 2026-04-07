# Code Review System Roadmap

## Current Status

Phase 1 is complete and in active real-world trial. The system performs execution-grade diff review with:

- Full / incremental / full-fallback reviewability based on prior session state
- Carry-forward fingerprints for tracking findings across sessions
- Cross-review integration (Codex / Gemini) with structured YAML parsing
- PR comment persistence and triage
- Confidence field (`high | medium | low`) in finding schema with rendering suppression for `low`
- BLOCKER proof enforcement: vague BLOCKERs downgraded by script before persistence and by LLM instruction at merge
- Red-team adversarial specialist with updated routing (size gate removed, dual signal gate retained)
- `_slice()` hunk-content matching: specialist token cost reduced by excluding files with matching headers but no matching diff content
- Lightweight plan coverage: first qualifying source, ≥2-item threshold, future-work marker exclusion
- Security guidance upgrade: IDOR, second-order injection, JWT anti-patterns, privilege-escalating mass-assignment, env-dict poisoning

The system is structurally stable. The trial period exists to discover what breaks in the wild.

---

## Phase 2 — Trial Feedback and Accuracy Hardening

Phase 2 work should not start until trial evidence reveals the actual pain points. The items below are the most likely candidates based on current architecture gaps.

### 2.1 Cross-Session Learnings

**Problem:** Each review run starts from scratch. File-level, repo-level, and team-level context accumulated across prior reviews is discarded. The system re-derives risk classification, specialist routing, and finding significance without any memory of what has mattered in this repo before.

**Why the current system still needs it:** Fingerprint carry-forward tracks *whether* a finding was seen before, but not *why it matters in this repo*, which specialist signals tend to fire here, or whether the RISK classification has historically been accurate.

**Proposed shape:** A lightweight `.claude/review-learnings.json` written by `write_review_state.sh`. Contains: per-repo RISK classification history (last 20 runs), specialist-hit rates (which specialists produced findings in this repo), and any user-confirmed suppressions. The orchestrator reads this in Step 6 and uses it to bias specialist pre-filter thresholds. No LLM call needed — pure signal aggregation.

**Risks / trade-offs:** Risk of stale learnings skewing routing after repo changes direction. Mitigate with a TTL (stale after 90 days or after a branch with >1000-line diff). Keep the file small and human-readable so it can be inspected or manually corrected.

**Done:** `write_review_state.sh` writes a learnings record per run. `detect_scope.sh` reads it and can lower specialist thresholds when a specialist has had a >50% hit rate in the last 10 runs for this repo.

---

### 2.2 Confidence-Based Report Filtering Refinement

**Problem:** The current confidence model is correct in principle but coarse in practice. All findings default to `medium` from parse.sh, meaning most SO findings land in the report without differentiation. The `low` suppression is the only active filter. There is no way to tune what a `medium` finding means across different risk levels or diff sizes.

**Why the current system still needs it:** On a LOW-risk diff, a `medium`-confidence WARNING creates noise. On a HIGH-risk diff, a `medium`-confidence WARNING deserves full visibility. The same label serves both cases without distinguishing them.

**Proposed shape:** Introduce a per-risk-level confidence floor in `output-format.md`. LOW risk: suppress `medium` findings from Key Findings table (demote to a "Additional Observations" section or omit entirely). MEDIUM risk: render medium with marker. HIGH risk: render medium without marker (treat as high for display). This is a report-rendering rule, not a schema change.

**Risks / trade-offs:** May suppress real findings on LOW-risk diffs. Acceptable if the alternative is noise that degrades trust. Low implementation complexity — affects only Step 14.1 rendering logic.

**Done:** output-format.md defines per-risk-level rendering floors. A LOW-risk diff with only `medium`-confidence WARNINGs produces a clean summary paragraph instead of a noisy Key Findings table.

---

### 2.3 False-Positive Suppression Memory

**Problem:** When a reviewer dismisses a finding as a false positive, the system will re-raise it on every subsequent review. There is no mechanism to record "this finding was reviewed and is acceptable in this codebase."

**Why the current system still needs it:** Without suppression memory, trust degrades fast. Reviewers start ignoring the table entirely when they see the same stale findings repeated.

**Proposed shape:** A `.claude/review-suppressions.json` file. Schema: `[{ "fingerprint": "...", "reason": "...", "suppressed_by": "...", "suppressed_at": "..." }]`. Suppressions are applied at Step 13.1 before classification — matching fingerprints are excluded from the merged set. The file is created manually or by a future `/review suppress <fingerprint>` command. No automated suppression — a human must make the call.

**Risks / trade-offs:** Wrong suppressions hide real issues. Mitigate by including a `reason` field (required) and logging suppressed count in the report footer. Do not apply suppressions to BLOCKERs unless the suppressor explicitly flags `"override_blocker": true`.

**Done:** Step 13.1 reads suppressions, excludes matching findings, logs `SUPPRESSED: N findings` in report footer. Suppression file is documented with schema and example.

---

### 2.4 Review Telemetry / Cost Tracking

**Problem:** There is no visibility into how much each review costs in tokens, which specialists fire most, or whether cross-review runs frequently time out or produce value. Operating blind makes it hard to justify cost or tune routing.

**Why the current system still needs it:** Real-world trials will immediately raise the question "is this worth it?" without a way to answer it objectively.

**Proposed shape:** Each run appends a one-line JSON record to `~/.claude/review-telemetry.jsonl`. Fields: `project`, `sha`, `risk`, `specialists_run`, `red_team_ran`, `cross_review_ran`, `cross_review_status`, `cross_review_tool`, `finding_count`, `blocker_count`, `warning_count`, `downgraded_blockers`, `suppressed_count`, `diff_lines`, `timestamp`. No LLM call — all fields derivable from existing stdout signals. A separate `rtk` or shell command can aggregate the file on demand. No dashboard, no pipeline.

**Risks / trade-offs:** JSONL file grows unboundedly. Mitigate: rotate at 1000 records. Privacy: only project key (not file contents) is logged.

**Done:** `write_review_state.sh` appends to `~/.claude/review-telemetry.jsonl`. `wc -l` on the file confirms records are being written after a trial run.

---

## Phase 3 — Calibration and Synthesis

Phase 3 items require evidence from Phase 2 trials before they are worth building. They are described here so the rationale and unlock conditions are recorded.

### 3.1 Repo-Specific Calibration

**Problem:** Risk classification and specialist routing use fixed patterns (auth, migrations, shell, etc.) that are repo-agnostic. A repo where every PR touches auth files will route every run as HIGH even when the auth changes are trivial.

**Why not now:** The current routing has not been shown to be wrong in practice yet. Calibration without trial data is speculation.

**What would unlock it:** Telemetry from 2.4 shows a repo consistently classified as HIGH but with a low BLOCKER rate. Cross-session learnings from 2.1 provide per-repo hit rates to base calibration on.

### 3.2 Richer Plan-Completion Auditing

**Problem:** Plan coverage (Step 6) uses keyword grep against the diff patch. This is fast but imprecise. A TODOS.md item like "Add retry logic for flaky jobs" requires semantic matching that keyword grep misses if the diff uses different terminology.

**Why not now:** Keyword grep is cheap and covers the obvious cases. The semantic gap only matters if plan coverage is surfacing false `NOT DONE` results frequently — which is unknown without trial data.

**What would unlock it:** Trial reports showing plan coverage producing wrong NOT DONE verdicts. If reviewers are manually correcting these, it's worth investing in richer matching (embedding-based or targeted LLM call per item).

### 3.3 Specialist Routing Refinement

**Problem:** Specialist selection is file-pattern-based. A PR that touches `service.ts` with a 5-line logging change triggers the security specialist via `_ISC_BACKEND` + `DIFF_TOTAL > 100` even though there is nothing security-relevant in the diff.

**Why not now:** The `_slice()` hunk-content matching already mitigates this by giving specialists a filtered slice rather than the full diff. Routing might be slightly loose, but specialist token cost is bounded.

**What would unlock it:** Telemetry showing a specialist was dispatched in >80% of runs but produced zero findings >60% of the time. That specific specialist+signal combination can be tightened.

### 3.4 Better Cross-Model Synthesis

**Problem:** When the main review and cross-review disagree on severity (main says WARNING, cross-review says BLOCKER for the same fingerprint), the current system keeps the higher severity with a multi-confirmed annotation. It does not attempt to synthesize the disagreement.

**Why not now:** The disagreement case is rare and the conservative choice (keep higher severity) is correct. Adding synthesis complexity without evidence that disagreement causes noise is premature.

**What would unlock it:** Trial reports showing multi-confirmed severity mismatches that are routinely dismissed by reviewers. If cross-review is consistently inflating severity, the synthesis rule should bias toward the lower severity when the main review's evidence is stronger.

---

## Longer-Term Ideas / Optional Bets

These should not be built unless real-world evidence from trials justifies them.

**Learning from reviewer resolutions.** Track which findings reviewers accepted vs. ignored across sessions. Use acceptance rate per finding category to bias severity or confidence in future runs. Requires a resolution signal (manual or via PR state) that does not exist yet. High value if the signal is available; do not build the infrastructure speculatively.

**Confidence calibration against reviewer outcomes.** Tune what `high | medium | low` means based on whether high-confidence findings were actually correct. Requires resolved-finding data. Same dependency as above.

**Org-wide pattern memory.** Share suppression and learning state across a team's repos. Requires a shared service or synced file, which introduces coordination complexity and a trust boundary (one repo's suppression should not apply to another). Justified only if multiple repos with the same team are using the system and showing repeated false positives on the same patterns.

**Opt-in fix-first mode.** For mechanically fixable findings (unused imports, obvious null guards, simple enum gaps), apply the fix in a draft commit before the report. High complexity. Risk of unintended changes. Do not build unless reviewers are explicitly asking for it and the fix scope is provably narrow.

**GitLab support.** The system uses `gh` for PR metadata and comment posting. GitLab would require a parallel implementation of `gather_context.sh` and `post_pr_review.sh`. Justified if there is a concrete user need — not speculatively.

**Advanced telemetry / cost dashboard.** A web UI or structured report over the JSONL telemetry file. Do not build. Shell scripting over JSONL is sufficient for internal use.

---

## Explicit Non-Goals

These are intentionally out of scope and should not be revisited without a concrete forcing function.

- **No auto-fix by default.** The system identifies and recommends. It does not apply changes. This is a fundamental trust boundary.
- **No preamble bloat.** The orchestrator does not ask for confirmation, does not summarize its plan, does not recap what it found at the end. It starts, runs, and stops.
- **No fake quality scoring.** The confidence score (X/5) is based on finding severity, not a trained model or calibrated metric. It should not be presented as a precise measurement.
- **No giant planning subsystem.** Step 6 plan coverage is a lightweight keyword check, not a requirements-tracking system.
- **No speculative enterprise abstractions.** No multi-tenant config, no org hierarchy, no role-based access, no plugin architecture, no API server. This is a CLI tool.
- **No broad telemetry pipeline.** The JSONL file is the telemetry surface. If it needs to become a pipeline, that decision should follow from evidence, not be built preemptively.
- **No reviewer-facing UX beyond the report.** No web interface, no notification system, no Slack-native review flow unless a specific integration justifies the maintenance cost.

---

## Exit Criteria for the Trial Period

The trial period is complete when:

1. At least 10 full reviews have been run against real PRs in at least 2 different repos.
2. The BLOCKER downgrade rate is measured: what percentage of original BLOCKERs are being downgraded? If >40%, the proof heuristic is too aggressive. If <5%, it may be too lenient.
3. The cross-review hit rate is measured: in what percentage of HIGH/MEDIUM_SHARP runs does SO produce at least one finding not already in the main review? If <10%, SO's signal-to-noise may not justify its latency cost.
4. At least one false-positive has been identified that a suppression mechanism would have prevented.
5. The red-team has run on at least 3 HIGH-risk incremental diffs. Was it useful? Did it find anything the other specialists missed?

If these data points do not reveal a clear pain point, Phase 2 items should be deprioritized accordingly.

---

## Recommended Order of Execution

**1. Review Telemetry / Cost Tracking (2.4)**
Build this first. It is the foundation for every other prioritization decision. Without telemetry, Phase 2 and Phase 3 decisions are guesswork. Low implementation risk — pure signal aggregation in `write_review_state.sh`. No LLM call, no schema change, no routing change.

**2. False-Positive Suppression Memory (2.3)**
Highest impact on reviewer trust. A repeated false positive is more damaging to adoption than a missed true positive. The file-based approach is simple, auditable, and requires no new infrastructure. Implement before telemetry reveals suppression demand — it is the most predictable need.

**3. Confidence-Based Report Filtering Refinement (2.2)**
Second-highest impact on review accuracy (by reducing noise on low-risk diffs). Low implementation risk — affects only Step 14.1 rendering logic and `output-format.md`. Should wait until at least 5 trial runs produce data on whether LOW-risk diffs are generating noisy `medium` tables.

**4. Cross-Session Learnings (2.1)**
Highest long-term impact on specialist routing quality. Higher implementation risk than the others — introduces a persistent file that can skew routing if it goes stale. Should follow after telemetry shows which specialists are being over-dispatched or consistently producing zero findings.

**Phase 3 items** depend on Phase 2 telemetry revealing specific calibration failures. Do not sequence them until the trial period exit criteria are met.
