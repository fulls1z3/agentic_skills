---
name: git-commit
description: This skill should be used when the user asks to "commit", "create a commit", "make a commit", "commit my changes", "commit and push", "push this", or says things like "save this", "ship it", or "wrap this up". This skill creates a clean scoped commit and pushes it. Do NOT trigger for partial work, mid-task checkpoints, or when the user says changes are not ready yet.
---

# Git Commit Skill

## Goal
Create a clean, scoped commit for the current task and push it to the current branch.

## When to Use

Use this skill when:
- Changes for the current task are complete and ready to be saved
- The user explicitly asks to commit or commit and push
- Preparing work for a PR
- The user wants the branch updated remotely

Do NOT use this skill when:
- Changes are still incomplete or experimental
- The user has not indicated the work is done
- Multiple logical changes need separate commits (handle manually)
- The user wants review or more edits before committing

## Steps
1. Check current branch:
   - git branch --show-current

   If on main or master:
   - create a new branch using:
     git checkout -b <type>/<short-description>
   - continue on that branch
2. Inspect changed files with:
   - git status --short
   - git diff --name-only
3. Stage only files directly relevant to the task.
4. Before committing, check for obvious validation commands:
   - if manage.py exists: python manage.py test -q
   - if package.json exists: npm test --silent
   - if go.mod exists: go test ./...
5. Write a conventional commit message:
   - feat:
   - fix:
   - docs:
   - refactor:
   - test:
   - chore:
6. Commit.
7. Push to the current branch.
8. Never force-push unless the user explicitly says so.
9. Report:
   - staged files
   - commit message
   - push result

## Rules
- Do not stage unrelated files.
- Do not widen scope.
- Do not ask for confirmation unless the task scope is genuinely ambiguous.
- If push fails, report the exact error instead of claiming success.
- Never claim the commit or push succeeded without reading back the result from git output.