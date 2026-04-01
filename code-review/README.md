# code-review skill

Execution-grade code review with fix-first policy, specialist dispatch, adversarial pass, and configurable second opinion (Codex / Gemini).

## Setup

```bash
mkdir -p .claude
cp code-review/code-review.example.json .claude/code-review.json
```

Edit `.claude/code-review.json`:

```json
{
  "second-opinion-tool": "gemini",
  "second-opinion-model": "",
  "timeout": 300000
}
```

### Config fields

| Field | Values | Default | Notes |
|-------|--------|---------|-------|
| `second-opinion-tool` | `codex`, `gemini`, `auto`, `none` | `auto` | `auto` = first available: codex → gemini |
| `second-opinion-model` | model string or `""` | `""` | Empty = tool default. Passed as `-m` flag |
| `timeout` | ms | `300000` | Second opinion tool timeout |

### Tool install

**Codex:** `npm install -g @openai/codex` then `codex login`

**Gemini:** `npm install -g @google/gemini-cli` (or `npx @google/gemini-cli`)

## File structure

```
code-review/
├── SKILL.md                      # Orchestrator (lean DSL)
├── checklist.md                  # Review categories
├── fix-policy.md                 # Auto-fix / manual / report-only / test guardrails
├── output-format.md              # Report template (loaded in Step 11 only)
├── pr-comments.md                # PR comment triage (lazy-loaded)
├── code-review.example.json      # Config template
├── README.md                     # This file (not referenced at runtime)
├── bin/
│   ├── detect_base.sh            # → BASE_BRANCH
│   ├── gather_context.sh         # → /tmp/code-review/{diff.patch,changed_files.txt,...}
│   ├── detect_scope.sh           # → /tmp/code-review/{context.json,review_plan.json}
│   ├── pr_comment_count.sh       # → PR_NUMBER, COMMENT_COUNT
│   ├── resolve_second_opinion.sh # → SO_TOOL, MODEL_FLAG, SO_TIMEOUT
│   ├── run_second_opinion_structured.sh   # → /tmp/code-review/so_structured.txt
│   └── run_second_opinion_adversarial.sh  # → /tmp/code-review/so_adversarial.txt
├── prompts/
│   ├── boundary.txt              # Skill-file isolation prompt
│   ├── second_opinion_structured.txt
│   └── second_opinion_adversarial.txt
└── specialists/
    ├── CONTRACT.md
    ├── testing.md
    ├── maintainability.md
    ├── security.md
    ├── performance.md
    ├── data-migration.md
    ├── api-contract.md
    └── red-team.md
```

## Runtime artefacts (per run, in /tmp/code-review/)

```
/tmp/code-review/
├── diff.patch           # Full diff — used by all consumers, never embedded in prompts
├── changed_files.txt
├── diff_stat.txt
├── diff_total.txt
├── commits.txt
├── uncommitted.txt
├── pr.json
├── context.json         # Scope flags + risk metadata
├── review_plan.json     # Run/skip decisions for specialists, red-team, second opinion
├── so_config.sh         # Sourceable second opinion env vars
├── so_structured.txt    # Second opinion structured output
└── so_adversarial.txt   # Second opinion adversarial output (HIGH only)
```