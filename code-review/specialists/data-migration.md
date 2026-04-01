# Data Migration Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review migration files, schema changes, and affected application code (`/tmp/code-review/diff.patch`). Focus on rollout safety, rollback safety, data integrity, and lock risk.

---

## What to review

### 1. Data loss risk
- dropping columns/tables still plausibly in use
- destructive rename without compatibility phase
- narrowing type/length with truncation risk
- NOT NULL added without backfill/default plan

### 2. Multi-phase rollout safety
- migration that breaks old code during rolling deploy
- code assuming schema exists before migration lands
- mixed old/new versions becoming incompatible

### 3. Backfill and existing data
- new required column without backfill strategy
- one-shot update over large table
- application code reading new field before old rows are populated

### 4. Lock and runtime risk
- large-table operations likely to lock hard
- unsafe index creation strategy
- huge updates inside migration

### 5. Reversibility
- rollback path missing or fake
- rollback causing data loss
- down migration not matching up migration intent

### 6. Integrity and reference updates
- renamed schema not updated everywhere
- jobs/services/raw SQL still referencing old schema
- serializer/model drift after schema change

---

## Fix guidance bias

Prefer: expand/contract, add backfill phase, defer constraint until data is ready,
compatible rename path, move dangerous bulk work out of migration if appropriate.