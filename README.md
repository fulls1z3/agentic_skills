# agentic-skills

A personal repository of reusable Claude Code skills.

## Skills

| Skill | Description |
|-------|-------------|
| `change-review` | Execution-grade diff reviewer with specialist dispatch, red-team adversarial review, and config-driven cross-review. |
| `cross-review` | Config-driven external review sub-skill (Codex / Gemini). Invoked by `change-review`, not directly. |
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

Execution-grade diff reviewer with specialist dispatch, red-team adversarial review, and config-driven cross-review (Codex/Gemini).

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

Config-driven external review sub-skill that invokes Codex or Gemini on the diff and normalizes findings to YAML. Not invoked directly -- `change-review` calls it when risk warrants it.

### Setup

1. Copy the example config:
   ```bash
   cp cross-review/cross-review.example.json ~/.claude/cross-review.json
   ```

2. Edit `~/.claude/cross-review.json` -- set `"tool"` to `"codex"` or `"gemini"`, optionally set `"model"`:
   ```json
   {
       "tool": "codex"
   }
   ```

3. Install the external tool:
   - **Codex:** `npm install -g @openai/codex` then `codex login`
   - **Gemini:** `npm install -g @google/gemini-cli`

### Config resolution order

The config is resolved in this order (first match wins):

1. `CROSS_REVIEW_CONFIG` environment variable (path to JSON file)
2. `<repo>/.claude/cross-review.json`
3. `<repo>/.agents/cross-review.json`
4. `~/.claude/cross-review.json`
5. `~/.agents/cross-review.json`
6. Built-in defaults (`tool: "none"`)

### Config fields

| Field | Values | Default |
|-------|--------|---------|
| `tool` | `none` / `codex` / `gemini` | `none` |
| `model` | model name string (optional) | tool default |

When `tool` is `none` or the binary is not installed, cross-review is skipped silently.

### How it works

1. Resolves config via `cross-review/scripts/resolve.sh`
2. Invokes the external tool with the diff and a structured review prompt
3. Parses raw output into normalized YAML findings via `cross-review/scripts/parse.sh`
4. Writes artifacts to `$ARTEFACTS_DIR`: `so_structured.yaml`, `so_structured.txt`, `so_status.txt`
5. Reports status via stdout signals (`SO_TOOL`, `SO_MODEL`, `SO_STRUCTURED_STATUS`)

### Timeout

Both tools get 5 minutes (`SO_TIMEOUT=300`, overridable via env). If the tool exceeds the timeout, `SO_STRUCTURED_STATUS=timed-out` and partial output is preserved.

### Key files

| File | Purpose |
|------|---------|
| `cross-review/SKILL.md` | Full execution contract |
| `cross-review/cross-review.example.json` | Config template |
| `cross-review/scripts/run.sh` | Entry point |
| `cross-review/scripts/resolve.sh` | Config resolution |
| `cross-review/scripts/structured.sh` | Tool invocation and capture |
| `cross-review/scripts/parse.sh` | Raw output to YAML parser |
| `cross-review/prompts/` | Boundary and structured review prompts |

---

## Adding a Skill

1. Create `<skill-name>/SKILL.md` at the repo root
2. Follow conventions in `CLAUDE.md`
3. Run `./install.sh` or `./install.sh -s <skill-name>`
4. Commit and push
