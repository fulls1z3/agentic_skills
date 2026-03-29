---
name: jira-adf-writer
description: Use when writing or fixing Jira descriptions or comments in ADF format. Ensures correct rendering (no markdown, no literal \n, proper paragraph structure). Do NOT use for planning, issue creation, or non-rich-text fields.
---

See REFERENCE.md for detailed ADF examples and payload patterns.

# Jira ADF Writer Skill

## Goal
Write or fix Jira rich-text fields (description or comment) using valid ADF so content renders correctly.

---

## When to Use

Use when:
- Writing a Jira description or comment
- Fixing fields showing `\n`, `\\n`, or raw markdown like `**text**`
- Content appears as a single unreadable block

Do NOT use for:
- Issue creation or hierarchy planning
- PRDs or roadmap generation
- Any field other than description/comment

---

## Inputs Required

- cloudId
- issueIdOrKey
- targetField: description | comment
- rawContent (for write mode)

---

## Guardrails

- Only modify the requested field (description or comment)
- Preserve content exactly (no rewriting)
- Always use `contentFormat: adf`
- Never pass plain strings — always JSON ADF object
- Never include markdown syntax in text nodes
- For comments: create new comment unless explicitly told to edit existing

---

## Workflow

### Mode A — Write

1. Parse input into logical blocks
2. Normalize `\\n` and `\n` → real newlines
3. Build ADF document
4. Call:
   - description → editJiraIssue
   - comment → addCommentToJiraIssue
5. Fetch issue to verify
6. Validate output
7. Report result

---

### Mode B — Fix

1. Fetch current field (markdown format)
2. Confirm broken (see detection rules)
3. Normalize text and rebuild structure
4. Build ADF document
5. Update field (same as Mode A)
6. Fetch again and validate
7. Report what changed

---

## ADF Rules (non-negotiable)

- Use paragraph nodes for logical blocks
- Label + value must be in same paragraph node
- Use ADF marks for bold (not `**text**`)
- Do not use `\n` inside text nodes
- Normalize all newline variants before splitting

---

## Detection Rules

Field is broken if:
- Literal `\n` or `\\n` visible
- `**text**` appears instead of bold
- Single collapsed block > 200 chars

---

## Validation Checklist

- No `\n` or `\\n` visible
- No markdown syntax visible
- Content split into logical blocks
- Label/value not split across paragraphs
- Meaning unchanged
- Only target field modified

---

## Scope Boundary

Only operates on description/comment of a single issue.
Does not create issues or modify other fields.