# OFFYNEX Cloud — implementation and completion specification

## Current implemented foundation
- Local portable backup/export/import/restore exists for supported OFFYNEXBD data, including Writer assets and Scan PDFs.
- Archive validation, path traversal protection, size/file-count limits and rollback-aware preference restore are implemented.
- This is local backup portability, not remote cloud storage or multi-device synchronization.

## Remaining implementation
- Define account identity, authentication, session expiry, recovery and account deletion.
- Select and document backend/storage architecture, data residency, privacy terms and operational cost limits before implementation.
- Add encrypted transport and encryption-at-rest/key management; separate user credentials from content encryption keys.
- Implement upload/download, resumable transfer, background queue, offline outbox and storage quota handling.
- Add multi-device sync, conflict detection/resolution, version history, restore points and deleted-item recovery.
- Add controlled sharing links, permissions, revocation, expiry and audit events.
- Add sync status, retry controls, selective sync and per-file offline availability.
- Preserve existing local-first data if sign-out, network failure or remote deletion occurs; never silently overwrite newer local work.

## Acceptance gates
- Threat model and security review before real user data is synchronized.
- Offline/online, interrupted transfer, conflict, duplicate, restore and account deletion integration tests.
- Secrets never stored in plain preferences or included in portable archives.
- Analyze, full tests and signed Android build pass; backend and multi-device tests independently verified.
