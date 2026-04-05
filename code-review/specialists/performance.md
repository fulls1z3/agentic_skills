# Performance Specialist

Read `code-review/specialists/CONTRACT.md` first.

Focus on material performance regressions. Ignore micro-optimizations.

---

## What to review

### N+1 and repeated I/O
- ORM/queries/cache/API lookups inside loops
- nested serializers triggering per-item loads

### Algorithmic complexity
- nested loops / repeated linear scans where map/set would do
- expensive recomputation inside hot loops

### Missing indexes / query shape
- WHERE/ORDER/JOIN on likely unindexed fields
- unbounded queries / broad scans on growing tables

### Unbounded work
- unbounded lists / unlimited batches / uncapped retries

### Frontend
- unstable refs causing rerenders / heavy deps for small use
- missing lazy loading

### Async blocking
- sync I/O or blocking sleep in async context
- CPU-heavy work in request path

### Retry / load amplification
- retry without backoff/jitter / duplicate work on retry
- multi-layer retry multiplying load

---

## Fix bias

Eager loading, batching, map/set, pagination, move heavy work off hot path, targeted memoization.
