# OFFYNEX Forms — implementation and completion specification

## Current implemented foundation
- Local form question/response records, typed question parsing, basic required/choice validation and response CSV export exist.
- This is not yet a complete visual builder or published online form service.

## Remaining implementation
- Build a visual form designer with sections, drag/reorder, question types (short/long text, email, number, date, choice, multi-select, checkbox, file upload and signature where supported).
- Add conditional branching, required/format/range validation, help text, default values and preview mode.
- Add reusable templates, themes, branding and responsive respondent UI.
- Add secure publish/share links, access controls, expiry, authentication/anonymous response policy and spam/rate limiting.
- Add online response backend, offline draft submission queue, duplicate protection and retry status.
- Add response dashboard, filtering, charts, exports (CSV/XLSX/PDF) and per-response review.
- Add privacy/consent text, retention/deletion controls and data export.
- Keep local-only mode functional when network/publishing services are unavailable.

## Acceptance gates
- Builder/preview/conditional logic/validation tests and respondent workflow tests.
- Offline draft, retry, duplicate submission and CSV/XLSX/PDF export tests.
- Access-control, privacy and abuse-protection review before public release.
- Analyze, full tests and signed Android build pass; online backend is verified separately.
