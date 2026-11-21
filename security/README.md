# OFFYNEXBD Security — project-wide requirements

## Existing safeguards
- Local portable backup codec validates archive structure, paths, file counts and size limits; restore includes rollback-aware preference writes.
- File importers apply type/size checks in several workflows. These safeguards are partial and do not constitute a complete security architecture.

## Required security work
- Threat model assets, trust boundaries, local data, imported files, cloud services, AI context and sharing.
- Secure secrets and tokens with platform secure storage; never put keys/passwords in source, logs, exports or ordinary preferences.
- Validate file signatures and content, not just filename extensions; enforce decompression, image/PDF/font and archive resource limits.
- Define encryption at rest for sensitive local files and cloud content, key lifecycle/recovery and transport TLS policy.
- Implement authentication/session lifecycle, least-privilege authorization, account recovery and access revocation before online features.
- Protect PDF redaction, signatures, form sharing, cloud links and database queries against misuse.
- Add privacy notice, consent, retention/deletion, user data export and breach/incident procedures.
- Add dependency/license scanning, static analysis, secret scanning, vulnerability review and release signing verification.

## Release gates
- Security review and automated tests for malformed files, path traversal, oversized payloads, injection, auth boundaries and secret leakage.
- No real cloud/AI integration with production user data before threat model and credential handling are reviewed.
- Record unresolved risks; do not claim compliance/certification without an independent audit.
