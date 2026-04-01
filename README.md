# agentic-skills

A personal repository of reusable Claude Code skills.

## Skills

| Skill | Description |
|-------|-------------|
| `code-review` | Code reviewer with second opinion. |
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
`~/.claude/skills/<skill-name>` is a symlink pointing to the installed copy — this is how Claude Code discovers them.

Restart Claude Code after installing or updating skills.

## Usage

```
/code-review
/git-commit
/github-pr
/jira-adf-writer
```

## Adding a Skill

1. Create `<skill-name>/SKILL.md` at the repo root
2. Follow conventions in `CLAUDE.md`
3. Run `./install.sh` or `./install.sh -s <skill-name>`
4. Commit and push
