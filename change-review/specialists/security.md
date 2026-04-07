# Security Specialist

Read `change-review/specialists/CONTRACT.md` first.

Focus on real attack surface and trust-boundary failures.

---

## What to review

### Input validation
- params/body without type/shape validation
- query params in DB/search/file/routing unsafely
- file uploads without size/type/content checks
- webhook payloads without authenticity check
- second-order injection: input stored with safe parameterization but later interpolated into a downstream query, shell command, or template
- validation at wrong layer: validated in controller but accessed unsanitized in service, job, or async worker

### Auth / authz
- missing auth middleware
- work before authz check / default-allow
- role escalation / missing ownership check
- token/session expiry or revocation not enforced
- IDOR: resource ID supplied by user — is `owner_id == current_user` checked before returning or mutating?
- JWT: `alg` field trusted from token header (alg:none bypass); `aud`/`iss` not verified
- privilege-escalating fields (`role`, `isAdmin`, `userId`) mass-assigned from request body

### Injection
- shell/command injection / path traversal
- SSRF from user/model URLs
- XSS / unsafe HTML rendering
- SQL interpolation / template/header injection
- env var dict passed to subprocess includes user-controlled values; `PATH`/`LD_PRELOAD` replaceable

### Secrets
- secrets/tokens in source, logs, URLs, or error responses
- hardcoded keys/IVs/tokens
- config committed with environment-specific values (dev endpoints, local credentials) that differ in production

### Crypto
- weak hashes / predictable randomness for secrets
- non-constant-time compare / missing salt

### LLM / tool security
- stored prompt injection chains
- multi-hop tool output trust without validation
- model output used for authz/write decisions or shaping queries/paths/shell

### Unsafe deserialization
- untrusted object deserialization / unsafe YAML/pickle/marshal loads

---

## Fix bias

Schema validation, ownership checks, constant-time compare, parameterized queries, arg-array subprocess, allowlist checks.
