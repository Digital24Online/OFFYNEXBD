# OFFYNEXBD — Integrated Completion Blueprint

**Purpose:** Single implementation contract for completing every OFFYNEXBD module without losing existing work. This document is the cross-module index; each `modules/<module>/README.md` contains the detailed module checklist.

## 1. Product invariants — do not break
- Brand remains OFFYNEXBD, tagline “The Future of Office Productivity”, selected logo Option 2.
- App Info creator attribution remains inside App Info: **MD PIYARUL ISLAM — Founder & Original Creator**, using the approved portrait. No address, GitHub work history or release record.
- Preserve Writer documents/Delta, tables, images, comments, citations, revisions, page settings and recovery data.
- Preserve Sheets workbooks, formulas, worksheets, formatting, validation, chart/pivot/conditional-format records and recovery data.
- Preserve Forms responses, Database rows/schema, Scan PDFs/OCR and existing portable backups.
- Offline-first behavior must remain available; online services are additive and must not silently replace local data.
- Bangla and English are first-class languages. Validate যুক্তাক্ষর, কার, ফলা, রেফ, punctuation, line wrapping and mixed-script content.
- Keep Android-first development while preserving iOS, Windows and macOS architecture. Never claim a platform feature is verified until it builds and is tested there.
- Existing actions must remain functional. No UI control may promise a feature that is not wired to a real operation.

## 2. Repository source map
### App shell and shared foundation
- `lib/main.dart` — app routes, dashboard and App Info.
- `lib/lib/theme/offynex_theme.dart` — shared theme tokens.
- `docs/OFFYNEXBD_GLOBAL_DESIGN_SYSTEM.md` — global UI and responsive behavior contract.
- `security/README.md` — security and privacy requirements.

### Module code map
| Module | Main source files | Detailed completion checklist |
|---|---|---|
| Writer | `lib/lib/modules/writer/writer_screen.dart`, `writer_table.dart`, `writer_document_codec.dart`, `writer_document_format_service.dart`, `writer_docx_export_service.dart`, `writer_pdf_export_service.dart`, `writer_viewport.dart`, `writer_page_break.dart` | `modules/writer/README.md` |
| Sheets | `sheets_screen.dart`, `sheets_formula_engine.dart`, `sheets_analytics.dart`, `sheets_analytics_widgets.dart`, `sheets_workbook_codec.dart`, `sheets_data_validation.dart`, `sheets_pdf_export_service.dart` | `modules/sheets/README.md` |
| Slides | `office_workspace_screen.dart`, `slides_preview_screen.dart`, `slides_pdf_export_service.dart` | `modules/slides/README.md` |
| PDF | `pdf_reader_screen.dart`, `pdf_to_document_screen.dart`, `pdf_to_document_service.dart` | `modules/pdf/README.md` |
| Fonts | shared workspace source and Writer font integration | `modules/fonts/README.md` |
| AI | shared workspace source and future provider/service boundary | `modules/ai/README.md` |
| Cloud | `portable_workspace_backup_service.dart`, `workspace_backup_codec.dart` | `modules/cloud/README.md` |
| Forms | `office_workspace_screen.dart`, `forms_question_codec.dart`, `forms_response_csv_codec.dart` | `modules/forms/README.md` |
| Scan | `scan_document_service.dart`, Scan flows in workspace screen | `modules/scan/README.md` |
| Database | `office_workspace_screen.dart`, `database_field_codec.dart`, `database_rows_dialog.dart`, `database_rows_csv_codec.dart` | `modules/database/README.md` |

**Path note:** This repository currently stores Flutter sources under `lib/lib/modules/...`; do not “correct” this layout or move files without auditing imports, workflow generation and tests first.

## 3. Accurate current state (source audit; not a completion claim)
- Writer: strong editing and document interchange foundations; true content-aware pagination, advanced tables, broad format fidelity, toolbar cleanup and device acceptance remain.
- Sheets: multi-sheet workbook, formula/grid, import/export, validation, analytics foundations, charts, pivot summaries, conditional-format rules and PDF/print source exist. These are not full Excel parity; richer editing, compatibility and real-file round-trip remain.
- Slides: text-per-slide records, read-only 16:9 preview and PDF export; no full canvas editor or PPTX/ODP interchange.
- PDF: read-only Reader with print/share plus conversion; no direct content editing/page management/annotations/signature/security toolset.
- Fonts: bundled Bengali fonts used by Writer/PDF; local font-record workspace only, no safe TTF/OTF manager.
- AI: local prompts/records only; no live model provider.
- Cloud: local portable backup/restore only; no authenticated remote sync.
- Forms: local question/response foundations and CSV export; no visual builder or published online form service.
- Scan: Android ML Kit document scanner and OCR/history foundations; platform parity and device OCR quality remain.
- Database: local typed fields/rows and CSV foundations; no relational engine/query builder.
- Global: shared theme/design blueprint exists, but all module screens are not yet fully migrated; Android CI does not prove iOS/Windows/macOS parity.

## 4. Cross-module completion requirements
- Unified phone/tablet/desktop navigation, ribbon/toolbar behavior, dialogs, empty/error/loading states, search, file lifecycle and accessibility.
- Shared file/document model and import/export contracts; stable IDs and versioned migrations.
- Shared print/preview/export pipeline with Bengali shaping and per-module page settings.
- Unified offline autosave, crash recovery, undo/redo where applicable, portable backup and safe restore.
- Searchable recent files, consistent naming, metadata and user-controlled deletion.
- Localization of every visible label, validation error, confirmation, accessibility label and status.
- Data integrity: migrations, atomic writes, rollback, duplicate detection, import previews and non-destructive conflict handling.
- Performance: large documents/workbooks/PDFs, image memory, background processing, cancellation and storage limits.
- Security: threat model, secrets, imported-file validation, privacy, account boundaries and cloud/AI controls.

## 5. Integrated execution order — do not implement one tiny feature and stop
1. **File preparation and audit (this phase):** keep this blueprint and all ten module READMEs synchronized with actual source; identify every affected source/test/config/asset file; record dependencies and acceptance evidence. No claims of implementation merely because a requirement is written here.
2. **Shared foundations:** data models/migrations, localization, design tokens, responsive shell, import/export safety, backup/recovery and print/export contracts.
3. **Core editors:** Writer pagination/tables/format fidelity; Sheets formulas/analytics/chart editing/print compatibility; Slides canvas/editor/interchange.
4. **Document workflows:** PDF editing/page tools/OCR/forms/security; Scan capture/OCR review and file lifecycle; Fonts manager and shaping integration.
5. **Productivity/services:** Forms builder/publishing/analytics; Database relations/query/migrations; AI provider/privacy/result insertion; Cloud authentication/sync/conflicts/sharing.
6. **Integrated verification:** regression tests across modules, real fixture round-trips, device/desktop builds, Bengali rendering, accessibility, performance, security and backup restore.
7. **Release:** update progress only from evidence; run full CI on exact final commit; complete physical-device acceptance; then use the user's existing PR #13 merge authorization when all release conditions are met. Do not ask again for that already-given permission.

## 6. Required evidence for every feature
Each feature must have: source file(s), UI entry point, persisted data/schema behavior, localization, automated test(s), failure/cancel behavior, backward compatibility/migration notes, and platform limitations. A README checklist alone is not implementation.

## 7. Definition of complete
A module is complete only when its actual user workflow works end-to-end, its data survives save/reopen/backup/restore, imports/exports are verified with representative real files, tests and CI pass on the same commit, and required physical-device/platform checks are recorded. Never use “complete” to mean only “screen exists” or “build passed”.
