# Security Specialist

Read `code-review/specialists/CONTRACT.md` first.

Review the diff (`/tmp/code-review/diff.patch`) and directly related code. Focus on real attack surface and trust-boundary failures.

---

## What to review

### 1. Input validation at trust boundaries
- request params/body accepted without type or shape validation
- query params used in DB, search, file, or routing logic unsafely
- file uploads without size/type/content checks
- webhook payloads processed without authenticity verification
- external API payloads trusted too early

### 2. Authentication and authorization
- routes/endpoints missing auth middleware
- work done before authz check
- default-allow behavior
- role escalation paths
- user-controlled ids with no ownership check
- expiry or revocation not enforced for tokens/sessions

### 3. Injection vectors
- shell/command injection
- path traversal
- SSRF from user/model supplied URLs
- unsafe HTML rendering/XSS
- SQL built via interpolation
- template/header injection

### 4. Secrets and sensitive data
- secrets in source/comments
- secrets or tokens logged
- credentials in URLs
- sensitive internals leaked in error responses
- hardcoded keys, IVs, tokens

### 5. Crypto misuse
- weak hashes for security-sensitive use
- predictable randomness for secrets/tokens
- non-constant-time compare on secrets/tokens
- missing salt or modern password hashing

### 6. LLM / tool security (beyond basic trust boundary)
- stored prompt injection chains (model output → KB → future model input)
- multi-hop tool output trust (tool A output fed to tool B without validation)
- model/tool output used for authz or write decisions directly
- model output shaping queries, paths, or shell commands indirectly

### 7. Unsafe deserialization
- untrusted object deserialization
- unsafe YAML/pickle/marshal-style loads

---

## Fix guidance bias

Prefer: explicit schema/type validation, ownership/authz checks, constant-time compare,
parameterized query, arg-array subprocess, allowlist/denylist checks, earlier boundary guard.
No giant rewrites unless unavoidable.