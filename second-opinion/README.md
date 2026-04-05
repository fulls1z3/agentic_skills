# second-opinion

Config-driven second-opinion sub-skill for `code-review`. Not invoked directly.

## Setup

```bash
cp second-opinion/second-opinion.example.json ~/.claude/second-opinion.json
# edit: set "tool" to "codex" or "gemini", optionally set "model"
```

**Codex:** `npm install -g @openai/codex` then `codex login`
**Gemini:** `npm install -g @google/gemini-cli`

## Key files

| File | Purpose |
|------|---------|
| `scripts/run.sh` | Entry point |
| `second-opinion.example.json` | Config template |
