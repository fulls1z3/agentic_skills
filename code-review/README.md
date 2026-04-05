# code-review

Execution-grade diff reviewer with specialist dispatch, red-team adversarial review, and config-driven second opinion.

## Quickstart

```bash
cd /path/to/your/repo
# review current branch against detected base
/review
```

## Key files

| File | Purpose |
|------|---------|
| `SKILL.md` | Execution contract |
| `checklist.md` | Main review checklist |
| `specialists/` | Specialist prompts + CONTRACT.md |
| `scripts/` | Shell helpers |
| `pr-comments.md` | Inline comment policy |
