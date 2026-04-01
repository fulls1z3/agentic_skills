# Performance Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review the diff (`/tmp/code-review/diff.patch`) and nearby code. Focus on material performance regressions introduced or exposed by the branch. Ignore decorative micro-optimizations.

---

## What to review

### 1. N+1 and repeated I/O
- ORM associations loaded inside loops
- queries inside iteration
- repeated storage/cache/API lookups in loops
- nested serializers/resolvers triggering per-item loads

### 2. Algorithmic complexity
- nested loops over related collections
- repeated linear scans where map/set would do
- expensive recomputation inside render/request loops

### 3. Missing indexes / query shape drift
- new WHERE/ORDER/JOIN usage on likely unindexed fields
- broad scans introduced by convenience code
- unbounded queries on growing tables

### 4. Unbounded work
- endpoints returning unbounded lists
- jobs processing unlimited batches in one pass
- retries or loops with no cap

### 5. Frontend performance
- unstable references causing rerenders
- heavy client deps/imports for small use
- missing lazy loading where obvious

### 6. Async blocking
- sync I/O in async handlers
- blocking sleep in async context
- CPU-heavy work in request path

### 7. Retry/load amplification
- retry loops without backoff/jitter
- duplicate work on retry
- retry across multiple layers multiplying load

---

## Fix guidance bias

Prefer: eager loading, batching, local map/set/index, pagination/limits,
parallelize independent calls, move heavy work out of hot path,
targeted memoization/lazy loading, index recommendation when clearly warranted.