# Skill Repository Conventions

This file defines rules for maintaining skills in this repository.

---

## Directory Layout

Every skill must live at:

```
.claude/skills/<skill-name>/SKILL.md
```

No other locations. No subdirectories within a skill folder (keep it flat unless the skill explicitly requires supporting files).

---

## Naming Conventions

- Folder name: `kebab-case`, lowercase, no spaces
- Folder name must match the skill's intended invocation name
- Be specific: `jira-adf-writer` not `jira` or `writer`
- Avoid version suffixes (`-v2`). Evolve in place and use git history.

---

## Skill Requirements

Every skill must be:

- **Atomic** — one focused responsibility. If a skill does two unrelated things, split it.
- **Reusable** — no hardcoded project names, team names, or environment-specific values unless the skill is explicitly intended for a single project.
- **Readable** — a human unfamiliar with the context must be able to understand what the skill does by reading `SKILL.md`.
- **Deterministic** — given the same inputs, the skill must produce the same behavior. Avoid vague instructions like "do your best" or "be creative".
- **Scoped** — clearly define what the skill does *not* do in a "Do NOT use for" or "Scope Boundary" section.

---

## SKILL.md Structure

Recommended sections (adapt as needed):

```
# <Skill Name>

## Description
One paragraph. What this skill does and when to use it.

## When to Use / Do NOT Use For
Clear inclusion and exclusion criteria.

## Inputs Required
Table of required inputs.

## Guardrails
Hard rules Claude must follow when executing this skill.

## Workflow
Step-by-step instructions.

## Validation Checklist
Checklist Claude runs after completing the skill.
```

Not all sections are required for every skill. Keep only what's useful.

---

## Maintenance Rules

- When a skill changes behavior, update `SKILL.md` in the same commit.
- Do not leave stale examples or outdated workflows in the file.
- If a skill is retired, delete its folder entirely — don't leave dead code.
- Keep skills independent. Skills should not import or call each other unless explicitly designed to compose.

---

## Review Checklist (Before Adding a New Skill)

- [ ] The skill has a single, clearly defined responsibility
- [ ] The folder name is kebab-case and matches the invocation name
- [ ] `SKILL.md` contains at minimum: description, when to use, guardrails
- [ ] No hardcoded project-specific references (unless intentional)
- [ ] Workflow steps are explicit and deterministic — no ambiguous instructions
- [ ] Scope boundary is defined (what the skill does NOT do)
- [ ] `install.sh` was run to verify local install works
- [ ] `README.md` skills table updated

---

## What Does Not Belong Here

- Project-specific automation that only works in one repo
- Skills that duplicate built-in Claude Code behavior
- Workflow documentation that belongs in a project's own `CLAUDE.md`
