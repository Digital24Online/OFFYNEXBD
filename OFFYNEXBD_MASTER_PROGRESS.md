# OFFYNEXBD MASTER PROJECT

## Brand
- Name: OFFYNEXBD
- Tagline: The Future of Office Productivity

## Platforms
- Android
- iPhone
- Windows
- macOS

## Main Modules
1. OFFYNEX Writer
2. OFFYNEX Sheets
3. OFFYNEX Slides
4. OFFYNEX PDF
5. OFFYNEX Fonts
6. OFFYNEX AI
7. OFFYNEX Cloud
8. OFFYNEX Forms
9. OFFYNEX Scan
10. OFFYNEX Database

## Project Requirements
- Desktop-class office features
- Bengali and international font support
- DOCX, XLSX, PPTX, ODT, ODS, ODP and PDF
- Offline-first with online synchronization
- Security, backup and accessibility
- Prefer free/open-source technology where practical

## User Working Rules
- User works from Android phone and does not code.
- Do not ask the user to upload documents or images.
- Give one simple instruction at a time in easy Bangla.
- Avoid repeating completed work.
- Preserve existing features, data, and compatibility.
- Do not ask the user to install APK unless explicitly requested.
- Keep OFFYNEXBD separate from Digital 24 Online and INAB BD.

## Repository
- GitHub: https://github.com/Digital24Online/OFFYNEXBD
- Branch: main
- Repository is separate and active.
- Automatic Android build triggers on relevant source changes.

## Completed Repository Structure
- [x] Android app folder
- [x] iPhone app folder
- [x] Windows app folder
- [x] macOS app folder
- [x] OFFYNEX Writer
- [x] OFFYNEX Sheets
- [x] OFFYNEX Slides
- [x] OFFYNEX PDF
- [x] OFFYNEX Fonts
- [x] OFFYNEX AI
- [x] OFFYNEX Cloud
- [x] OFFYNEX Forms
- [x] OFFYNEX Scan
- [x] OFFYNEX Database
- [x] Backend
- [x] Database architecture
- [x] Security

## Verified Development Checkpoint — 2026-11-16

### Android Build
- Latest workflow run: #35
- Run ID: 43929157157
- Commit: c3fe68efa052b8b985cde623dc62e768656754e9
- Result: SUCCESS
- Verified all job steps succeeded: Analyze Project, Run Tests, Build Android APK, signing-file cleanup, source save, and APK upload.
- APK artifact: OFFYNEXBD-Android-APK (28,573,909 bytes; available until 2026-11-23).
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/43929157157
- Do not ask the user to install the APK; development continues.

### OFFYNEX Writer
- [x] Writer editor and local autosave foundation.
- [x] Formatting foundation.
- [x] Table embed and editing foundation.
- [x] Serial 14.6 — Image Support: Insert Image, image file selection and validation, local image persistence, Quill image embed rendering and preview.
- [x] Serial 15 — Layout Tab: A4/A5/Letter/Legal, Portrait/Landscape, margin presets, custom margins, reset, responsive page display and per-document layout autosave.
- [x] Serial 16 — References, Review and View: citation source manager with individual source deletion; bibliography sorted by author/year/title; footnotes/endnotes and captions; table of contents; review comments with improved text-location recovery; Find/Replace; revision history restore/delete/clear; zoom, ruler, page border, status bar and focus mode controls. Android build #35, Analyze and Tests all passed.

### OFFYNEX Sheets
- [x] Initial offline-first Sheets screen added at lib/lib/modules/sheets/sheets_screen.dart.
- [x] Sheets connected to the app home.
- [x] Formula parser fix for repeated cell references committed.
- [ ] Continue feature audit and enhancement; verify cell editing, formula recalculation, persistence, row/column operations, and workbook import/export before marking Sheets complete.

### Important Technical Notes
- Writer screen: lib/lib/modules/writer/writer_screen.dart
- Writer table embed: lib/lib/modules/writer/writer_table.dart
- Preserve table embed identifier: offynexbd-writer-table.
- Writer images currently use the app-private offynexbd_images directory. Portable document export/import must package images; local paths are not portable.
- Preserve compatibility with existing Quill Delta documents, tables, images, autosave, page layout, comments, citations and revisions.
- App must support Bangla and English.
- Keep Android-first workflow while preserving cross-platform architecture.

## Next Development Tasks
1. Continue OFFYNEX Sheets verification and enhancements without breaking its current data or formulas.
2. Verify every source change with GitHub Actions analysis, tests, and Android build.
3. Expand document format support and other modules in the planned order.
4. Maintain this progress file after verified milestones.


## Verified Development Checkpoint — 2026-11-17

### OFFYNEX Sheets — Formula Engine and Grid
- [x] Formula engine aggregate ranges now propagate formula errors and circular references instead of silently skipping them; text values remain ignored by numeric aggregate functions.
- [x] Formula tests cover SUM, AVERAGE, MIN error propagation and text handling.
- [x] Replaced eager DataTable rendering with a lazy `ListView.builder` grid; distant rows are created only when scrolled into view.
- [x] Kept the column header fixed during vertical scrolling and preserved horizontal/vertical scrolling, cell selection, editing, formulas and formatting.
- [x] Added a widget test that scrolls to row 1000 and verifies that the distant cell is built on demand.
- [x] Build #108 (run ID 44106861497; commit e6b11b28d059a953a3682c350beafbee4268cdcf) — Analyze, Tests, Android APK build and APK upload all SUCCESS.
- [x] APK artifact: OFFYNEXBD-Android-APK (30,627,520 bytes; available until 2026-11-24).
- [ ] Cell-alignment and editing lifecycle fixes are committed; latest Build #114 is queued for Analyze, Tests, Android APK build and upload.

### Latest Sheets Alignment Correction — 2026-11-17
- Commit `53ac055872c032547553066218221f8d3851dc01`: cell horizontal and vertical alignment are now combined, so Top/Middle/Bottom alignment works even when Wrap Text is off.
- Commit `a33b39a0ae31bf4c81f260f60f6ccae42e3e59f0`: widget test added for vertical alignment without Wrap Text.
- Commit `39c4a3a210d7514907ad1ddd599323210495cc93`: widget test added for cell editing, formula recalculation and save/reload persistence.
- Commit `a1c12bcaea3b5395bc4a17fa0f898a85ab97fabb`: widget test added to verify populated edge rows/columns are protected and add-row/add-column operations preserve existing data.
- Build #112 (run ID 44113043865) failed during widget tests: the cell editor disposed its TextEditingController while the dialog was still animating out; the alignment test searched for an ancestor Container instead of the cell's child Container. The lazy-grid test also reported a dirty build-scope assertion after test teardown.
- Commit `aba60c426ac838ba33937946397edaf6bf9b23cc`: moved the edit TextEditingController into a dedicated StatefulDialog so it is disposed with the dialog lifecycle.
- Commit `3e912bc4b1880bf5b269924d831a28fb260e010f`: corrected the alignment test to inspect the Container inside the keyed cell.
- Latest Build #114 (run ID 44114359226) includes these fixes and must pass Analyze, Tests, Android APK build and APK upload before these changes are considered verified.

## Next Development Tasks
1. Verify the latest cell-alignment correction with GitHub Actions Analyze, Tests and Android APK build/upload.
2. Continue the OFFYNEX Sheets audit and tests for cell editing, formula recalculation, persistence, row/column operations and XLSX import/export. Do not mark Sheets complete until these are verified.
3. Update this file after each verified milestone.
4. Continue Writer completion and then the remaining modules in the planned order.


## Verified Development Checkpoint — 2026-11-17 (Build #123)

### Android Release Verification
- [x] Commit: `f3e3433806b5af25732ef4726630fbda62ddc6d0` — Add continuous multi-page Writer canvas.
- [x] Build #123 (run ID 44120494832) completed successfully.
- [x] Flutter Analyze — SUCCESS.
- [x] Automated Tests — SUCCESS.
- [x] Android Release APK — SUCCESS; artifact `OFFYNEXBD-Android-APK`, 33,463,935 bytes; available until 2026-11-24.
- [x] Signing files cleanup and generated-source save — SUCCESS.
- [ ] This build verifies the current source only; it does not mean all ten office modules are feature-complete.

### Full Repository Audit — Current Reality
- [x] Separate repository exists: `Digital24Online/OFFYNEXBD`, branch `main`.
- [x] Ten module names are visible on Home Screen.
- [x] Writer and Sheets have working implementation foundations.
- [ ] Slides, PDF, Fonts, AI, Cloud, Forms, Scan and Database remain incomplete; Home Screen currently shows a “coming soon” message for these modules.
- [ ] Writer continuous-page canvas is preliminary visual pagination; true rich-content page flow and full Word parity remain incomplete.
- [ ] Writer PDF generation currently needs rich formatting, image, table, header/footer and note preservation verification.
- [ ] Sheets still needs complete Excel feature parity, print system, advanced formulas, charts, pivot/data tools and compatibility testing.
- [ ] Shared print/preview, portable document packaging, offline/online sync, backup/restore and security architecture need implementation and verification.
- [ ] Branding: approved logo SVG is present and used on Home Screen. Platform App Icon files exist, but their visual match to approved logo #2 has not yet been confirmed.
- [x] Home Screen footer tagline corrected to the approved brand tagline: “The Future of Office Productivity”.

### Coordinated Development Rule
- Work across related modules in cohesive integrated batches; do not treat placeholder module tiles as completed modules.
- Preserve existing Writer Delta/table/image/autosave/layout/review data and Sheets formulas/workbook data.
- Run Analyze, automated tests and Android release build after each stable integrated batch; record only verified results here.
