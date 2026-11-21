# OFFYNEX AI Assistant — implementation and completion specification

## Current implemented foundation
- Offline prompt/record workspace and local persistence exist.
- No live AI generation provider is currently wired; UI records/prompts must not be presented as generated AI results.

## Remaining implementation
- Define a provider abstraction for online AI and optional on-device models; show provider/model availability and network state clearly.
- Secure API credentials using platform secure storage; never hardcode keys, commit secrets or expose credentials in logs/exports.
- Add explicit user consent and per-request context selection (current selection/document/sheet/slide/PDF); preview what content will be sent.
- Implement writing, rewrite, summarize, translate (Bangla/English), grammar/spelling suggestions, spreadsheet explanation/formula help and slide-outline generation.
- Stream/cancel requests, handle timeouts/rate limits/offline failures, and show source/context provenance.
- Insert results into Writer/Sheets/Slides only after user review; preserve original content and provide undo.
- Add privacy controls, retention policy, delete history, model limitations and safe prompt-injection boundaries for imported files.

## Acceptance gates
- Mock-provider tests for request construction, consent, cancellation, errors and result insertion.
- Security tests ensure secrets never appear in logs, backups or source.
- Bangla/English quality review, privacy review and real-provider integration test.
- Analyze, full tests and signed Android build pass. Do not claim AI is live until a real provider test succeeds.
