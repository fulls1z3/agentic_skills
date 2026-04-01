# Maintainability Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review the diff (`/tmp/code-review/diff.patch`) and nearby code. Focus on structural mess likely to cause confusion, bugs, or bad follow-up changes. Do not nitpick style.

---

## What to review

### 1. Dead code and stale code
- unused vars/imports introduced by the diff
- functions or branches left behind after refactor
- commented-out code blocks
- stale TODO/FIXME comments
- docstrings/comments now describing old behavior

### 2. Duplication
- repeated logic blocks introduced by the diff
- copy-paste with only tiny variation
- repeated conditional chains that should be a local helper or lookup

Only flag when extraction is clearly worth it.

### 3. Conditional side effects
- one branch updates state, sibling branch forgets
- event/log/cleanup only on happy path
- partial side effects across sibling branches

### 4. Incomplete refactor shape
- new abstraction introduced but old path still half-live
- rename not propagated where it matters
- helper/service introduced but only some callers updated

### 5. Module boundary violations
- transport/presentation layer doing persistence/business work directly
- reaching into private-by-convention internals
- circular dependency introduced by the change

### 6. Magic numbers and string coupling
- raw literals that clearly encode business logic
- brittle cross-file string coupling
- hardcoded values that should be config or named constant

Do not flag harmless small constants.

### 7. Documentation drift caused by this branch
- developer docs now misleading
- examples/config snippets now stale

---

## Fix guidance bias

Prefer: remove dead code, delete stale comments, align obvious callers,
extract one small helper, replace repeated lookup with local map/helper.
Avoid broad refactors.