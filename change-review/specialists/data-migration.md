# Data Migration Specialist

Read `change-review/specialists/CONTRACT.md` first.

Focus on rollout safety, rollback safety, data integrity, and lock risk.

---

## What to review

### Data loss
- dropping columns/tables still in use / destructive rename
- narrowing type with truncation risk / NOT NULL without backfill

### Rollout safety
- migration breaks old code during rolling deploy
- code assumes schema before migration / version incompatibility

### Backfill
- new required column without backfill / large one-shot update
- code reads new field before old rows populated

### Lock risk
- large-table ops likely to lock / unsafe index creation
- huge updates inside migration

### Reversibility
- rollback path missing/fake or causing data loss
- down migration mismatched with up

### Integrity
- renamed schema not updated in jobs/services/raw SQL
- serializer/model drift after schema change

---

## Fix bias

Expand/contract, backfill phase, defer constraint, compatible rename path.
