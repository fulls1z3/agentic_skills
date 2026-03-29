---
name: github-pr
description: This skill should be used when the user asks to "open a PR", "create a pull request", "make a PR", "submit a PR", "update the PR", "push a PR", or says things like "open it up", "send it for review", "get this reviewed". Do NOT trigger when changes are not yet committed, when the user only wants a local commit, or when no GitHub remote is configured.
---

# Github PR Skill

## Goal
Create or update a clean PR and verify it was actually updated.

## When to Use

Use this skill when:
- All relevant changes are already committed and pushed
- The user explicitly asks to open, create, or update a PR
- A clean, structured PR description is needed

Do NOT use this skill when:
- Changes are not yet committed (use git-commit first)
- The branch is in a broken or untested state
- The user only needs local commits without a PR
- No GitHub remote is configured

### Preconditions
- If there are uncommitted changes, stop and instruct to use git-commit first
- If no GitHub remote is configured, stop and report that PR creation is not possible yet
- If gh CLI is unavailable or unauthenticated, stop and report the exact issue

## Steps
1. Determine base branch:
   - prefer main unless repo uses another default branch
2. Read diff:
   - git diff --stat origin/main...HEAD
   - git diff origin/main...HEAD
3. Produce PR body with sections:
   - Summary
   - Changes
   - Testing
   - Risks / Notes
4. If PR already exists:
   - update it with gh pr edit --body
5. If PR does not exist:
   - create it with gh pr create
6. Verify:
   - gh pr view --json number,title,body,url
7. Report:
   - PR URL
   - confirmed title
   - confirmed body sections
   - any gaps in testing

## Rules
- Never claim the PR was updated without verifying with gh pr view.
- Use gh CLI, not any alternative tool.
- Keep the PR description grounded in the actual diff.
- Do not include changes that are not present in the branch.