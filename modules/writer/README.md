# OFFYNEX Writer — implementation and completion specification

## Current implemented foundation (source exists; CI coverage is not the same as device acceptance)
- Quill Delta document editing, local autosave/recovery, document library and native JSON archive.
- Rich text, numeric font sizes, font family choices, colors/highlight, alignment, lists, undo/redo, tables and local images.
- Page setup (A4/A5/Letter/Legal, portrait/landscape, margin presets/custom), page view/width/actual zoom, pinch/pan, ruler, focus mode and status controls.
- References, bibliography, footnotes/endnotes, captions, TOC, review comments, Find/Replace and revision snapshots.
- DOCX/ODT import/export foundations; PDF export, print preview/print with bundled Bengali fonts and shaping support.
- PDF/image-to-Writer conversion foundations and Bangla/English OCR where supported.

## Remaining implementation — all must be addressed, not silently dropped
### Editing and pagination
- Replace estimated continuous-canvas page backgrounds with content-aware pagination and independent page layout/flow.
- Support explicit page/section breaks, keep-with-next, widow/orphan handling, paragraph spacing, page-number fields and section-specific page settings.
- Keep text selection, cursor movement, IME/keyboard, undo/redo and autosave stable across page boundaries.
- Preserve page-fit/zoom behavior on narrow phones, tablets and desktop.

### Tables and objects
- Upgrade plain-text table cells to editable rich cells with row/column resize, add/remove, merge/split, borders, cell shading, alignment, wrapping and table positioning.
- Preserve existing `offynexbd-writer-table` embeds and migrate old records without data loss.
- Improve image resize/crop/wrap/position/alt text and object anchoring; keep images portable in native backups and DOCX/ODT/PDF.
- Add shapes and robust hyperlink editing if supported by the document model.

### Format fidelity and review
- Improve DOCX/ODT import/export for sections, headers/footers (default/first/even), fields, tables, lists, images, page breaks and styles.
- Keep native Writer archive as loss-minimizing format; never claim DOCX/ODT is lossless without round-trip evidence.
- Add Bangla/English spellcheck dictionary integration, proofing UI, language selection and safe Bijoy ANSI-to-Unicode conversion if licensed/technically appropriate.
- Complete localization of ribbon, dialogs, validation and error messages.

### Device and release acceptance
- Fix the known bottom toolbar overlap / unwanted “Apps” item intrusion without removing existing actions.
- Test long documents, large images/tables, crash recovery, memory/performance and autosave race conditions.
- Compare rendered Bengali যুক্তাক্ষর, কার/ফলা/রেফ, mixed English/Bangla, line wrapping and page breaks against representative references on Android, desktop PDF viewers and physical printers.
- Validate keyboard, touch selection, full-page view, zoom, print preview editability and all ribbon actions on physical Android devices.

## Required source/test areas
- Main editor/library: `lib/lib/modules/writer/writer_screen.dart`
- Table model/editor: `lib/lib/modules/writer/writer_table.dart`
- Page break and viewport: `writer_page_break.dart`, `writer_viewport.dart`
- Document codecs/export: `writer_document_codec.dart`, `writer_document_format_service.dart`, `writer_docx_export_service.dart`, `writer_pdf_export_service.dart`
- Tests: all `test/writer_*.dart`

## Acceptance gates
- Legacy Delta, tables, images, comments, citations, revisions and page layout survive upgrade/import/export.
- Automated tests cover page-flow, tables, format round-trip, recovery and compact phone layout.
- Analyze + complete test suite + signed Android APK/package checks pass on the same commit.
- Physical Android, keyboard, Bengali visual rendering, printer and Word/LibreOffice interoperability checks are recorded separately.


## Active scope and completion requirements
**Writer only.** The current user instruction explicitly excludes all other OFFYNEXBD modules until Writer is complete. Do not implement or advance Sheets, Slides, PDF, Fonts, AI, Cloud, Forms, Scan or Database as separate modules.

Writer must reach a professional, desktop-class Microsoft Word-style feature set, with responsive phone/tablet/desktop behavior. Audit every ribbon and contextual command, then complete the remaining Writer work in integrated batches rather than isolated one-feature patches.

Preserve existing saved documents and backward compatibility: Quill Delta content, legacy document records, `offynexbd-writer-table` and `offynexbd-writer-page-break` embeds, images, autosave, recovery/backup, page layout, comments, citations, revisions, header/footer metadata and existing export workflows.

**Confirmed outstanding blocker:** the current editor is a single continuous Quill editor over a `CustomPaint` page background with estimated page count. True content-aware pagination—where text, images and tables flow naturally from one physical page to the next—has not been implemented or verified. Do not call Writer complete until this and all other required Writer workflows are implemented and tested end-to-end.

Before changes, audit all Writer source, services, dependencies and tests. After changes, run Analyze, regression tests and Android build; inspect and fix every failure. A successful build alone is not proof of completion.
