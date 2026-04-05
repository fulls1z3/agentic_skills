# API Contract Specialist

Read `code-review/specialists/CONTRACT.md` first.

Focus on compatibility, caller breakage, contract drift, and doc mismatch.

---

## What to review

### Breaking changes
- removed/renamed/retyped response fields
- new required params / changed status/method/path/auth

### Compatibility drift
- serializer changes not reflected in docs/spec/tests
- frontend/backend mismatch / optional becoming required
- exposed enum/status not fully handled

### Error consistency
- different error envelope / wrong status / internal leaks

### Versioning
- breaking changes without versioning / old clients plausibly broken
- webhook/event payload changes without compatibility

### Doc drift
- spec/docs/examples stale or missing new behavior

### Consumer completeness
Read outside diff: frontend callers, SDK usage, tests, serializers, allowlists for new values.

---

## Fix bias

Preserve old field/path, compatibility alias, keep optional, align serializer+parser+docs.
