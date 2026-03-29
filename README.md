# agentic-skills

A personal repository of reusable Claude Code skills.

## Skills

| Skill | Description |
|-------|-------------|
| `git-commit` | Creates conventional git commits with structured messages. |
| `github-pr` | Opens GitHub pull requests with title, summary, and test plan. |
| `jira-adf-writer` | Writes and fixes Jira rich-text fields using ADF. Prevents raw markdown and literal `\n` in the Jira UI. |

## Install

```bash
git clone <repo-url>
cd agentic_skills
./install.sh
```

Copies all skills from `.claude/skills/` into `~/.claude/skills/`. Restart Claude Code after install.

## Usage

```
/git-commit
/github-pr
/jira-adf-writer
```

## Adding a Skill

1. Create `.claude/skills/<skill-name>/SKILL.md`
2. Follow conventions in `CLAUDE.md`
3. Run `./install.sh`
4. Commit and push
