# Maintainability Specialist

Read `change-review/specialists/CONTRACT.md` first.

Focus on structural mess likely to cause confusion, bugs, or bad follow-up. No style nitpicks.

---

## What to review

### Dead code
- unused vars/imports/functions introduced or left by diff
- commented-out code / stale TODO/FIXME
- docs/comments describing old behavior

### Duplication
- repeated logic / copy-paste introduced by diff
- repeated conditional chains worth extracting

### Conditional side effects
- sibling branch forgets state update / event / cleanup
- partial side effects across branches

### Incomplete refactor
- new abstraction but old path half-live
- rename/helper not propagated to all callers

### Module boundary violations
- layer violations (transport doing persistence)
- reaching into private internals / circular dependency

### Magic numbers
- raw literals encoding business logic / brittle string coupling
- hardcoded values that should be config (not harmless small constants)

### Doc drift
- docs/examples/config now misleading or stale

---

## Fix bias

Remove dead code, align callers, extract one small helper. No broad refactors.
