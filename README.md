# agentic-skills

A personal repository of reusable Claude Code skills.

## Skills

| Skill | Description |
|-------|-------------|
| `change-review` | Execution-grade diff reviewer with specialist dispatch, red-team adversarial review, and cross-review. |
| `cross-review` | External review sub-skill (Codex / Gemini). Invoked by `change-review`, not directly. |
| `git-commit` | Creates conventional git commits with structured messages. |
| `github-pr` | Opens GitHub pull requests with title, summary, and test plan. |
| `jira-adf-writer` | Writes and fixes Jira rich-text fields using ADF. Prevents raw markdown and literal `\n` in the Jira UI. |

## Install

```bash
git clone <repo-url>
cd agentic_skills

# Install all skills
./install.sh

# Install a single skill
./install.sh -s <skill_name>
```

Skills are installed to `~/.agents/skills/<skill-name>/` (full copy).
`~/.claude/skills/<skill-name>` is a symlink pointing to the installed copy -- this is how Claude Code discovers them.

Restart Claude Code after installing or updating skills.

## Usage

```
/change-review
/git-commit
/github-pr
/jira-adf-writer
```

---

## change-review

Execution-grade diff reviewer with specialist dispatch, red-team adversarial review, and cross-review (Codex/Gemini).

### When it triggers

- "review my PR / diff / branch"
- "check this branch against main"
- "is this commit/PR ready to merge"
- "review these PR comments"

### What it does

1. Detects base branch and prior review state (full / incremental / carry-forward)
2. Gathers diff artifacts into a per-run temp directory
3. Classifies risk (LOW / MEDIUM / HIGH) and builds a review plan
4. Runs main structured review against the checklist
5. Dispatches specialist agents (security, testing, performance, data-migration, api-contract, maintainability) based on risk and file signals
6. Runs red-team adversarial review on HIGH-risk diffs
7. Optionally invokes `cross-review` for an independent external opinion
8. Triages PR comments if a PR exists
9. Merges, deduplicates, and classifies all findings
10. Produces a structured report with confidence score and merge stance

### Key files

| File | Purpose |
|------|---------|
| `change-review/SKILL.md` | Full execution contract (the authoritative reference) |
| `change-review/checklist.md` | Main review checklist |
| `change-review/output-format.md` | Report format, scoring model, severity language |
| `change-review/fix-policy.md` | Finding classification rules |
| `change-review/pr-comments.md` | PR inline comment policy |
| `change-review/specialists/` | Specialist prompts + `CONTRACT.md` |
| `change-review/scripts/` | Shell helpers (context gathering, scope detection, state persistence) |

---

## cross-review

External review sub-skill that invokes Codex or Gemini on the diff and normalizes findings to YAML. Not invoked directly -- `change-review` calls it when risk warrants it.

### Setup

1. Install the external tool:
   - **Codex:** `npm install -g @openai/codex` then `codex login`
   - **Gemini:** `npm install -g @google/gemini-cli`

2. Set the tool via environment variable:
   ```bash
   # Gemini
   export CROSS_REVIEW_TOOL=gemini
   export CROSS_REVIEW_MODEL=gemini-2.5-pro   # optional
   export CROSS_REVIEW_TIMEOUT=300             # optional

   # Codex
   export CROSS_REVIEW_TOOL=codex
   export CROSS_REVIEW_MODEL=o4-mini           # optional
   ```

3. No config files needed. Cross-review is configured entirely through environment variables.

### Environment variables

| Env var | Values | Default | Description |
|---------|--------|---------|-------------|
| `CROSS_REVIEW_TOOL` | `none` / `codex` / `gemini` | `none` | Set to enable cross-review |
| `CROSS_REVIEW_MODEL` | model name string | tool default | Optional model override |
| `CROSS_REVIEW_TIMEOUT` | seconds | `300` | Tool timeout (5 minutes) |

Cross-review does **not** use config files. No JSON, no `.claude/` or `.agents/` lookup. Env vars only.

When `CROSS_REVIEW_TOOL=none` (default) or the tool binary is not installed, cross-review is skipped silently.

### How it works

1. Reads env vars directly (`CROSS_REVIEW_TOOL`, `CROSS_REVIEW_MODEL`, `CROSS_REVIEW_TIMEOUT`)
2. Invokes the selected tool (Codex or Gemini) with the diff and a structured review prompt
3. Parses raw output into normalized YAML findings via `cross-review/scripts/parse.sh`
4. Writes artifacts to `$ARTEFACTS_DIR`: `cross_review_structured.yaml`, `cross_review_structured.txt`, `cross_review_status.txt`
5. Reports status via stdout signals (`CROSS_REVIEW_TOOL`, `CROSS_REVIEW_MODEL`, `CROSS_REVIEW_STATUS`)

### Timeout

Both tools get 5 minutes (`CROSS_REVIEW_TIMEOUT=300`, overridable via env). If the tool exceeds the timeout, `CROSS_REVIEW_STATUS=timed-out` and partial output is preserved.

### Key files

| File | Purpose |
|------|---------|
| `cross-review/SKILL.md` | Full execution contract |
| `cross-review/scripts/run.sh` | Entry point |
| `cross-review/scripts/structured.sh` | Tool invocation and capture |
| `cross-review/scripts/parse.sh` | Raw output to YAML parser |
| `cross-review/prompts/` | Boundary and structured review prompts |

---

## Adding a Skill

1. Create `<skill-name>/SKILL.md` at the repo root
2. Follow conventions in `CLAUDE.md`
3. Run `./install.sh` or `./install.sh -s <skill-name>`
4. Commit and push
