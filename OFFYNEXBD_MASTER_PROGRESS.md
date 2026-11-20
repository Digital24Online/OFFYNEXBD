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

## Repository Structure — corrected implementation status
- [x] Separate Flutter repository and Android build workflow exist.
- [x] Platform project folders exist for Android, iPhone, Windows and macOS.
- [x] Home Screen displays the ten planned module names.
- [x] Initial Writer, Sheets and PDF-to-Document source implementations exist.
- [x] Partial offline functionality exists across Slides, Fonts, AI Assistant, Cloud backup, Forms, Scan and Database; these are not yet complete office-grade or production modules.
- [ ] Production backend, cloud authentication/synchronization, shared online Forms, live AI services, and complete database/security architecture remain unimplemented.
- Note: module names, README files, planned folders or UI tiles do not count as completed functional modules. See the 2026-11-18 integrated repository audit below.

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


### Cross-platform Brand Consistency Batch — 2026-11-17
- [x] Android launcher display label standardized to OFFYNEXBD.
- [x] iPhone app display name and bundle name standardized to OFFYNEXBD.
- [x] macOS app bundle display name standardized to OFFYNEXBD.
- [x] Windows file description, internal name and product name standardized to OFFYNEXBD.
- [x] Home Screen widget test now checks the approved brand tagline.
- [ ] Build and tests for this batch are pending GitHub Actions verification.

## Required Feature Added — PDF to Editable Document — 2026-11-17

- [x] Product requirement confirmed: users must be able to convert an existing PDF into an editable Writer document.
- [x] Add an explicit **PDF to Document / PDF to DOCX** workflow in OFFYNEX PDF, with the resulting editable document opened in OFFYNEX Writer.
- [ ] Text-based PDF extraction must preserve reading order, paragraphs, page breaks and supported formatting as accurately as possible.
- [ ] Extract images and tables where technically possible; retain page structure and provide a clear conversion-quality notice when exact layout reconstruction is not possible.
- [ ] Scanned/image-only PDFs must use OCR, with Bangla and English language support; users must be able to review and correct recognized text.
- [ ] Export converted content as editable DOCX and as Writer's native document format; allow PDF export again.
- [ ] Handle multi-page PDFs, mixed text/image pages, selectable output pages, progress/cancellation, password-protected PDFs (request password securely; never log it), and conversion errors.
- [ ] Preserve source PDF unchanged; conversion creates a separate document.
- [ ] Add automated tests for text extraction, page order, Bangla/English OCR integration boundary, image/table handling, malformed/encrypted PDFs and DOCX round-trip.
- Status: **Initial workflow implemented; full production parity remains incomplete.** Multi-page, scanned-PDF OCR reliability, password handling, layout fidelity and full round-trip tests remain pending.


## Integrated PDF-to-Writer Conversion Batch — 2026-11-17

- Added a real PDF module route from the Home Screen.
- Uses the MIT-licensed docx_creator PDF reader to parse PDF text, formatting, images, and detected tables, and to generate editable DOCX.
- Saves a separate native Writer document; the source PDF remains unchanged.
- Maps paragraphs, basic bold/italic/underline/font styling, extracted images, and detected tables into Writer-compatible Quill content.
- Adds Bengali + English Tesseract OCR for scanned/image-only PDFs when embedded page images are extractable. CI provisions ben/eng trained data.
- Adds PDF size/type validation, conversion progress, warnings, DOCX Save As, and Open in Writer.
- Adds automated helper tests and a Home Screen PDF-route test.
- Known limitations: complex multi-column positioning may shift; table detection is beta; password-protected PDFs are not supported yet; scanned PDFs whose page image cannot be extracted need a PDF renderer fallback; OCR native packaging/platform support still needs validation on iOS and Windows.
- Status remains pending until Analyze, tests, Android release build, and a real scanned Bangla/English PDF test pass.


## Integrated Image-to-Document Batch — 2026-11-17

- Added an explicit Image to Document action beside PDF conversion in the PDF workspace.
- Supports JPG, JPEG, PNG, WEBP, BMP and TIFF file selection (30 MB limit).
- Runs Bengali + English Tesseract OCR on the selected image, then creates a multi-page intermediate PDF using the bundled Noto Sans Bengali font and exports editable DOCX through the same PDF-to-DOCX pipeline.
- Saves a separate native Writer document and offers Open in Writer / Save DOCX; source image remains unchanged.
- Added supported-image-extension validation test.
- OCR native support remains unverified on iOS; Windows OCR is explicitly reported unsupported rather than falsely showing success. OCR quality depends on image clarity, angle, lighting and text size; the extracted document is text-first and does not preserve the original photo layout.
- Build and test status must be checked before marking this feature complete.


## Writer Bengali Font and PDF Preservation Batch — 2026-11-17

- Repaired the malformed image-to-document service source from its last known good PDF conversion implementation, then restored the Bengali/English OCR image workflow with correct filename validation and temporary-file cleanup.
- Replaced the Writer plain-text PDF export with a Quill Delta-based PDF export service. It embeds bundled Noto Sans Bengali and Noto Serif Bengali fonts and maps supported bold, italic, underline/strike, font size, text color, paragraph alignment, images and Writer table blocks into the generated PDF.
- Writer Save PDF/Print Preview/Print continue to use the same PDF generation callback, so the embedded-font output is passed to the printer pipeline.
- Added the Noto Serif Bengali asset to the app bundle and CI font provisioning; Writer font choices now identify the actual bundled Bengali fonts.
- Added a PDF export test for embedded font resources and supported rich-text formatting.
- Important validation limit: embedding fonts prevents external font substitution, but the PDF package's complex-script shaping and exact visual equivalence for every Bengali conjunct/ligature must still be checked with rendered PDFs on Android and desktop. No claim of perfect glyph-shape preservation is made until that visual test passes. Arbitrary user-installed fonts are not yet supported; only the bundled Bengali fonts are selectable.
- Status: source repair and implementation committed; CI analysis, automated tests, Android APK and real Bengali print/PDF visual verification pending.


## OFFYNEX Sheets PDF and Print Batch — 2026-11-17

- Added a dedicated Sheets PDF export service with bundled Noto Sans Bengali and Noto Serif Bengali fonts embedded in the PDF.
- Added Save as PDF and Print actions to the File ribbon; both use the same PDF builder and A4 landscape layout.
- PDF output includes the used cell range, displayed cell values/formula results, supported bold/italic/underline, font size/color, fill color and alignment, plus a sheet heading and page numbering.
- Existing workbook data, local autosave and XLSX import/export code are retained.
- Added an automated test for Bengali PDF font embedding and styled cell output.
- Analyze, automated tests, Android APK and visual print verification are pending; exact Bengali complex-glyph shaping must be checked on rendered output before claiming perfect visual fidelity.

## Build #142 Error Investigation — 2026-11-17

- Build #142 (run ID 44131903430; commit `998841ddb42696ad7a552da7927aaa220ffa1fd8`) failed at **Analyze Project**.
- Exact analyzer findings: two `prefer_interpolation_to_compose_strings` infos at `sheets_pdf_export_service.dart:71:11` and `:71:53`; workflow treats analyzer infos as a failing exit.
- Dependencies and font downloads succeeded; tests and Android build were skipped because Analyze failed.
- Corrected the page-number expression to Dart string interpolation. The next GitHub Actions run must still verify Analyze, tests, APK build and upload before this Sheets PDF/Print batch is marked successful.


## Integrated Bengali PDF Shaping and Sheets Print Fidelity Batch — 2026-11-17

- Build #143 (run ID `44133425598`, commit `53102cbf7f48d8c528ab233372d080457f570374`) was verified SUCCESS: Analyze, Tests, Android APK build, signing cleanup, generated-source save and APK upload all passed. APK artifact size: 47,931,757 bytes; expiry: 2026-11-24T17:14:05Z.
- Source audit found that the previous PDF implementation embedded Bengali fonts but used the base `pdf` text widgets without OpenType GSUB/GPOS shaping; embedding alone was not sufficient to guarantee Bengali conjuncts, reph and vowel-sign placement.
- Migrated Writer and Sheets PDF widget imports to `bangla_pdf` 1.9.2, which performs Unicode Bengali OpenType shaping and retains a Unicode text layer. The package reports HarfBuzz differential tests for Noto Sans Bengali and Noto Serif Bengali and supports Android, iOS, Windows, macOS and web.
- Updated the `pdf` dependency to 3.13.1 to meet the shaping package's dependency requirements.
- Expanded Sheets PDF rendering to respect the workbook's gridline visibility, individual cell borders, wrap/ellipsis behavior and vertical alignment, in addition to existing font, color, fill and horizontal alignment.
- Expanded Writer and Sheets PDF tests with complex Bengali conjunct/reph/matra samples and PDF text extraction checks.
- Current batch status: source changes prepared; GitHub Analyze, automated tests and Android APK verification are pending. Visual print inspection on actual Android/printer devices remains a separate final acceptance check; no claim is made about every third-party font or printer.


## Build #144–#146 Failure Analysis and Mixed-script PDF Fix — 2026-11-17

- Build #144 failed at Analyze: the PDF TextOverflow enum in this package has no `ellipsis`; Build #145 repeated that same failure because it started before the correction reached the branch.
- Build #146 passed Flutter Analyze but failed one Writer PDF test (25 passed, 1 failed). Sheets Bengali PDF test passed.
- Exact failure: Writer mixed English text was extracted as Bengali-looking mojibake (`ঊহমষরংয সরীবফ ঃবীঃ`) instead of `English mixed text`.
- Root cause: the embedded Noto Sans Bengali / Noto Serif Bengali fonts do not cover every Latin/Unicode symbol; a Bengali font alone is not a complete fallback chain. The PDF package documentation explicitly requires fallback fonts for characters not covered by Bengali faces.
- Corrective batch: add Helvetica as a Latin/symbol fallback to Writer title, rich-text spans and table cells, and to Sheets cells/header/footer. Keep Noto Bengali as the primary font for Bengali shaping. Expand Writer and Sheets tests to assert mixed Bengali/English round-trip and a regression check against the mojibake string.
- Current verification status: changes committed; a new GitHub Actions run must pass Analyze, all tests and Android APK build/upload. Actual Android printer/viewer visual inspection remains pending.


## Build #147 Failure Analysis and Unicode Latin Fallback Correction — 2026-11-17

- Build #147 (run ID `44137173358`, commit `29b04f2b1a95d800fb142437f409cdfa7439ef46`) passed Flutter Analyze but failed 2 PDF tests (24 passed, 2 failed); Android APK build was skipped.
- Both Writer and Sheets extracted English text as Bengali-looking mojibake. The prior Helvetica fallback was not a safe Unicode fallback; the PDF runtime warned that Helvetica has no Unicode support.
- Corrective integrated batch: provision a real Google Noto Sans variable TrueType font as `assets/fonts/NotoSans.ttf`; use it as the Unicode Latin/symbol fallback in Writer title, rich-text spans, tables and Sheets cells/header/footer; pass the font data through both export services and their production callers; update PDF tests to load the same fallback asset.
- Bengali primary faces (Noto Sans Bengali and Noto Serif Bengali), existing styles, workbook data and Writer content remain unchanged.
- Verification pending: the next GitHub Actions run must pass Analyze, all tests, Android APK build and artifact upload. Device/printer visual inspection remains a separate acceptance step.


## Build #148 Failure and PDF Fallback Scope Check — 2026-11-17

- Build #148 (run ID 44138032704) failed during Flutter Analyze at `writer_pdf_export_service.dart:186:36`: `latinFont` was referenced inside the Writer table renderer without being passed into that helper.
- Corrected the helper signature and call site so the already-loaded Noto Sans Unicode fallback is passed into Writer table-cell styles. This retains Noto Sans Bengali/Serif Bengali as primary faces and uses the bundled Noto Sans font only for missing Latin/Unicode glyphs.
- User confirmed OFFYNEXBD must support both Unicode Bengali fonts and legacy Bijoy ANSI fonts such as SutonnyMJ.
- Font system audit: current Writer picker only exposes two generic aliases (`sans-serif`, `serif`); arbitrary TTF/OTF installation, persistent font identities, document-level font metadata, font preview/management and ANSI↔Unicode conversion are not implemented. OFFYNEX Fonts remains a planned module. This is a major required feature, not satisfied by the current two bundled fonts.
- Next validation: GitHub Actions must verify Analyze, tests, Android APK build and artifact upload after this fix. The full font manager and Bijoy ANSI conversion require a dedicated integrated implementation and licensed/user-supplied font assets; do not bundle proprietary SutonnyMJ without a redistribution licence.


## PDF Mixed-Script Font Routing Correction — 2026-11-17

- Build #149 (run ID 44138838447; commit 50af431631612cf7024841dba81238ef29d32ea5) — Analyze passed, but 2 PDF export tests failed because English-only content was routed through the Bengali font and extracted as mojibake.
- Updated Writer PDF font selection to use the selected Bengali sans/serif face only for text containing Bengali; English-only runs use the bundled Noto Sans Latin font. Bengali-containing runs retain the Latin fallback for unsupported characters.
- Updated Writer table cells and title routing with the same script-aware rule.
- Updated Sheets PDF cells, sheet heading and page numbering to select Latin or Bengali fonts according to their text.
- Added mixed Bengali/English extraction assertions to both Writer and Sheets PDF tests.
- Status: correction committed; Build verification pending. Do not claim fixed until Analyze, all tests, Android APK build and artifact upload pass.


## OFFYNEX Sheets Formula Engine Expansion — 2026-11-17

- Source audit confirmed the current Sheets module has a working cell grid, local autosave, XLSX import/export, basic formatting, PDF/print entry points and a limited formula parser; this is not Excel parity.
- Expanded the formula engine from 13 to 31 supported functions: added MEDIAN, LARGE, SMALL, ROUNDUP, ROUNDDOWN, CEILING, FLOOR, PI, EXP, LN, LOG, LOG10, SIN, COS, TAN, ASIN, ACOS and ATAN.
- Added ribbon access and argument examples for the new functions; PI inserts directly as `=PI()` because it takes no arguments.
- Added automated tests for valid calculations, invalid ranks, invalid math domains and wrong argument counts.
- This batch is pending GitHub Actions Analyze, complete tests, Android release APK and artifact upload. Formula compatibility remains partial; logical, text, date/time, lookup, conditional aggregate and array/dynamic functions are not yet implemented.


### CI error correction — 2026-11-17
- Build #151 failed at Analyze Project, not in formula tests: lint prefer_is_empty at sheets_formula_engine.dart LOG argument validation.
- Corrected the empty-list check to values.isEmpty; the full LOG argument/domain validation remains intact.
- Build #152 was started before this lint correction and must not be treated as verification of the corrected code. A new integrated validation run is required.


## Sheets Formula Validation — Build #153 Failure and LARGE/SMALL Correction — 2026-11-17

- Build #153 (run ID `44142906724`, commit `b0c29af86d2092f9aa66ea4fdb592c984d21de07`) passed Flutter Analyze (`No issues found`) but automated tests reported 27 passed and 1 failed; Android APK build/upload did not run.
- Exact failing assertion: `LARGE(1,3,5,7,2)` returned null instead of 5. Root cause: the parser correctly collects multiple data values plus the final rank, but the implementation incorrectly validated LARGE/SMALL as requiring exactly two flattened values.
- Corrected validation to require at least two values (one or more data values plus rank), preserving rank/domain validation. Added coverage for both LARGE and SMALL with multi-value arguments and cell ranges.
- Analyze, the full test suite, Android APK build and artifact upload remain pending; do not mark the formula expansion verified until all pass.


## Sheets Formula Engine — Build #154 Failure Analysis and LOG10 Parser Correction — 2026-11-18

- Build #154 (run ID `44143652589`, commit `3b066c02522c0c5f790c2e875ba534c307627425`) passed Flutter Analyze but failed one formula-engine test; the remaining tests passed, including Bengali PDF shaping and XLSX round-trip tests. Android APK build/upload were skipped after the test failure.
- Exact failing assertion: `=LOG10(1000)` returned null instead of 3. Root cause: the tokenizer's cell-reference pattern also matches the identifier `LOG10`; the parser classified it as a cell reference before checking whether it was a function call.
- Corrected parser precedence: an identifier immediately followed by `(` is parsed as a function call first; ordinary cell references remain supported. Added a regression assertion that a cell reference named `LOG10` still resolves when it is not followed by `(`.
- Verification pending: Analyze, full tests, Android APK build and artifact upload must all pass before the 31-function expansion is marked verified.

### Build #156 verification and correction
- Build #156 (`44144984847`, commit `3d29b5ba`) completed with Analyze successful; tests failed on an overly strict exact floating-point assertion for `LOG10(1000)`: actual `2.9999999999999996` versus expected `3`.
- Updated the regression test to use a `1e-12` tolerance for this floating-point result. No formula-engine behavior was changed for this precision-only test issue.
- Re-run verification pending; APK build is not yet verified.


## Sheets Formula Engine — Build #157 Verified — 2026-11-17

- [x] Build #157 (run ID `44145977349`, commit `0ca238de5612640932307661169b50ee5ee890f1`) completed with SUCCESS.
- [x] Flutter Analyze — SUCCESS.
- [x] Automated Tests — SUCCESS, including the LOG10 floating-point tolerance regression test.
- [x] Android APK build — SUCCESS.
- [x] Signing-file cleanup, generated-source save and APK upload — SUCCESS.
- [x] Artifact: `OFFYNEXBD-Android-APK`, 49,983,747 bytes; available until 2026-11-24T18:22:27Z.
- [x] The 31-function formula-engine batch and LOG10 parser regression are now CI-verified. This does not imply full Excel formula compatibility; the remaining function families and edge cases listed in the project audit are still pending.
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44145977349
- Artifact download: https://api.github.com/repos/Digital24Online/OFFYNEXBD/actions/artifacts/14355609677/zip


## OFFYNEX Sheets — Formula Semantics and Regression Audit — 2026-11-18

### Implemented corrections
- [x] Corrected MOD remainder sign to follow spreadsheet divisor-sign behavior for positive and negative inputs.
- [x] Aggregate functions now ignore direct blank/text cell references as well as blanks/text inside ranges; formula errors and circular references remain errors.
- [x] Empty MIN/MAX return zero; empty AVERAGE/MEDIAN/LARGE remain invalid.
- [x] ROUND, ROUNDUP and ROUNDDOWN now handle negative precision, negative values, non-integer precision rejection and finite-range safeguards.
- [x] CEILING/FLOOR now handle negative-number/significance combinations and reject positive numbers with negative significance.
- [x] Scientific notation such as 1E3 and 2.5e-1 is parsed.
- [x] Nested LOG10 function calls inside aggregate functions are parsed without mistaking LOG10 for a cell reference.
- [x] Non-finite text values such as NaN/Infinity are not treated as numeric cell values.
- [x] General number display no longer truncates calculated values to four decimal places.
- [x] Row removal no longer mistakes a LOG10 function name for a row-10 reference, while real references such as A10 still protect the row.
- [x] Added regression tests for all above behaviors, invalid domains, overflow, empty aggregates, formula range-size limits, and row-removal/data-display widgets.
- [x] Updated modules/sheets/README.md to describe current implemented foundations and explicitly list major features that remain incomplete.

### Latest CI verification
- [x] Build #167 (run ID 44150323330; commit 7aa0136db371fac061a2d6f6df2fee7e7330c1d6): Flutter Analyze — SUCCESS.
- [x] Build #167: complete automated Test Suite — SUCCESS.
- [ ] Build #167: Android Release APK build and artifact upload — IN PROGRESS at checkpoint update; do not claim APK success until both steps complete.
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44150323330

### Scope limits
- The 31 supported functions are not full Excel formula parity. Logical, text, date/time, lookup, conditional aggregate, array/dynamic and financial functions remain unimplemented.
- Multi-worksheet workbooks, charts, sorting/filtering, pivot tables, data validation, conditional formatting, ODS/CSV and advanced print-preview controls remain incomplete.
- Physical Android/device and printer visual verification remains separate from CI.


### Android APK verification for the audited application source
- [x] Build #166 (run ID `44150127443`, commit `3e63aaf5b9dc0b7986b9e42a8ed43d5a906f5222`) — Analyze, Tests, Android Release APK build, signing-file cleanup, generated-source save and artifact upload all SUCCESS.
- [x] Artifact: `OFFYNEXBD-Android-APK`, 49,987,088 bytes; available until 2026-11-24T18:45:21Z.
- [x] Artifact download: https://api.github.com/repos/Digital24Online/OFFYNEXBD/actions/artifacts/14358866885/zip
- [x] Build #167 adds only further formula edge-case tests; the application source is unchanged from Build #166. Build #167 Analyze and all Tests also passed. Its redundant APK step was still running at this checkpoint.
- [x] Therefore the current application source has a verified successful Android APK build; Build #167's additional test-only commit remains under final workflow confirmation.

## OFFYNEX Sheets — XLSX Import Safeguards Verified — 2026-11-18

- [x] Multi-worksheet XLSX imports now explicitly let the user select one worksheet.
- [x] The import flow clearly states that only the selected worksheet is imported; other worksheets remain in the original XLSX and are not silently merged or discarded.
- [x] Added a pre-import workbook-size guard: worksheets exceeding 1,000 rows or 100 columns are rejected before the current workbook is replaced.
- [x] Added automated boundary, over-limit and invalid-dimension tests.
- [x] Build #170 (run ID 44156020614; commit `be700e6fed9639798297f6aa957b00c4c4cef3d6`) completed SUCCESS.
- [x] Flutter Analyze — SUCCESS.
- [x] Full automated test suite — SUCCESS.
- [x] Android APK build, signing-file cleanup, generated-source save and APK upload — SUCCESS.
- [x] Artifact: `OFFYNEXBD-Android-APK`, 50,005,546 bytes; available until 2026-11-24T19:20:57Z.
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44156020614
- Artifact download: https://api.github.com/repos/Digital24Online/OFFYNEXBD/actions/artifacts/14360978705/zip
- [ ] Remaining Sheets features are not complete: multi-sheet workbook management, charts, sorting/filtering, pivot tables, data validation, conditional formatting, ODS/CSV import/export, advanced print-preview controls, larger-workbook performance and physical Android/printer visual verification.

## OFFYNEX Sheets — CSV Import/Export Verified — 2026-11-18

- [x] Added a dedicated CSV codec with UTF-8/BOM handling and correct parsing/encoding for commas, escaped quotes, CRLF/LF, quoted multiline cells and Bengali text.
- [x] Added Import CSV and Export CSV actions in the Sheets File and Data ribbons; labels support Bangla and English.
- [x] CSV import validates the 1,000-row × 100-column workbook limit before replacing the current sheet and asks for confirmation; it explains that CSV does not preserve formatting.
- [x] CSV export writes the used worksheet range; formula contents are exported as formula text.
- [x] Added automated CSV codec tests for Bengali, quoted values, commas, multiline cells, BOM, trailing newline, malformed quoting and round-trip behavior.
- [x] Updated `modules/sheets/README.md` with CSV behavior and known limitations. CSV does not preserve cell formatting; imported cells are unformatted. ODS import/export remains unimplemented.
- [x] Build #178 (run ID `44160413539`; commit `ef7d4a62efb68d78ab14e96bcf51f3d5ee0ad6e8`) completed SUCCESS.
- [x] Flutter Analyze — SUCCESS.
- [x] Full automated test suite — SUCCESS.
- [x] Android APK build, signing-file cleanup, generated-source save and APK upload — SUCCESS.
- [x] Artifact: `OFFYNEXBD-Android-APK`, 50,028,708 bytes; artifact ID `14363800988`; available until 2026-11-24T19:42:58Z.
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44160413539
- [ ] Remaining Sheets features: multi-sheet workbook management, charts, pivot tables, data validation, conditional formatting, ODS import/export, advanced print-preview controls, larger-workbook performance and physical Android/printer visual verification.


## OFFYNEX Sheets — Display-only Sorting and Filtering Verified — 2026-11-18

- [x] Added selected-column A→Z / Z→A sorting; selecting the same column toggles direction.
- [x] Added case-insensitive substring filtering and combined sort + filter.
- [x] Blank cells remain at the bottom; equal values retain their original row order.
- [x] Sorting/filtering changes only the displayed row order. Underlying worksheet cells, formulas, styles and formula references remain in their original positions.
- [x] Clear sort/filter restores the original row order. CSV import, XLSX import and Clear Sheet reset the view state.
- [x] Bangla and English ribbon labels are provided.
- [x] Automated tests cover alphabetical/numeric sorting, blank-last, case-insensitive filtering, combined operations, original-order restoration and selected-cell column parsing.
- [x] Build #193 (run ID `44247321633`; commit `66c8d1caa8bc702d77c8b70d4a62bc9c5257e5d9`) completed SUCCESS.
- [x] Flutter Analyze — SUCCESS.
- [x] Full automated test suite — SUCCESS.
- [x] Android APK build, signing-file cleanup, generated-source save and APK upload — SUCCESS.
- [x] Artifact: `OFFYNEXBD-Android-APK`, 50,036,028 bytes; artifact ID `14402816557`; available until 2026-11-25T05:59:46Z.
- Run URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44247321633
- [ ] Physical Android/device and printer visual verification remains separate from CI. This feature does not imply full Excel sorting/filtering parity or completion of the Sheets module.

## OFFYNEXBD — Integrated 10-Module Restart and Repository Audit — 2026-11-18

### Binding development instruction
- The development target is the complete OFFYNEXBD product across all ten modules in one coordinated project-wide programme: Writer, Sheets, Slides, PDF, Fonts, AI Assistant, Cloud, Forms, Scan and Database.
- Do not return to one-feature-at-a-time work or ask the user to repeat this instruction.
- Audit and plan all ten modules together; preserve all existing source code, user data, formulas, Writer Quill Delta/table/image records, workbook records and document metadata.
- A module tile, README plan or placeholder screen is not a completed module. Never report planned or placeholder functionality as implemented.
- Bangla and English support is required throughout the app. Keep the Android-first workflow and cross-platform architecture.
- The user works from an Android phone and does not provide source uploads or screenshots. Do not ask for old completed work to be repeated.

### Repository and CI checkpoint
- Repository: `Digital24Online/OFFYNEXBD`, branch `main`.
- Repository head at audit start: `56f803f3b29fbb56eb242a3cbda8aed0b0c26d9c`.
- Build #194 (run ID `44248269429`, source commit `3e2d2cdec22041abd98f533f1dd586a26d5ed98e`) — SUCCESS.
- Build #194 Analyze, automated tests, Android APK build, signing cleanup, generated-source save and APK upload all succeeded.
- Artifact: `OFFYNEXBD-Android-APK`, artifact ID `14402527828`, 50,036,037 bytes; not expired at audit time.
- Build #194 URL: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44248269429
- This verifies the source at the build commit only; it does not mean all ten modules are complete.

### Source audit — current implemented reality
- Home screen lists all ten modules, but `lib/main.dart` routes only Writer, Sheets and PDF. The other seven tiles display a “coming soon” message.
- Actual module source currently exists for Writer, Sheets and PDF-to-Document conversion. No dedicated production Dart module implementation currently exists for Slides, Fonts, AI Assistant, Cloud, Forms, Scan camera workflow or Database.
- Writer has a substantial Quill editor, local autosave, page layout, table/image embeds, references, review/comments/revisions, view controls and shaped PDF export foundations. Its README is stale and still says “Planned”; full DOCX/ODT import/export, portable image packaging, real page fidelity, font management and remaining cross-platform verification are not complete.
- Sheets has a working single-sheet grid, local autosave, cell formatting, XLSX/CSV import/export, 31 formula functions, display-only sort/filter and PDF/print foundations. Multi-sheet management, cross-sheet formulas, charts, pivot tables, data validation, conditional formatting, ODS, advanced print preview and large-workbook performance remain incomplete.
- PDF currently provides PDF-to-Writer/DOCX conversion and image-to-document OCR workflows. It is not yet a complete PDF reader/editor/organizer; page operations, annotations, signatures, compression, encryption/password handling and full scanned-PDF renderer/OCR coverage remain incomplete.
- Slides, Fonts, AI, Cloud, Forms, Scan and Database are still planned-only according to their module READMEs.
- Current dependencies include Flutter, SharedPreferences, Quill, file picker, XLSX, PDF/printing, DOCX reader/export and Tesseract OCR. The current dependency manifest does not yet include a presentation engine, ODS engine, camera/document-edge scanner, local relational database engine or cloud sync/auth backend. Select dependencies only after compatibility/licensing/platform review; do not add pretend online sync or AI without a real configured service.

### Coordinated implementation scope
- Shared application foundation: persistent Bangla/English language setting, module navigation, shared file/document handling, common storage/backup interfaces, error/progress handling, accessibility and cross-module document handoff.
- Writer: finish portable editable-document import/export and page/print fidelity while retaining old Quill documents and embeds.
- Sheets: finish multi-sheet workbook architecture and the remaining spreadsheet/data/print features without changing the existing workbook schema incompatibly.
- Slides: editable presentation/deck model, layouts/themes, text/images/shapes, notes, transitions/slideshow and supported PPTX/ODP/PDF import/export.
- PDF: reader/viewer, page management, annotations, forms/signatures where supported, merge/split/compress/protect/print, OCR and conversion.
- Fonts: real font catalogue/preview/management, supported font import and licensing-safe embedding, Unicode Bengali/English and legacy Bijoy ANSI conversion workflow. Never redistribute proprietary fonts without permission.
- AI Assistant: Bangla/English writing, translation, summary, formula/data and presentation assistance; disclose online service requirements and privacy. Do not claim offline AI unless a real on-device model is integrated.
- Cloud: authenticated storage, sync, versioning, sharing, encryption and conflict recovery; do not label local-only storage as cloud sync.
- Forms: builder, field types, validation, save/edit responses, PDF/CSV/XLSX export and secure sharing.
- Scan: camera capture, automatic document boundary detection, perspective correction, enhancement, multi-page PDF and Bengali/English OCR with correction/review.
- Database: offline relational data model, tables/fields/relations, CRUD, query/filter/report, import/export and backup/restore.
- Cross-module integration: Writer/Sheets/Slides/PDF/Forms/Scan/Fonts/AI/Cloud/Database handoff and shared file formats.
- Complete automated tests, Analyze, Android release APK/artifact and platform-specific verification must be recorded accurately. Physical device/camera/printer checks must remain explicitly pending until actually performed.

### Audit status
- [x] Confirmed separate repository and current main branch.
- [x] Confirmed latest successful Build #194 and its APK artifact.
- [x] Inspected Home Screen routing, dependency manifest, CI workflow, all ten module READMEs, and current Writer/Sheets/PDF source/test inventory.
- [ ] Project-wide implementation and integration of all ten modules — NOT COMPLETE.
- [ ] End-to-end cross-module and platform verification — NOT COMPLETE.

## Integrated 10-Module Workspace Foundation — 2026-11-18

### Implemented in the coordinated batch
- [x] Added shared offline-first workspace source: `lib/lib/modules/workspace/office_workspace_screen.dart`.
- [x] Connected Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database from Home Screen. Existing Writer, Sheets and PDF routes remain intact.
- [x] Added per-module versioned local draft storage using separate SharedPreferences keys; create, edit and delete operations do not overwrite Writer or Sheets storage.
- [x] Slides workspace stores presentation titles and slide text drafts.
- [x] Fonts workspace stores font catalogue entries and notes. Dynamic font installation and editor-wide font activation are not implemented yet.
- [x] AI Assistant workspace stores Bangla/English prompts and drafts. It does not claim to generate AI answers; a secure AI provider connection remains pending.
- [x] Cloud workspace creates a JSON backup of OFFYNEXBD SharedPreferences data and restores compatible OFFYNEXBD keys after confirmation. This is local backup/restore, not online Cloud Sync.
- [x] Forms workspace stores form titles and question drafts. Response collection, validation and sharing remain pending.
- [x] Scan workspace accepts an image file, uses the existing Bengali/English OCR conversion service and saves recognized content as a Writer document. Camera capture, automatic edge detection and perspective correction remain pending.
- [x] Database workspace stores table/schema notes. A relational database engine, query runner and data editor remain pending.
- [x] Home Screen Bangla/English choice is now persisted with `offynex_language_bangla_v1`.
- [x] Added widget tests for Forms draft persistence, Database schema editing and local Cloud backup generation.
- [x] Flutter Analyze passed on source commit `dd63993b412fe097248df0d1e3f6e17339ec3927`.
- [x] Build run `44250644711`: Flutter Analyze — SUCCESS; full automated test suite — SUCCESS (including the new workspace tests).
- [ ] Android NDK installation, release APK build and artifact upload are still running in Build run `44250644711`.
- [ ] Physical Android, camera, printer and desktop acceptance tests remain pending.

### Test correction
- Initial integrated workspace tests exposed dialog TextEditingController disposal before the reverse route animation finished.
- Replaced parent-owned dialog controllers with a dedicated Stateful dialog that disposes controllers with its own widget lifecycle.
- The corrected source is commit `b69e17d4faade43cd6128eb6ffdf97f572ade489`; verify via Build run `44250644711` before marking the batch CI-verified.

### Remaining coordinated product work
- The seven new workspaces are functional local foundations, not complete commercial-grade modules.
- Continue coordinated implementation across all ten modules: real Slides/PPTX, complete PDF tools, installable and activatable font management plus Bijoy conversion, configured AI service, authenticated cloud sync, interactive Forms and responses, camera-based advanced scanner, relational Database, and richer Writer/Sheets format and feature coverage.


## Verified Integrated Workspace Foundation — 2026-11-18 (Build #200)

### Shared module workspace batch
- [x] All seven previously missing Home Screen routes now open dedicated offline-first workspaces: Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database.
- [x] Each workspace uses its own versioned SharedPreferences key; create/edit/delete draft records are available without overwriting Writer or Sheets storage.
- [x] Scan image OCR reuses the existing Bengali/English OCR conversion service and saves recognized text as a Writer document.
- [x] Cloud local backup/restore includes OFFYNEXBD-prefixed SharedPreferences values only. This is local/file backup, not online cloud synchronization.
- [x] Bangla/English preference is persisted.
- [ ] These are foundational workspaces, not completed full-featured modules. Slides rendering/PPTX export, dynamic font activation, secure AI service, online cloud sync, Forms responses/sharing, camera scanning enhancements and relational database engine remain future work.
- [x] Build #200 (run ID 44250644711; source commit b69e17d4faade43cd6128eb6ffdf97f572ade489): Flutter Analyze SUCCESS, complete automated test suite SUCCESS, Android APK build SUCCESS, signing cleanup SUCCESS, generated source save SUCCESS and APK upload SUCCESS.
- [x] APK artifact: OFFYNEXBD-Android-APK (50,111,069 bytes; artifact ID 14403333452; available until 2026-11-25).
- [x] Run: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44250644711

### Portable Cloud backup improvement — validation pending
- [x] Added a versioned backup codec with strict format/version checks, OFFYNEXBD-only key validation and supported SharedPreferences value validation.
- [x] Added JSON file export and import using the existing file picker; restore remains confirmation-gated.
- [x] Added codec tests for supported-value round trip, unsupported versions, foreign keys and invalid value types.
- [ ] Workflow #203 (run ID 44251489785) exposed two curly-brace lint findings in the new backup error handlers; both were corrected in commit `0f94cb4f78b6fd892071dedb47f36e94cc8660ba`.
- [ ] Latest validation is running in workflow #204 (run ID 44251710031). Do not mark this improvement verified until Analyze, all tests and Android APK build/upload pass.
- [ ] Online cloud sync remains unimplemented; do not describe local backup as cloud sync.

### Integrated development rule
Continue development as coordinated batches across Writer, Sheets, Slides, PDF, Fonts, AI Assistant, Cloud, Forms, Scan and Database. Audit shared dependencies and data compatibility before edits; preserve existing user data and features; add regression tests; run Analyze, full tests and Android APK build before marking any batch verified.


## Coordinated Workspace Data Portability — 2026-11-18 (validation pending)

- [x] Added a module-scoped JSON record format for Slides, Fonts, AI Assistant, Forms and Database.
- [x] Added strict format/version/module checks, record field validation, duplicate-ID rejection and a 10,000-record safety ceiling.
- [x] Added JSON Export and Import actions to the five draft workspaces.
- [x] Import is additive: records whose IDs already exist are skipped; existing records are never replaced. Import is capped at 10 MB.
- [x] Added automated codec tests for round-trip, cross-module rejection, duplicate/invalid records and unsupported module names.
- [ ] Run #207 (ID 44252236191) validates this source batch. Do not mark it verified until Analyze, all tests and Android APK build/upload succeed.
- [ ] These JSON files are an app-specific interchange format, not PPTX, ODT, DOCX, XLSX or an installable font package. Native formats and full module functionality remain in the coordinated roadmap.


## Shared Workspace Search and Import Safety — 2026-11-18 (validation pending)

- [x] Added case-insensitive search across saved titles and content in Slides, Fonts, AI Assistant, Forms and Database workspaces.
- [x] Search is non-destructive and only filters the visible list; stored records are not changed.
- [x] Added a widget regression test confirming title/content filtering.
- [x] CI exposed an async BuildContext lint issue after the workspace JSON file read; added a mounted guard immediately after the await.
- [ ] Latest source after the mounted-guard correction is commit `5a6512be200f49023f1d311af1f6106679fa8938`; wait for its own workflow to pass before marking the search/import batch verified.


### Portable Cloud backup validation result — Build #204
- [x] Corrected backup file export/import source commit `0f94cb4f78b6fd892071dedb47f36e94cc8660ba` passed Flutter Analyze and the full automated test suite.
- [x] Android APK build and upload succeeded.
- [x] Artifact: `OFFYNEXBD-Android-APK`, ID `14403898235`, 50,116,699 bytes; run `44251710031`.
- [x] Run: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44251710031
- [ ] This artifact validates the backup feature only; later workspace record import/export and search commits are being tested separately.


### Search UI regression test correction
- [x] Build #210 Flutter Analyze passed. The test suite found that adding the workspace search box changed TextField ordering in two older widget tests; the product UI behaved as intended, but tests still targeted the old field indices.
- [x] Updated the Forms test to target dialog title/content fields after the search field, and the Database test to target the dialog content field explicitly.
- [ ] Re-run validation for commit `bbc6bd7a2cc9e81eb250515b6815388391e880d6`; full tests and APK build are still pending.


### Build #211 Forms test finding and correction
- [x] Flutter Analyze passed.
- [x] Search regression test passed.
- [x] The Forms widget test still used field indices from before the search field was added. Corrected it to target dialog title/content fields (indices 1 and 2 after the search field).
- [ ] Revalidate commit `fccd1f4006b52f6d004734d6bdadcc71a1e4dc6d` in the next workflow; Build #211 test failure was limited to the stale Forms test selector.


## Writer Document Portability — 2026-11-18 (validation pending)

- [x] Added a dedicated versioned Writer archive codec; it preserves complete Writer records, including Quill Delta content, page layout, comments, citations, revisions and writer metadata.
- [x] Added Writer library JSON Export and Import actions.
- [x] Import is additive and skips existing IDs; it never replaces an existing document. Invalid versions, malformed records and duplicate IDs are rejected.
- [x] Archive file size is capped at 20 MB and the archive is capped at 10,000 documents.
- [x] Added codec round-trip, metadata-preservation and invalid/duplicate-record tests.
- [ ] Validate commits `83d5a447`, `1356f67b`, `6841b92d`, and `6b38028a` in the latest CI run before marking this Writer feature verified.


### Writer archive static analysis correction
- [x] The first Writer archive Analyze run found one redundant `dart:typed_data` import (the existing Flutter services import already exposes `Uint8List`). Removed it in commit `9a8600c39a357b7fbcf65afa3473365c30d9e8c8`.
- [ ] Re-run Analyze, Writer codec tests, complete tests and APK build against the corrected source.


## Data Recovery Safety — Writer + Sheets (2026-11-18, validation pending)

- [x] Writer: malformed document-library JSON is copied to a timestamped `offynex_writer_documents_recovery_*` SharedPreferences key before the library is shown as empty; the user receives a warning.
- [x] Sheets: malformed workbook JSON is parsed into temporary collections first, preventing partial state mutation; on failure the original raw workbook is copied to `offynex_sheets_workbook_recovery_*` before a fresh sheet is shown.
- [x] Both recovery keys remain OFFYNEXBD-prefixed, so they are included in the local Cloud backup.
- [x] Added tests proving the original raw data remains stored and a recovery copy is created.
- [ ] Revalidate all Writer archive and recovery changes plus Sheets recovery changes in CI before marking complete.


### Workspace JSON Import/Export + Search — Build #212 verified
- [x] Build #212 (run ID `44253188504`, commit `fccd1f4006b52f6d004734d6bdadcc71a1e4dc6d`) passed Flutter Analyze, the complete automated test suite, Android signing setup, NDK setup, APK build and artifact upload.
- [x] Artifact `OFFYNEXBD-Android-APK`: ID `14405660426`, size 50,151,865 bytes.
- [x] Run: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44253188504
- [x] This validated the five workspace modules' module-scoped JSON import/export and search, including corrected Forms/Database regression tests.
- [ ] Writer archive and Writer/Sheets data-recovery safeguards are newer changes and remain pending validation in Builds #217–#221.


## Verified Writer/Sheets recovery and archive batches — 2026-11-18

- [x] Build #217 / run `44253702842`: Writer archive codec, round-trip tests, and Writer archive import/export passed Analyze, full tests and APK build/upload. Artifact ID `14405506006`, size 50,156,776 bytes.
- [x] Build #218 / run `44253995059`: Writer recovery-copy safeguard passed Analyze, full tests and APK build/upload. Artifact ID `14405566194`, size 50,158,665 bytes.
- [x] Build #219 / run `44254056707`: Sheets damaged-workbook recovery safeguard passed Analyze, full tests and APK build/upload. Artifact ID `14405142125`, size 50,158,659 bytes.
- [x] Build #220 / run `44254121323`: Writer recovery test and complete source batch passed Analyze, full tests and APK build/upload. Artifact ID `14406130479`, size 50,159,788 bytes.
- [ ] Build #221 / run `44254160203`: Writer recovery test source commit `5bcd2500c261b7498615811cf26ec5dd2c0363a9`; Analyze/tests passed, Android APK build still running at last check.
- [ ] Forms response collection is implemented locally: one question per line, response form, additive saved responses, response viewer, and recovery copy for malformed response archives. Online form sharing is not implemented.
- [ ] Corrected Forms newline splitting to handle actual LF/CRLF lines and updated module guidance. Added widget test for multi-question response collection, local persistence and response viewer. Commits after Build #222 started require a fresh CI run.


### Forms response test correction + general workspace recovery
- [x] Build #221 / run `44254160203` completed successfully: Writer recovery-copy tests passed, Android APK build and upload succeeded.
- [x] Forms response collection test now exercises three newline-separated questions, saves all answers locally and checks the Responses viewer. Build #226 (`44255228472`) has passed Analyze and the complete test suite; APK build was still running at the last check.
- [x] Fixed the Forms question split expression to support LF/CRLF and corrected the widget test fixture/assertions.
- [x] Added common recovery-copy handling for malformed Slides, Fonts, AI Assistant, Forms and Database workspace record files. Original raw JSON is preserved under a module-specific `_recovery_*` SharedPreferences key before the workspace shows an empty list.
- [x] Added a widget test proving malformed workspace JSON remains intact and is copied to recovery storage.
- [ ] Latest commits `e9f2f0bc9d0c92507318c4409674fda83be7858e`, `8f31c781d61ccf724d76227df30f98eb700d3e09`, and `715031c6e97b114edd24ba58a3489dc7b05e7527` need their own successful Analyze, full tests and APK build/upload before these newest changes are marked verified.


### Forms response collection — Build #226 verified
- [x] Build #226 / run `44255228472` passed Analyze, all tests, Android APK build and artifact upload. Artifact ID `14405858046`, size 50,178,349 bytes.
- [x] Validated three-question Forms response collection, local response persistence and response viewer.
- [x] Forms response data is stored under an `offynex_` key and included in the local Cloud backup.
- [x] Added JSON export of collected responses, separate from the form-definition archive.
- [ ] New response-export implementation in commit `985dbf1e29d0e751d7349a47c6241dd85118e3cd` still needs CI verification.

### PDF conversion navigation integrity — validation pending
- [x] PDF/Image conversion screen now retains the exact record it just created and opens that record in Writer. It no longer searches by filename, which could open an older conversion with the same name.
- [x] Removed obsolete filename-matching state.
- [ ] Validate commits `54b8802044c234d4c288c5e01d7df52be0145484` and `644a35d822d03365a964b9cb1d3d697f409dee51` with Analyze, full tests and APK build/upload.


### Additional coordinated module work — 2026-11-18 (validation pending)
- [x] Forms response viewer now has a separate JSON export for collected submissions, including format/version and export timestamp. Existing form definitions and responses remain separate; all remain included in the local Cloud backup.
- [x] PDF-to-Writer navigation now opens the exact record created by the current conversion rather than searching by filename, preventing duplicate-filename collisions.
- [x] Slides now has a landscape PDF export: one non-empty content line becomes one slide page; Bangla font is embedded; export is capped at 200 slides.
- [x] Extracted PDF generation into `slides_pdf_export_service.dart` and added tests for Bangla/English PDF output and slide-count limits.
- [ ] Validate latest Forms response export, PDF navigation and Slides PDF export commits with Flutter Analyze, full test suite and Android APK build/upload. No claim of PPTX or full slideshow support: those remain future work.


### Slides PDF service lint correction
- [x] First Analyze runs for the extracted Slides PDF service identified one redundant `dart:typed_data` import (Flutter services already exposes `Uint8List`). Removed in commit `05274986d428301a38046e48e69e78645ebd6ffb`.
- [ ] Revalidate the corrected Slides PDF service and test in the next CI workflow; do not mark Slides PDF export complete until the full Android build succeeds.


### Forms + workspace recovery — Build #229 verified
- [x] Build #229 / run `44255669985` passed Flutter Analyze, full tests, Android APK build and upload. Artifact ID `14405983212`, size 50,177,256 bytes.
- [x] This verifies Forms response collection test assertions and the Forms question parsing correction present in that source commit.
- [ ] Workspace-wide damaged-record recovery and the newest Forms response export still require the later Build #227/#228/#231+ source runs to finish successfully; do not use #229 as proof for later commits.


### General workspace recovery + PDF navigation — verified builds
- [x] Build #227 / run `44255537457`: module-wide damaged workspace record recovery passed Analyze, all tests, APK build/upload. Artifact ID `14406396484`, size 50,177,257 bytes.
- [x] Build #228 / run `44255575772`: added regression test proving original malformed workspace JSON is preserved before showing an empty workspace; Analyze, all tests and APK build/upload passed. Artifact ID `14406357390`, size 50,177,251 bytes.
- [x] Build #230 / run `44256035950`: PDF/Image conversion now opens the exact newly created Writer document; Analyze, full tests and APK build/upload passed. Artifact ID `14405254164`, size 50,181,529 bytes.
- [ ] Forms response JSON export and Slides PDF export are newer changes and remain pending their own successful CI run.


### PDF conversion follow-up — Build #232 verified
- [x] Build #232 / run `44256236814` passed Flutter Analyze, all tests, Android APK build and artifact upload after removing obsolete PDF conversion state. Artifact ID `14405399366`, size 50,178,601 bytes.


### Slides PDF export CI checkpoint
- [x] Build #238 / run `44256863470` on corrected source commit `05274986d428301a38046e48e69e78645ebd6ffb`: Flutter Analyze passed; complete test suite passed, including the new Bangla/English Slides PDF export and slide-count validation tests.
- [ ] Android APK build and artifact upload were still running at the last check; wait for final success before marking Slides PDF export fully verified.


### Database offline row CRUD — 2026-11-18 (validation pending)
- [x] Added a dedicated table-row editor for Database workspace tables.
- [x] Supports creating, editing and deleting rows with field/value mapping; row data is stored per stable table ID in `offynex_database_rows_v1`.
- [x] Supports 1–40 comma-separated fields per table; malformed database-row JSON is copied to a timestamped recovery key before recovery.
- [x] Added widget test for creating a customer row and editing its values while preserving the other field.
- [x] Updated Database help text to distinguish offline row CRUD from the still-unimplemented SQL/relational query engine.
- [ ] Validate commits `1f1a41945bd28e23a74db63a4b3ff14a32ae1367`, `307d3ffdd6bfae6e4ef49739a35e029d7376331f`, `9c9533fb7f20c17c755f5f2881d627be977493fa`, and `7e26c33081e465d4b99c40243e2abea61c486961` in CI before marking verified.


### Forms response export + Slides PDF UI — verified base builds
- [x] Build #233 / run `44256457158` passed Analyze, complete tests, Android APK build/upload. Artifact ID `14407125344`, size 50,205,363 bytes. This source includes Forms response JSON export, exact PDF conversion record navigation, and initial Slides PDF export UI.
- [x] Build #234 / run `44256512065` passed Analyze, complete tests, Android APK build/upload. Artifact ID `14406243473`, size 50,204,851 bytes.
- [ ] Later refactor of Slides PDF generation into a separately tested service initially exposed one redundant import lint; corrected in commit `05274986d428301a38046e48e69e78645ebd6ffb`. Build #238 passed Analyze and tests; APK build still pending.


### Database row CRUD analyzer correction
- [x] First Analyze run for Database row CRUD found a BuildContext async-gap warning before opening the row editor. Added a mounted guard after asynchronous preference/recovery work in commit `8564cb71b42724be374550b6bf3b4bdf1e427af3`.
- [ ] Revalidate Database row CRUD and tests in the next CI run.


### Forms response JSON export — Build #231 verified
- [x] Build #231 / run `44256187962` passed Analyze, full tests, Android APK build and upload. Artifact ID `14405339663`, size 50,178,656 bytes.
- [x] This validates the separate versioned JSON export of locally collected Forms responses.


### Slides PDF export — Build #238 verified
- [x] Build #238 / run `44256863470` passed Flutter Analyze, complete tests (including Bangla/English Slides PDF generation and 200-slide limit checks), Android APK build and upload.
- [x] Artifact `OFFYNEXBD-Android-APK`: ID `14407300215`, size 50,205,409 bytes.
- [x] Slides export currently creates a landscape PDF, one content line per slide; this is PDF output, not PPTX.


### Database row editor lifecycle correction
- [x] Build #243 passed Analyze but the new Database CRUD widget test exposed a controller-lifecycle bug: controllers were disposed immediately after the nested dialog began its closing animation.
- [x] Moved row-editor controllers into a dedicated stateful dialog so they are disposed only when the dialog widget is actually removed. Fix commit: `24e69adbc861e0f0cd5bd1882de176ee089442a2`.
- [ ] Re-run the complete tests and Android build for Database row CRUD; do not mark this feature verified until successful.


### Database CRUD corrected test checkpoint
- [x] Build #244 / run `44258247618` passed Flutter Analyze and the complete test suite after moving TextEditingControllers into the nested row-editor widget.
- [ ] Android NDK setup and APK build were still running at the last check. Wait for artifact upload before marking Database row CRUD fully verified.


### Database row CRUD — Build #244 verified (2026-11-18)
- [x] Build #244 / run `44258247618`, source commit `24e69adbc861e0f0cd5bd1882de176ee089442a2`: Flutter Analyze passed, full test suite passed, Android APK build passed, artifact upload passed.
- [x] Artifact `OFFYNEXBD-Android-APK`: ID `14406877998`, size 50,231,735 bytes.
- [x] Database offline row create/edit/delete workflow and controller-lifecycle regression test are verified by this build.
- [x] Build #239 / run `44257520506`, source commit `1f1a41945bd28e23a74db63a4b3ff14a32ae1367`, also passed all CI stages; artifact ID `14406612497`, size 50,205,416 bytes.


### Sheets destructive XLSX import safety — validation pending (2026-11-18)
- [x] Before replacing the active Sheets workbook with an imported XLSX worksheet, the app now saves the exact previous workbook JSON under a timestamped `offynex_sheets_import_backup_*` SharedPreferences key.
- [x] If the backup cannot be saved, the import is cancelled before the in-memory workbook is replaced. The original primary workbook key is left intact until the normal save after import.
- [x] XLSX import now rejects files larger than 20 MB before decoding; the existing workbook remains unchanged.
- [x] Added unit tests for exact backup preservation, no-existing-workbook behavior, and the 20 MB boundary.
- [x] Build #252 / run `44260743427`, source commit `cc1d2677eebd134279213479ca776584fc0e37d2`, passed Flutter Analyze, complete test suite, Android release APK build and artifact upload. Artifact `OFFYNEXBD-Android-APK`: ID `14408226617`, size 50,234,182 bytes. The corrected XLSX import backup integration is verified.
- [ ] Multi-worksheet editing inside OFFYNEX Sheets remains future work; current import still imports one selected worksheet at a time.

- [x] Follow-up safety refinement: XLSX replacement now waits for the pending save queue before reading the current workbook, ensuring the backup includes the latest edits (commit `8f51750409b0d139310adb34de8c9a12757ab585`).


### Sheets XLSX import safety integration correction — 2026-11-18
- [x] CI runs #249–#251 exposed that the first automated edit placed the backup block in the CSV import method and left its variable out of scope in XLSX import. Those runs failed at Flutter Analyze; no APK was produced from those source revisions.
- [x] Corrected the code in commit `cc1d2677eebd134279213479ca776584fc0e37d2`: CSV import restored to its original flow; backup logic now lives only in XLSX replacement and the backup key is used in its success message.
- [x] Manually inspected both import paths and confirmed the XLSX path waits for pending saves, preserves the previous workbook, then replaces the active worksheet.
- [x] Build #252 / run `44260743427` completed successfully on the corrected integration commit; Analyze, full tests, Android APK and artifact upload all passed.


### Native Android Document Scanner — implementation pending CI (2026-11-18)
- [x] Added `google_mlkit_document_scanner: ^0.4.1`, selected because its documented requirements match the existing Android compile/target SDK 35 baseline and the current Flutter/Dart toolchain. The package provides Android-native automatic document capture, edge detection, crop/perspective correction, rotation, filter/cleanup UI, and PDF/JPEG output. It is Android-only in this version; other platforms retain the existing image-picker OCR path.
- [x] Added `lib/lib/modules/workspace/scan_document_service.dart`: full scanner mode, gallery import, up to 50 pages, JPEG + PDF output, 50 MB PDF cap, per-page 30 MB OCR input cap, saved PDF under app documents, and Bengali+English OCR for each captured page.
- [x] Native scanner cancellation is handled without an error alert. The Android plugin returns local filesystem paths for PDF and page images; the integration uses those paths directly.
- [x] Extracted reusable `PdfToDocumentService.recognizeImageBytes` so native multi-page scanning can OCR each page without creating a throwaway DOCX for every page. Existing single-image conversion now uses the same helper.
- [x] Scan screen saves recognized text as a Writer document with scan PDF path/page metadata and provides a PDF share action. If OCR finds no text, the captured PDF is still saved and can be shared.
- [x] Added tests for ordered multi-page OCR text aggregation and updated `modules/scan/README.md` with platform support and limits.
- [ ] Full Analyze, tests, Android release APK and artifact upload remain pending for the scanner integration. Do not mark it verified until the latest-source workflow succeeds.
- [x] Added workflow concurrency control so rapid source commits cancel superseded builds and preserve resources for validating the newest main-branch source.

Key commits: `94a7934f5b745f2517d6501d7ae4b9eecccbef99` (dependency), `3eea3832466fa15dcb73804b4cc626591695d743` (scanner service), `613ca21812ef23fafe4ecd028ce84b2a60ce9c97` (reusable OCR), `df1e074d12c49d050a62a05631868e68d99bb578` (screen integration), `324cd19aec79219a71594fcf8671eb9a28330d8a` (cancellation/path correction), `d3e82d4b4c559f1b4addd59216137f2d77b53c78` (tests), `aa9b8a1936ed0663df8616c7d853abcda9fa4149` (CI concurrency).


### Sheets XLSX import safety — Build #252 verified
- [x] Build #252 / run `44260743427`, source `cc1d2677eebd134279213479ca776584fc0e37d2`: Analyze, full tests, Android APK and artifact upload passed.
- [x] Artifact `OFFYNEXBD-Android-APK`: ID `14408226617`, size 50,234,182 bytes.
- [x] The pre-import backup, pending-save queue ordering, backup failure abort behavior, and 20 MB XLSX file-size boundary are now covered by the verified source/test suite.

### Scan integration corrections after first CI attempt
- [x] Build #257 exposed a malformed source splice in the workspace screen; the duplicate tail was removed and the Scan method was restored as one bounded method in commit `c7dec759456f7b232608a95d3d9f8b5f0a38b860`, then interpolation and extension regex were corrected in `8552a0f2922480cdc4ea694adf0fe7506c1ffd2f`.
- [x] Native scanner service now handles Android cancellation and uses the local file paths returned by the plugin. The native Android plugin returns filesystem paths for the PDF and page images.
- [x] Multi-page OCR separators now use real newline characters. The scanned PDF is saved to app documents before OCR begins, so OCR failure cannot discard the captured PDF (commit `b06e579c11edfe3e61f086ac912feb4589ee9617`).
- [ ] Latest-source Build #267 / run `44261674201` is pending; its Analyze, full tests, Android APK and artifact upload must all pass before the native scanner is marked verified.

- [x] Build #267 / run `44261674201` reached Analyze but failed only on one lint: redundant `dart:typed_data` import in the new Scan service (the import is already re-exported by Flutter services). Removed the redundant import in commit `f7c862dec623613b48e107242d6def03b65b2ff4`.
- [ ] Build #268 / run `44261927870` validates that lint correction and the latest native Scan source; Analyze, full tests, Android APK and artifact upload remain pending.
## Writer integrated completion batch — 2026-11-18 (CI validation pending)

- Re-audited the existing Writer source and progress history. Serials 14.6 (Images), 15 (Layout), and 16 (References/Review/View) were already implemented; Serial 16 had passed Build #35. They were preserved rather than repeated.
- Passed the app's selected Bangla/English language setting into Writer and localized the Writer library shell, editor shell, ribbon tabs, common status labels and document menu.
- Added per-document Header and Footer metadata with `{page}` and `{pages}` placeholders. Writer PDF/print output now renders repeating headers, footers and dynamic page numbering.
- Added Save as DOCX using the existing `docx_creator` dependency. Export converts supported rich text/headings and Writer table blocks; image bytes are embedded rather than exporting private local file paths.
- Added DOCX export regression tests, missing-image safety test and PDF header/footer/page-number test.
- Replaced the stale Writer README that incorrectly said the module was only planned. It now records implemented functionality and explicitly documents outstanding format/fidelity boundaries.
- Relevant commits in this batch: `0fec434`, `bd5af56`, `10ed908`, `cb265eb`, `c876708`, `2f622d9`, `214d346`, `9fa34bc`, `d13bf09`, `931527d`, `c889f2f`, `5f71d0d`.
- [ ] Validate the integrated Writer batch with Flutter Analyze, all tests, Android release APK build and artifact upload. Do not mark this batch verified until all stages pass on the final source commit.
- [ ] Remaining product-level Writer gaps: native DOCX import into Quill, ODT import/export, full rich-content on-screen pagination, Word-grade DOCX fidelity for every Quill embed, native spell-check dictionary integration, font management/user font installation, and physical device/printer verification. The current Writer implementation must not be described as complete Microsoft Word parity.


## Latest Integrated Verification — 2026-11-18 (Build #310)

- [x] Repository confirmed active: `Digital24Online/OFFYNEXBD`, default branch `main`; separate repository creation is complete and must not be repeated.
- [x] Latest source commit: `7c028eb4cdb100b728be8420984f34d18172a66e` — Prepare OFFYNEXBD test release update 1.0.1.
- [x] App version: `1.0.1+3`.
- [x] Build #310 / run ID `44274169447` completed successfully on the latest source commit.
- [x] Flutter Analyze — SUCCESS.
- [x] Full automated test suite — SUCCESS.
- [x] Android NDK setup and Android release APK build — SUCCESS.
- [x] Signing-file cleanup and generated-source save — SUCCESS.
- [x] APK artifact upload — SUCCESS; artifact `OFFYNEXBD-Android-APK`, 51,135,413 bytes, created 2026-11-18 and not expired at verification.
- [x] The integrated Writer batch (Bangla/English localization, document Header/Footer metadata, dynamic PDF page numbering, DOCX export with embedded images, and associated regression tests) is validated by this successful latest-source Analyze/test/build workflow.
- [x] The current Sheets recovery/workbook test changes included in this source revision passed Analyze and the full automated test suite.
- [x] Native Android Document Scanner implementation and its included tests are present in the source revision that passed the full workflow.
- [ ] Physical Android device verification of scanner capture, OCR, PDF sharing, Writer editing/export and update installation remains outstanding; automated CI success is not a substitute for device testing.
- [ ] Writer product gaps listed above remain open (native DOCX import, ODT import/export, complete rich-content pagination and full Word-grade fidelity, spell-check dictionary integration, font management and physical printer verification).
- [ ] Continue the next planned product task from the current repository state; do not recreate the repository or redo verified work.


## Professional Design System rollout — 2026-11-18

- [x] Added shared OFFYNEXBD visual tokens and Material 3 theme in `lib/lib/theme/offynex_theme.dart`.
- [x] Redesigned the home dashboard with responsive module cards, refined branding, consistent color, spacing and typography in commit `50d127f7c5cf3b72243a35b24f61e123416267d2`.
- [x] CI Build #312 / run `44283498612`: Flutter Analyze passed, but full tests failed because the redesigned dashboard moved module cards below the automated test viewport and the visible hero tagline no longer matched the established test text. APK build was correctly skipped; do not treat Build #312 as release-ready.
- [x] Corrected dashboard breakpoints and restored the exact visible tagline expected by existing widget tests.
- [x] Redesigned Writer document library as a responsive document-card workspace with a professional empty state, while retaining existing import/export, create, rename, delete, open and local storage behavior.
- [x] Restyled Writer ribbon tabs, editor title surface, app canvas and status strip using the shared theme. Existing Quill controller, autosave, document model, toolbar actions, page layout, tables, images, PDF and DOCX workflows are retained.
- [ ] Validate the dashboard and Writer visual batch with Flutter Analyze, full automated tests, Android release APK build and artifact upload. Do not mark verified until the final source commit passes every CI stage.
- [ ] Continue shared design rollout to Sheets, Slides, PDF, Fonts, AI Assistant, Cloud, Forms, Scan and Database only after this batch passes CI.


- [x] Writer empty-state duplicate create action removed after CI #314 exposed a widget-test ambiguity; create remains available from the persistent New Document action.
- [x] Sheets UI refresh: shared OFFYNEX theme applied to Ribbon tabs/commands, formula bar, grid headers/selection, status area and worksheet tabs. Existing formulas, workbook data, XLSX/CSV import/export, PDF/print, sorting/filtering, formatting and multi-sheet actions are unchanged.
- [ ] Validate latest Writer + Sheets UI batch with Flutter Analyze, complete tests and Android release APK build before calling it verified.

- [x] CI #316 identified a Sheets status/worksheet-bar Container color+decoration assertion. Corrected by moving white surface color into BoxDecoration; Analyze had already passed, and full regression tests are being rerun. No test was removed or weakened.


- [x] Unified shared workspace shell styling for Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database: canvas, app bar, module identity panel, record cards, search field and primary action now use OFFYNEX theme tokens. Existing module-specific actions and local records are unchanged.
- [x] PDF-to-Document conversion screen uses the shared professional app shell and clean card surfaces. PDF/image selection, OCR conversion, Writer handoff and DOCX export logic remain unchanged.
- [ ] Run Analyze, all tests and Android release build for the expanded workspace/PDF visual batch before marking it verified.


## Writer Office Ribbon refinement — 2026-11-18
- [x] Applied classic green Microsoft Office-inspired tab bar and a compact icon-and-label ribbon to Writer while preserving existing editor actions and document workflows.
- [x] Build #320 (commit 251082b1341c9a654df9e67677c71080f24f964f) passed Flutter Analyze but failed an existing Writer Header/Footer widget test because the ribbon panel Container specified both color and decoration; the test could not complete its UI interaction.
- [x] Corrected the Container by moving its surface color into BoxDecoration and widened ribbon commands to improve Bangla label visibility. Existing tests were preserved unchanged.
- [ ] Re-run Analyze, all automated tests and Android APK build for the correction commit; do not call the Writer redesign verified until CI succeeds.
- [ ] Physical Android visual and interaction checks remain outstanding.


## Writer Editable Print Preview — implementation in progress (2026-11-18)

- [x] Rechecked the current main branch and confirmed the existing Print Preview was a read-only `PdfPreview`; the original Quill document editor remained separate.
- [x] Added an Edit action inside the Print Preview screen. It opens the same live Quill document controller, so text and existing table/image embeds can be edited without leaving the preview route.
- [x] Added Save and Preview actions. Saving writes through the existing document save queue before rebuilding the PDF preview, so edits are retained in the original Writer document.
- [ ] Validate Flutter Analyze, all automated tests, Android APK build and artifact upload on the final commit.
- [ ] Improve phone page-fit behavior after checking actual layout constraints; do not shrink the A4 page to unreadable size merely to show its full height.
- [ ] Physical phone and printer verification remains outstanding.


### Database damaged-row preservation safety — validation pending (2026-11-18)
- [x] Database row loading now validates the entire stored row collection before opening the editor: table collections, row IDs, row values maps, and text field values.
- [x] If any stored row is malformed, the original JSON is copied to a timestamped recovery key and the editor stops; it no longer silently filters malformed rows and overwrites the original database store.
- [x] Added widget regression tests for malformed table row collections and malformed field values, asserting that both the original data and recovery copy remain unchanged.
- [x] Build #328 / run `44304003563` on commit `84feaa34e1682c672324b5ba3f9010d2dddd7b42` passed Flutter Analyze, the complete automated test suite, Android release APK build and artifact upload.


## Database damaged-row preservation — Build #328 verified (2026-11-18)

- [x] Commit: `84feaa34e1682c672324b5ba3f9010d2dddd7b42` — Preserve damaged database rows before editing.
- [x] Build #328 / run ID `44304003563` completed successfully on this exact commit.
- [x] Flutter Analyze — SUCCESS; full automated test suite — SUCCESS; Android release APK build — SUCCESS; signing cleanup and APK upload — SUCCESS.
- [x] Regression tests confirm malformed row collections and malformed field values are copied to a recovery key, original stored JSON remains unchanged, and editing is stopped.
- [x] APK artifact: `OFFYNEXBD-Android-APK`, ID `14428305759`, size 51,174,989 bytes; expires 2026-11-25T12:35:52Z.
- [ ] Physical Android device validation remains outstanding; CI success does not replace real-device verification.



## Integrated Data Integrity and Import Safety Batch — 2026-11-18

- [x] Forms response archive validation: malformed or partially malformed response archives are copied to a recovery key; save, export and response viewing are blocked rather than silently dropping records. Build #331 / run `44308240635` completed successfully on commit `8c242979bcbd69fb0980e6cda2f01987ff0ae2a6`; Analyze, full tests, Android release APK and artifact upload passed. Artifact `OFFYNEXBD-Android-APK`, ID `14430310243`, size 51,198,289 bytes; expires 2026-11-25T13:00:25Z.
- [x] Writer library safety: malformed archive data now sets a write-block state; creating, importing, renaming, deleting and exporting are guarded so a recovery-only empty view cannot overwrite the original library. The shared store helper also refuses writes while blocked. Regression coverage verifies the original raw archive remains unchanged.
- [x] Sheets recovery safety: malformed workbook data is preserved as a recovery copy; the primary workbook is no longer replaced with a blank workbook, and editing is blocked until recovery. Regression test verifies the original raw workbook remains unchanged.
- [x] Workspace mutation safety: Slides, Fonts, AI Assistant, Cloud, Forms and Database record create/edit/import/delete operations now persist a candidate collection before changing in-memory state; failed persistence cannot leave a misleading changed UI state.
- [x] Sheets CSV import: rejects empty or larger-than-20-MB files, waits for pending saves, creates a full-workbook backup before replacement, and reports save failures rather than claiming success.
- [ ] Latest combined source validation: Build #334 / run `44310287107`, commit `43e63414b3d69758bef3b9e4c6dae34f3c5df2dd`. Flutter Analyze and the complete automated test suite passed; Android release APK build was still running at this checkpoint. Do not mark this batch release-verified until APK build, signing cleanup, source save and artifact upload complete.

### Product-level work still open (not to be marked complete)
- Writer: native DOCX import into Quill, ODT import/export, full rich-content pagination and fidelity, spell-check dictionary, font management, device/printer verification.
- Sheets: advanced Excel compatibility, charts, pivot tables, data validation, conditional formatting, ODS import/export, print-preview controls and large-workbook/device testing.
- Slides: full slide editor, PPTX import/export and slideshow rendering; current export is text-based PDF.
- PDF: scanned/malformed/encrypted edge cases, OCR accuracy and source-layout fidelity.
- Fonts: actual installable font library and system font management; current workspace is not a complete font manager.
- AI Assistant: secure backend/API integration; do not expose secrets in the client or simulate a live AI service.
- Cloud: production online authentication, sync and conflict resolution; current backup/restore is local only.
- Forms: online publishing, share links, remote response collection and access controls; current forms are local.
- Scan: physical Android camera, edge detection, OCR and PDF sharing verification; other-platform scanner parity.
- Database: advanced schema/query/relationship functionality and device-level performance/security validation.
- Cross-platform: iPhone, Windows and macOS build/interaction testing. Android CI does not verify these platforms.
- Physical printer and real-device validation remain outstanding across relevant modules.


## Integrated project-wide continuation — Build #341 verified and shared workspace corrections (2026-11-18)

- [x] Verified Build #341 / run `44314759299` against exact source commit `9c22acf9124eb6598d16449f83268531579ce99b`: Flutter Analyze, complete automated test suite, Android release APK, signing cleanup, generated-source save and artifact upload all succeeded. Artifact `OFFYNEXBD-Android-APK`, ID `14432326906`, size 51,198,591 bytes; expires 2026-11-25.
- [x] Re-audited the shared workspace paths used by Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database, plus the central local backup/restore flow.
- [x] Fixed a backup completeness defect: the workspace screen previously filtered preference values before calling the strict backup codec, which could silently omit an unsupported OFFYNEXBD preference. It now passes every OFFYNEXBD key to the codec, allowing the codec to reject unsupported values instead of exporting an incomplete backup.
- [x] Enabled module-scoped record export/import for Cloud and Scan as well as the previously supported record modules. Unknown module names remain rejected.
- [x] Added regression coverage that round-trips portable records for every record-based workspace module and retains rejection of unknown modules.
- [ ] Validate this follow-up batch with Flutter Analyze, the complete test suite, Android release APK build and artifact upload before marking it CI-verified.
- [ ] Product gaps remain open across Writer (native DOCX import, ODT, advanced pagination/fidelity, spell-check and font management), Sheets (charts, pivots, validation, conditional formatting, ODS and advanced Excel compatibility), Slides (real slide editor, PPTX import/export and slideshow), PDF (layout fidelity and difficult/encrypted/scanned files), Fonts (installable font management), AI (secure live backend), Cloud (online sync/auth/conflict resolution), Forms (online publishing and remote collection), Scan (real-device and cross-platform validation), and Database (advanced schema/query/relationships).
- [ ] Physical Android device, iPhone, Windows, macOS and printer validation remain separate from CI and have not been claimed complete.


## Coordinated cross-module resource and import/export hardening — source batch committed (2026-11-18)

- [x] Sheets workbook JSON: 20 MB import/export ceiling; existing legacy workbook migration remains intact.
- [x] Sheets formulas: 4,096-character and 2,048-token ceilings to reject pathological input.
- [x] PDF conversion: 50 MB source-file ceiling and 1,000-page ceiling.
- [x] Slides PDF export: 200-slide and 5 MB combined text ceilings.
- [x] Shared module record interchange: 10 MB import/export ceiling.
- [x] Writer document archive: 25 MB import/export ceiling.
- [x] Regression tests added for these boundaries; final test syntax correction included before final verification.
- [ ] GitHub Actions full Analyze, test suite, Android APK build and artifact upload remain pending for the final integrated source commit.
- [ ] These protections are not a claim of office-suite feature completion. PPTX/DOCX/ODT/ODS parity, chart/pivot features, full slide editor, production Cloud sync, live AI backend, online Forms, full font manager, advanced Database and physical/cross-platform checks remain outstanding.


## Build #345 analyzer correction — 2026-11-18

- [x] Build #345 reached Flutter Analyze; the only reported issue was an unnecessary string-interpolation brace in Slides PDF text-size calculation.
- [x] Removed the redundant brace without changing export behavior.
- [ ] Re-run Analyze, complete tests, Android release APK build and artifact upload on the corrected integrated commit.


## Build #346 test declaration correction — 2026-11-18

- [x] Build #346 / run `44318916415` on commit `3219c1913de92a137694e73559e875a8181bef99`: Flutter Analyze passed; test stage reported 106 passed and 3 failed; APK build/upload were skipped.
- [x] Root cause isolated to three newly extended test files: size-limit test declarations were accidentally nested inside preceding tests due to missing closing braces in Writer document codec, workspace record codec and Slides PDF export tests.
- [x] Corrected test declaration boundaries only; all assertions and cases are retained.
- [ ] Re-run Analyze, complete tests, Android APK build and artifact upload on this correction commit.


## Build #347 syntax correction — 2026-11-18

- [x] Build #347 / run `44319688458` on commit `cf0721a9f151c26d6302b605d2dd986b138890ae` failed at Flutter Analyze before tests could run.
- [x] Exact issue: the final size-limit test in each of `test/slides_pdf_export_test.dart`, `test/workspace_record_codec_test.dart` and `test/writer_document_codec_test.dart` was missing its closing `});`.
- [x] Restored the three test-block closures; no test or assertion was removed.
- [ ] Re-run Flutter Analyze, full automated tests, Android release APK build and artifact upload on the corrected commit.
- [ ] Do not mark the resource-hardening batch verified until all CI stages pass.


## Forms response dashboard search and filter — 2026-11-18 (CI pending)

- [x] Build #350 / run `44322462331` verified on exact commit `c2f4ded0b82b2b24a1a8cd6504b8afe2a52a96ed`: Flutter Analyze, full automated tests, Android APK build, signing cleanup, generated-source save and APK upload all passed.
- [x] Forms CSV export is present in that verified source; Bengali UTF-8 BOM, quoting/escaping and multi-form question separation are covered by tests. Existing JSON export is retained.
- [x] Added response-dashboard search across form title, question, answer and submission timestamp. The dashboard shows total response/form counts and a matching-result count without changing stored response data.
- [x] Added pure filtering regression tests for Bangla form titles, question labels, answers, date search, empty matches and blank search.
- [ ] Validate this dashboard batch with Flutter Analyze, all automated tests, Android release APK build and artifact upload on its final commit.
- [ ] Online Forms publishing, share links, remote response collection and access controls remain product-level work; local response search does not imply online Forms support.


## Database CSV interchange — integrated feature batch (2026-11-18)

- [x] Added schema-aware CSV export for offline Database table rows, including Bengali UTF-8 BOM and correct quoting for commas, double quotes and multiline cells.
- [x] Added CSV import that checks exact column order, rejects malformed quotes/row widths and appends rows without replacing existing data.
- [x] Import/export enforce a 10 MB file limit and a 100,000-row ceiling; the existing database JSON store and recovery path remain unchanged.
- [x] Added regression tests for Bengali round-trip, quoted/multiline cells, schema mismatch, malformed CSV and invalid rows.
- [ ] Flutter Analyze, complete automated tests, Android APK build and artifact upload must pass on this integrated commit before this batch is marked CI-verified.


## Scan workspace structural repair — Build #357 failure corrected (2026-11-18)

- [x] Build #357 / run `44332125755` on commit `d627f41bae991e4831db6c08370b451a28459911` failed at Flutter Analyze. The Scan UI patch had accidentally duplicated approximately 1,149 lines of the workspace screen, causing duplicate classes and cascading analyzer errors.
- [x] Restored the workspace screen from the last successful source baseline `46ccbad5303609dd1102e3c7d567d4e741d47b0c` and reapplied the Scan library changes as focused edits, preserving the previous Forms, Database and workspace features.
- [x] Scan PDFs are stored in the Scan workspace list even if OCR returns no text; share/delete actions operate on the saved PDF path; recognized text is also stored as an editable Writer document.
- [ ] Build #358 / run `44333893480` on commit `14bc74a78b2b2e986d493da986b11f03a6e873bc` must pass Flutter Analyze, all tests, Android APK build and artifact upload before this repair is CI-verified.
- [ ] Android physical camera/scanner behavior, PDF persistence after app restart, sharing, deletion and OCR remain unverified on a real device.


## Correction to Scan status after Build #358 (2026-11-18)

- [x] Build #358 / run `44333893480` also failed at Flutter Analyze. The duplicate workspace tail remained in the resulting file because the attempted replacement was not a safe, bounded edit.
- [x] Reverted the entire workspace screen to the exact last successful Build #355 version (`46ccbad5303609dd1102e3c7d567d4e741d47b0c`) in commit `cf0bb22b5b273eafa62c31d5b595dbaaa57d15f9`. This removes the faulty duplicate code and restores the previously verified Forms, Database, and other workspace functionality.
- [ ] Scan PDF library listing/share/delete enhancement is NOT present in the restored source and remains incomplete. Do not describe it as implemented until a clean focused patch passes CI.
- [ ] Build #359 / run `44334365915` validates the restored source; Analyze, full tests, APK build and upload are pending.


## Scan workspace focused repair — Build #363 verified (2026-11-18)

- [x] Final main commit: `efae8609c10912c485319bba4f4b61fd01105f6c`.
- [x] Build #363 / run `44336065714` completed with overall conclusion `success`.
- [x] Flutter Analyze passed; full automated tests passed; Android release APK build passed; signing-file cleanup passed; generated source save passed; Android APK artifact upload passed.
- [x] Static source verification on the exact main commit confirms Scan list visibility, saved PDF path persistence, PDF share handler, PDF delete handler and Scan list actions are present.
- [x] APK artifact: `OFFYNEXBD-Android-APK`, artifact ID `14441588470`, 51,264,578 bytes, SHA-256 `658772d794e635a57588d0aa727e518fc75b6e455dc0e3b5383f1e4b989fb1ea`, expires 2026-11-25 15:35:58 UTC.
- [ ] Real Android device checks are still required for camera permission, auto edge detection, multi-page capture, OCR accuracy, saved PDF persistence after app restart, share and delete behavior. CI success does not prove physical-device behavior.
- [ ] This verifies the Scan workspace repair only; it does not mean all OFFYNEXBD modules or all previously listed product gaps are complete.


## Integrated Sheets Find & Replace — source batch (2026-11-18)

- [x] Added literal Find & Replace across every worksheet, with optional case-sensitive matching and empty replacement support.
- [x] The operation preserves cell formatting and worksheet metadata, treats regex symbols and replacement dollar signs literally, and reports the number of replacements.
- [x] Added a Home ribbon command and Bangla/English dialog labels.
- [x] Added regression tests for multi-worksheet replacement, case sensitivity, formatting preservation, regex-safe literal matching and empty search rejection.
- [ ] Flutter Analyze, complete automated tests, Android release APK build and artifact upload are pending for this source commit.
- [ ] This batch does not close the remaining Sheets gaps: charts, pivot tables, data validation, conditional formatting, ODS, advanced Excel compatibility, freeze panes and large-workbook/device testing.


## Sheets Find & Replace formula safety — integrated correction (2026-11-18)

- [x] Find & Replace now excludes formula cells by default, preventing accidental formula corruption during ordinary text replacement.
- [x] Added an explicit “Include formulas” option for users who intentionally need formula text changed.
- [x] Added regression coverage for default formula protection and opt-in formula replacement across worksheet cells.
- [ ] Flutter Analyze, full tests, Android APK build and upload must pass on this correction commit before CI verification.


## Sheets Freeze Top Row — implementation batch (2026-11-18)

- [x] Added a View-ribbon Freeze Top Row / Unfreeze Top Row toggle for the active worksheet.
- [x] The first currently visible row remains pinned below the column headers while the remaining rows scroll; horizontal scrolling remains shared.
- [x] Freeze state is saved per worksheet and round-trips through the existing workbook format without changing its version; old and legacy workbooks default to unfrozen.
- [x] Added codec validation and regression tests for persistence, legacy defaults, invalid metadata and the ribbon toggle.
- [ ] Flutter Analyze, full automated tests, Android APK build and artifact upload are pending on this source batch.
- [ ] Physical-device scrolling and imported/exported XLSX freeze-pane compatibility remain to be validated; this feature currently applies to the OFFYNEXBD Sheets workspace view.


## Sheets formula and freeze-pane reliability batch (2026-11-18)

- [x] Added Excel-style numeric comparison operators: =, <>, >, <, >= and <=, with chained comparisons rejected safely.
- [x] Added numeric IF, AND, OR and NOT functions to the formula engine and formula ribbon picker; formula values remain numeric in this version.
- [x] Added regression coverage for comparisons, nested arithmetic, logical combinations and invalid argument/comparison syntax.
- [x] Corrected Freeze Top Row to pin physical worksheet row 1, rather than the first row after sorting/filtering; filtered/sorted row order remains view-only.
- [ ] Flutter Analyze, full tests, Android APK build and upload pending on this combined batch.
- [ ] Remaining Sheets work still includes charts, pivot tables, data validation, conditional formatting, ODS, advanced Excel fidelity and performance/device testing.


## Sheets data validation — integrated dropdown batch (2026-11-18)

- [x] Added per-cell dropdown list rules, persisted independently for every worksheet.
- [x] Added Data-tab rule editor and a formula-bar dropdown picker for the selected cell.
- [x] Manual cell edits and formula-bar commits now reject values outside the configured list; blank values remain allowed.
- [x] Clear-sheet and CSV replacement remove obsolete validation rules; row/column shrink is blocked if it would discard a rule.
- [x] Added bounded option parsing, duplicate/length checks, codec validation, persistence and widget regression tests.
- [ ] XLSX native data-validation import/export, CI Analyze/tests/APK and physical-device verification remain pending.


## Sheets interactive cell-write integrity — integrated correction (2026-11-18)

- [x] Cell editor, formula bar, dropdown selection and formula picker now share one guarded interactive write path.
- [x] Formula picker functions, including the direct PI() shortcut, cannot bypass an existing exact-value Dropdown Validation rule.
- [x] Rejected writes leave the stored cell value unchanged and display the same Bangla/English validation message; blank values remain allowed.
- [x] Added regression assertions for formula strings against dropdown options.
- [ ] Flutter Analyze, complete automated tests, Android APK build and artifact upload are pending for this integrated correction.
- [ ] Native XLSX data-validation import/export remains unsupported by the current mapping; not claimed complete.
- [ ] Charts, pivot tables, conditional formatting, named ranges, ODS import/export, advanced print setup, freeze columns/panes, large-workbook performance and physical-device validation remain open.


## Sheets XLSX dropdown-validation interoperability — integrated batch (2026-11-18)

- [x] XLSX import reads native fixed-list dropdown validations and expands each supported range into the worksheet's per-cell validation model.
- [x] Worksheet dimensions grow to include imported validation ranges, even when the validated cells contain no values.
- [x] XLSX export writes per-cell dropdown rules back as native Excel data-validation ranges, coalescing adjacent cells with identical options.
- [x] Multi-area ranges and absolute cell references are handled; unsupported non-list and formula/range-backed validations are rejected rather than silently discarded.
- [x] Import/export enforces the existing 1,000-row × 100-column grid and a 10,000-cell validation expansion ceiling.
- [x] Export/import explicitly rejects fixed-list options Excel cannot represent faithfully (commas, quotes, line breaks, or more than 255 joined characters).
- [x] Added regression coverage for multi-cell/multi-area import, unsupported rules, grid/expansion limits, grouped export and XLSX save/reopen round-trip.
- [ ] Flutter Analyze, full automated tests, Android release APK build and artifact upload must pass on the integrated commit before CI verification.
- [ ] Formula/range-backed dropdowns and non-list Excel validation types remain unsupported; they are rejected with an explicit import error, not silently dropped.


## Writer mobile page viewport and touch zoom — implementation batch (2026-11-18)

- [x] Added a shared, testable viewport scale calculator for Full Page, Page Width and Actual (100%) modes; layout recalculates when device/window dimensions change.
- [x] Added a mobile-visible zoom strip with zoom-out, zoom-in, slider, percentage, Full Page, Page Width and 100% controls.
- [x] Added two-finger pinch zoom and pan to the Writer page canvas using InteractiveViewer; pinch scale is committed to the per-document saved zoom setting while preserving pan translation.
- [x] Expanded the saved zoom range to 50%–300%; existing legacy zoom values remain readable and are safely clamped.
- [x] Kept the existing Quill Delta, table/image embeds, autosave, PDF generation and print-preview callbacks in place.
- [x] Added five viewport unit tests for phone Full Page fit, Page Width, 100% scale, zoom limits and invalid page dimensions.
- [ ] Flutter Analyze, complete automated test suite, Android release APK build and artifact upload must pass on the integrated commit before merge.
- [ ] This viewport change does not yet provide true rich-content pagination: the existing continuous Quill editor and estimated page backgrounds remain a limitation for exact page breaks around tables/images.
- [ ] DOCX import, ODT import/export, full-fidelity portable image packaging, advanced pagination, spellcheck and installable font management remain open Writer tasks.
- [ ] Physical Android pinch/scroll, small-screen and accessibility checks remain pending.


## Writer document format interchange — integrated implementation batch (2026-11-18)

- [x] Added bounded DOCX and ODT import (25 MB source, 60 MB expanded archive, 2,000 archive entries, 15 MB per image).
- [x] DOCX import maps paragraphs, common text formatting, headings, alignment, lists, editable Writer tables and embedded images into the existing Quill Delta/table/image model.
- [x] ODT import maps paragraphs, headings, common span styles, lists, editable tables and embedded images into the existing document model.
- [x] ODT export writes an OpenDocument ZIP package with text styles, headings, lists, editable tables, packaged images, page size/orientation/margins and header/footer content.
- [x] Added File ribbon commands for DOCX/ODT import and ODT export; imports create a new library document and leave the open source document unchanged.
- [x] Added three regression tests for DOCX formatting import, ODT text/style/table round-trip and unsupported/oversized file rejection.
- [ ] Flutter Analyze, complete tests, Android release APK and real-device checks are pending; do not claim full format fidelity before validation.
- [ ] Advanced automatic pagination, spellcheck and installable user-font management remain open Writer tasks.


## Writer interchange CI readiness — 2026-11-18

- [x] Enabled GitHub Actions pull-request validation for source, tests, dependencies and asset changes; the existing main-branch and manual triggers remain enabled.
- [x] ODT package now includes its document title metadata and lists the metadata file in the package manifest.
- [ ] Pull-request Analyze, full test suite and Android APK build have not yet reported a result; merge remains blocked until the run passes.


## Writer CI dependency-resolution correction — 2026-11-18

- Build #378 (run ID 44362647172) reached dependency resolution and failed before Analyze because pdf ^3.13.1 requires xml ^7.0.1 while Writer initially pinned xml ^6.5.0.
- [x] Updated the direct XML dependency to ^7.0.1 to satisfy the existing PDF package constraint.
- [ ] Re-run dependency resolution, Analyze, full tests and Android APK build on the corrected branch.


## Writer format-import integration correction — 2026-11-18

- Build #381 reached Flutter Analyze but failed because the first DOCX/ODT import/export method insertion was truncated at a raw filename regular expression, producing cascading Dart parser errors.
- [x] Replaced the entire import/export method region with complete, bounded methods; removed the fragile extension regular expression and used the selected file's extension/name fields.
- [ ] Re-run Analyze, all tests and Android APK build; no feature is considered verified until the full run passes.


## Writer source restoration and DOCX/ODT integration — 2026-11-18

- [x] Restored the complete Writer screen from the last intact mobile-viewport commit, preserving its ribbon, references, review, print preview, table/image editor, autosave and page controls.
- [x] Reinserted DOCX/ODT import and ODT export as complete class methods at the correct scope; imports create a separate document and preserve the current one.
- [x] Re-added File ribbon commands and Bangla/English labels.
- [ ] Analyze, tests and Android APK build must pass before the Writer format changes are merged.


## Writer ZIP encoder API compatibility — 2026-11-18

- [x] Archive 4.x renamed ZIP encoding from `encode` to `encodeBytes`; corrected the ODT exporter and its DOCX fixture test to use the current API.
- [ ] Re-run Analyze and tests to catch any further API mismatches before building the Android APK.


## Writer ODT package ordering and import metadata — 2026-11-18

- [x] Corrected ODT package assembly so the uncompressed `mimetype` entry is the first ZIP member, as required by the OpenDocument package format; image files are now queued and appended after it.
- [x] Corrected PlatformFile size checking to use the repository-supported lengthSync()/length() methods.
- [x] Replaced all unresolved UI interpolation placeholders with explicit Dart string/path operations.
- [x] Added a regression assertion that ODT `mimetype` is the first archive entry.
- [ ] Analyze, tests and Android APK build remain pending for the corrected commit.


## Writer Analyze cleanup — 2026-11-18

- Build #385 installed dependencies successfully, then Analyze identified a nullable PlatformFile length, an async BuildContext lint, string-composition lints and a deprecated Matrix4.translate call.
- [x] Added a zero fallback for nullable file length, separated the mounted guard, converted string composition to interpolation and replaced deprecated matrix translation with translateByDouble.
- [x] Removed the remaining unnecessary interpolation braces in ODT image names.
- [ ] Re-run Analyze, full tests and Android APK build on the corrected commit.


## Writer viewport Matrix4 API correction — 2026-11-18

- Build #386 reduced Analyze findings to one Matrix4 API signature mismatch: translateByDouble requires x, y, z and w.
- [x] Added the homogeneous w=1 argument; no other Analyze errors or lints were reported in Build #386.
- [ ] Re-run Analyze, tests and Android APK build.


## Writer final Analyze lint correction — 2026-11-18

- Build #387 narrowed Analyze findings to two informational lints: a missing mounted guard after the asynchronous file-size read, and unnecessary interpolation braces in the ODT filename.
- [x] Added the post-await mounted guard and simplified the filename interpolation.
- [ ] Re-run Analyze, tests and Android APK build.


## Writer document import title test correction — 2026-11-18

- Build #388: Flutter Analyze SUCCESS; 150 tests passed and one DOCX import test failed because the service retained the source extension in the imported title.
- [x] DOCX/ODT import title normalization now removes only the supported .docx/.odt suffix and preserves other periods in the document title.
- [ ] Re-run all tests and Android APK build.


## Writer CI artifact publication repair — 2026-11-18

- Build #389: Flutter Analyze SUCCESS; all 151 tests SUCCESS; Android Release APK compiled successfully (108.0 MB).
- The workflow then failed in "Save Generated Source" because GitHub Actions checked out a detached HEAD and the step used a bare `git push`; this caused the APK upload step to be skipped.
- [x] Updated the source-save step to push explicitly to the triggering branch (`HEAD:${GITHUB_REF_NAME}`) and skip source pushes on pull-request runs.
- [ ] Re-run workflow to verify artifact upload and final job success.
- [ ] Physical Android device validation and complete Writer parity checks remain open.


## Writer Interchange Fidelity Batch — 2026-11-19

- Added safe external hyperlink preservation to DOCX import by resolving external relationship targets and mapping supported HTTP, HTTPS and mailto links into Quill link attributes.
- Added ODT hyperlink import/export through standard text hyperlink elements.
- Link targets are restricted to safe supported schemes; unsupported, malformed, oversized and non-web schemes are discarded rather than made clickable.
- Added DOCX and ODT hyperlink regression coverage alongside the existing paragraph, formatting, table and package checks.
- This batch does not claim complete DOCX/ODT fidelity: headers/footers and section/page setup import, numbering fidelity, merged tables, floating images, advanced styles, comments/track changes and real-world round-trip compatibility remain open.
- Build #390 (run ID 44367606027; commit 08ec234f733c4e537859233f6b72319dfb05d3c8) verified Analyze, 151 automated tests, Android Release APK build and APK artifact upload successfully. Artifact ID 14457907066; expires 2026-11-25. Physical Android gesture, editing and printer testing remain pending.


### Writer hyperlink batch CI correction — 2026-11-19
- CI run #394 identified two Dart analyzer style diagnostics in the new DOCX/ODT hyperlink map literals. Replaced nullable checks with null-check patterns; no functional behavior change.
- Hyperlink import/export test coverage remains in the same Writer interchange batch. CI must be rerun and pass before considering this batch verified.


### Writer ODT inline-format fidelity — 2026-11-19
- ODT style import/export now covers strike-through, foreground/background colors, font size (pt/px normalization), and serif/sans-serif font family in addition to bold, italic and underline.
- ODT export generates named inline styles from validated Quill attributes instead of dropping those formats.
- Added ODT round-trip assertions for all newly supported inline attributes.
- This remains a standards-interoperability implementation, not a claim of pixel-perfect fidelity across every office suite. Page layout/header/footer import, advanced numbering, complex table merges and floating objects remain to be verified/implemented.


### Writer CI lint follow-up — 2026-11-19
- Applied the null-check pattern consistently to both DOCX and ODT hyperlink attribute maps after CI surfaced the second instance.
- The ODT inline-style enhancement is queued for full analyzer, regression-test and Android build validation.


### Writer page setup and header/footer import — 2026-11-19
- DOCX section properties now import common paper sizes/orientation and page margins from Word twips.
- DOCX default header/footer parts are resolved through package relationships and their text is imported.
- ODT page dimensions/orientation/margins and master-page header/footer text are read from styles.xml.
- Imported page layout and header/footer are now applied to the new Writer document instead of silently resetting to A4 defaults/empty header-footer.
- Added round-trip/import assertions for DOCX and ODT page setup and header/footer.
- Limitations remain for section-specific layouts, multiple headers/footers, first/even page variants, complex fields/page-number fields, and exact pagination.


---

## New Chat Handoff — Verified checkpoint 2026-11-19

### Mandatory continuation rules
- Continue the existing OFFYNEXBD project; do not restart, scaffold a duplicate app, or ask the user to repeat prior requirements.
- User wants related tasks handled in coherent batches, not one tiny task per turn. Avoid repetitive progress dialogue; perform repository inspection, implementation, tests, and CI verification before reporting.
- Use simple Bangla for user-facing communication. Do not ask the user to upload files/images or write code.
- Do not claim a feature is complete merely because a screen, menu, or source file exists. Completion requires implementation plus appropriate tests and validation.
- Do not claim physical Android/printer validation based on CI.
- Keep OFFYNEXBD separate from Digital 24 Online and INAB BD.
- Writer is the active priority; do not move to another module until Writer's software work is complete and remaining device-only checks are explicitly identified.

### Repository and active work
- Repository: https://github.com/Digital24Online/OFFYNEXBD
- Active branch: `work/writer-mobile-page-viewport`
- Active PR: https://github.com/Digital24Online/OFFYNEXBD/pull/3
- Branch head at checkpoint: `160351fd365c18a94688b365cd621c8f000ee6bb`
- Main branch remains separate; do not assume the active PR is merged.

### Latest verified Android CI
- Workflow run #400, run ID `44381024091`.
- Commit: `160351fd365c18a94688b365cd621c8f000ee6bb`.
- Flutter Analyze: SUCCESS.
- Automated tests: SUCCESS.
- Android Release APK build: SUCCESS.
- APK artifact upload: SUCCESS.
- Artifact: `OFFYNEXBD-Android-APK`, artifact ID `14464681374`, size 51,491,506 bytes; expires 2026-11-25.
- Run: https://github.com/Digital24Online/OFFYNEXBD/actions/runs/44381024091
- APK artifact success does not establish real-device gesture, printer, or full office-suite compatibility.

### Latest Writer implementation checkpoint
- Mobile page viewport controls include Fit Page, Fit Width, 100% and pinch-zoom handling.
- DOCX/ODT import reads common page size, orientation, margins and default header/footer text.
- ODT import/export supports bold, italic, underline, strike-through, foreground/background color, font size, font family and hyperlinks.
- DOCX/ODT hyperlink import/export supports safe HTTP, HTTPS and mailto targets.
- Regression tests cover the supported import/export metadata and formatting.
- CI run #400 verifies Analyze, tests, APK build and upload for this checkpoint.

### Writer remaining work — do not mark complete yet
1. True document pagination and accurate page-break behavior.
2. Advanced DOCX/ODT fidelity: complex tables, merged cells, floating images, numbering/lists, paragraph styles and multiple sections.
3. Section-specific, first/even-page headers and footers; fields and page-number fields.
4. Confirm and extend DOCX export of page layout, headers and footers.
5. Spellcheck, including Bangla.
6. Font management/import and Bangla shaping/ligature tests.
7. Large-document performance, crash recovery and robust backup/restore with portable embedded images.
8. Complete Bangla/English UI localization and responsive mobile ribbon audit.
9. Expand widget tests for zoom, pinch, scrolling, editing and page display.
10. Android physical-device testing and printer/Print Preview integration checks.

### Other modules — incomplete
- Sheets: formula/grid foundation, lazy rendering, cell editing/persistence, find/replace, freeze top row and dropdown validation work exist. Still needs charts, pivot tables, conditional formatting, broader Excel fidelity, ODS, advanced print setup, large-workbook and device tests.
- Slides, PDF, Fonts, AI, Cloud, Forms, Scan and Database are only initial/partial implementations; none should be represented as complete office-grade modules.
- Production authentication/backend, online sync, shared cloud services, security architecture and cross-platform release validation remain open.

### Next batch to execute
1. Inspect Writer DOCX export service and ensure page layout/header/footer export is present and tested.
2. Audit portable image packaging in Writer backup/restore and document import/export.
3. Fix font-family classification so sans-serif is not misclassified as serif.
4. Complete Bangla/English localization audit for Writer ribbons and controls.
5. Add/extend automated tests for the above as one coherent batch.
6. Update this progress file, run Analyze + full tests + Android Release build + artifact upload, and only then report verified status.
7. Keep device-only checks clearly separated from CI-verified work.

### New-chat continuation prompt
“OFFYNEXBD MASTER PROJECT চালু করো। GitHub-এর OFFYNEXBD_MASTER_PROGRESS.md-এর সর্বশেষ ‘New Chat Handoff’ এবং active PR #3/branch-এর বর্তমান অবস্থা পড়ে ঠিক সেখান থেকে কাজ চালাও। আগের কোনো কাজ পুনরায় শুরু বা আমাকে আবার নির্দেশনা দিতে বলবে না। Writer-এর বাকি কাজগুলো একসঙ্গে অডিট, বাস্তবায়ন, পরীক্ষা ও CI যাচাই করো। সহজ বাংলায় কথা বলবে; কাজ যাচাই না করে সম্পন্ন বলবে না।”


---

## Writer Reliability Batch — DOCX export, portable backup, fonts and localization (2026-11-19)

- [x] DOCX export now receives the current page size, orientation, four margins, and header/footer text from the active Writer document.
- [x] DOCX package writer adds Word section page dimensions/margins and separate header/footer parts with relationships and content-type declarations.
- [x] Added archive-level regression coverage for A5 landscape dimensions, margins, and exported header/footer parts.
- [x] Fixed DOCX/ODT font family detection: sans-serif is checked before generic serif matching, preventing the substring collision in `sans-serif`.
- [x] Added DOCX and ODT regression tests for sans-serif and serif classification.
- [x] Added a portable `.offynex` Writer backup format that packages referenced images with the document library and restores image files to the destination app storage.
- [x] Writer backup import retains legacy JSON import compatibility; new backup export uses the portable archive format.
- [x] Localized the Writer View ribbon controls for Bangla and English.
- [x] Corrected relationship ID allocation in DOCX package post-processing to avoid collisions with existing image relationships.
- [x] Added a 60 MB expanded-archive safety bound for portable Writer backup import/export, restricted image packaging to the app's Writer image directory, and aligned the screen import limit with the 25 MB archive limit.
- [x] DOCX section replacement now handles both existing paired and self-closing section-property XML forms.
- [ ] Run Flutter Analyze, complete automated tests, Android Release APK build and artifact upload on this batch.
- [ ] Real Microsoft Word / LibreOffice opening and print output must still be checked; CI archive tests do not replace external office application testing.
- [ ] Remaining Writer gaps: true live pagination, complex DOCX/ODT fidelity, spellcheck, full font management, comprehensive ribbon localization, large-document performance and Android physical-device/printing validation.

- CI trigger note (2026-11-19): source commit `e5e5f33f4691fbe3a326579f47ae61dc07567ac6` is the current Writer implementation checkpoint; run Analyze, all tests, Android release build and artifact upload against the latest PR head before considering this batch verified.

- Latest source branch head at 2026-11-19 checkpoint: `53f9cca97fbb4c7580a4275163fae8229248beab` (Writer backup path guard and CI-trigger marker).
- Current PR #3 still points to this branch. Build #401 (`44383179935`) analyzed and tested commit `3a92f365db04f4e1cc31c177ad1f2fc6dcd283f4`, which predates the Writer reliability batch; Android APK build is still in progress. No CI result is yet available for the current source head, so do not mark this batch verified.


## Integrated Portable Backup — All Modules, Writer Assets and Scan PDFs (2026-11-19)

- [x] Replaced Cloud workspace's primary backup export with a portable `.offynex` ZIP archive containing all supported `offynex_*` preferences used by Writer, Sheets and the other module workspaces.
- [x] Writer embedded image files are packaged from the app-managed `offynexbd_images` directory and their paths are rewritten in the backup manifest.
- [x] Scan PDF files are packaged from the app-managed `OFFYNEXBD/Scans` directory; Scan workspace records and Writer references are rewritten and restored to new device-local paths.
- [x] Legacy JSON backup import and manual JSON copy/paste restore remain supported.
- [x] Import validates the app-specific manifest, archive size/file count/expanded size, asset paths and managed storage roots; extraction is rolled back if restore preparation fails.
- [x] Added regression tests for Writer image + Scan PDF cross-device restoration, unrelated local-path rejection and invalid archive rejection.
- [ ] Current source branch CI Analyze/tests/Android APK/artifact verification is pending.
- [ ] This is portable offline backup/restore, not online Cloud Sync. Authentication, remote storage, encryption-at-rest, sharing and conflict resolution remain incomplete.

- CI correction note: Build #402 (run ID 44383735233, source commit `c411f9b8aa226fd105558cde4da28488a222bcb7`) failed at Analyze because of two DOCX string-style infos, one missing mounted guard after an async Writer import, and one unused test import. These findings are being corrected in the integrated batch; no APK was produced by that run.

- Build #405 (run ID 44385365644, source commit `5cedf1b9f27504410c3ba675fb28228d005a0169`) — Analyze SUCCESS; tests 157 passed / 1 failed. The failing regression exposed that the ODT font-family branch still used the old substring check even though the DOCX helper was fixed. Correcting ODT to use the shared sans-first classifier; APK build was skipped because tests failed.
- Portable backup export/import size accounting now applies the same 100 MB expanded limit including the manifest, and asset extensions are constrained to their matching folder type.

---

## Writer integrated audit follow-up — 2026-11-19

- [x] Audited the current Writer mobile viewport implementation: Full Page, Page Width, Actual 100%, slider zoom and pinch/pan controls are present. The page background count is still estimated from plain-text height; this is not true rich-content pagination and remains open.
- [x] Audited DOCX export page setup/header/footer generation and the archive-level regression test for page size, margins, and header/footer parts.
- [x] Audited portable Writer image backup/restore: app-managed image-root checks, missing-image rejection, archive limits, embedded image packaging and restore-to-new-path test are present.
- [x] Corrected DOCX nested-list import to store Quill indent as a numeric level and aligned its regression assertion.
- [x] Corrected the DOCX nested-list export fixture to use actual newline characters rather than literal backslash-n text, so the test exercises separate list paragraphs.
- [ ] Run Flutter Analyze, full tests, Android release build and artifact upload against the latest branch head; no fresh CI verification is claimed for these latest commits yet.
- [ ] True rich-content pagination, complex DOCX/ODT fidelity, section-specific/first/even headers and fields, Bangla spellcheck, full font management/shaping, comprehensive localization, large-document stress/recovery and physical Android/printer validation remain open.

---

## Branding and App Info work — 2026-11-19

- [x] Confirmed the user's selected logo is Option 2 (Productivity), featuring the document, four productivity tiles and white orbit/swoosh with the tagline “Work Smart, Be Productive”.
- [x] Replaced the previous generic placeholder SVG with an Option 2-inspired OFFYNEXBD brand mark used by the Home app bar and App Info.
- [x] Added an App Info entry point on the Home app bar; creator attribution is inside App Info, not a separate About menu.
- [x] Added the creator attribution content: MD PIYARUL ISLAM; Founder & Original Creator; Rajshahi, Bangladesh; creator statement; “Work Smart, Be Productive”; © 2026 OFFYNEXBD. All Rights Reserved.
- [x] Embedded the selected founder portrait in the App Info screen source to avoid a missing external asset dependency.
- [x] Added an Android vector launcher icon and updated the Android manifest to use it instead of the old mipmap icon.
- [x] Updated the Android launch background to show OFFYNEXBD branding.
- [x] Added CI generation of the same approved logo into Android, iOS, Windows and macOS launcher icon resources using `flutter_launcher_icons`; CI creates a 1024px PNG from the checked-in SVG before icon generation. Cross-platform builds and rendered icon appearance still require verification.
- [x] Added an App Info widget regression test for creator attribution and founder portrait rendering; CI must pass it before verification is complete.
- [ ] Latest branding changes add a CI step to rasterize the SVG and generate platform launcher icons, then run Analyze, tests and Android APK upload; the latest run is pending verification.
- Note: the in-app creator statement is an attribution record; it is not, by itself, a legal certificate of ownership. GitHub commit history and release records remain outside the app as requested.

- Added `test/app_info_screen_test.dart` to check the creator statement, name, city, copyright and image decode fallback.
- The app icon generation workflow uses the same approved Option 2 SVG as the single source of truth; Android splash uses the matching vector identity.

## Writer portable-image backup security follow-up — 2026-11-19

- Hardened Writer backup export path validation: image files are now resolved through filesystem symbolic links and must resolve inside the app-managed Writer image directory. A symlink pointing outside that directory is rejected.
- Made Writer backup image extraction transactional: if a later referenced image is missing/invalid or extraction otherwise fails, files extracted earlier in that import attempt are deleted on a best-effort basis while the original import error is preserved.
- Added regression tests for symlink escape rejection and cleanup after a partially failed import.
- [ ] Flutter Analyze, full tests, Android Release APK build, signing verification and artifact upload are pending for this security follow-up.
- Build #447 (run ID 44485996198; commit 6238248dd4dcaeced9418e39a51c0f336694d005) passed Analyze and the full test step, but the workflow was **cancelled during Android APK build**. Signature verification and APK upload were skipped; no new installable artifact was produced by #447.
- Writer still remains incomplete: true rich-content pagination, complex DOCX/ODT layout fidelity, advanced section/header/footer fields, Bangla spellcheck, user font management, large-document stress/recovery, full ribbon localization and physical Android/printer validation are not yet verified.


## CI verification and direct APK delivery correction — 2026-11-19

- Build #456 (run ID `44492934813`, PR #3 head `6ad999906aebf50131d641c998f3cd7d9553b210`) completed successfully: Flutter Analyze SUCCESS; all 170 automated tests passed; Android release APK build SUCCESS; APK signing fingerprint and package metadata verification SUCCESS; download package validation and artifact upload SUCCESS.
- Verified package ID: `com.offynexbd.offynexbd`; signing certificate SHA-256 matches the previously installed app certificate; generated APK size is approximately 104 MB.
- The user's Android file manager repeatedly reports “Couldn't extract file. Error unknown” for the 51 MB compressed Actions artifact. The artifact itself uploaded successfully; extraction is a delivery/usability failure, not a Flutter build failure.
- Added a main-branch-only GitHub Release asset publishing step so future validated main builds provide a directly downloadable `app-release.apk` (plus SHA-256 file), avoiding the need to extract the Actions artifact ZIP. This step must pass on the first main-branch release build before a direct APK link is offered.
- The DOCX page layout/header/footer export, sans-serif font classification, portable Writer image backup/restore, and View ribbon localization changes are included in the source verified by Build #456 and its 170 passing tests.
- Still open and not claimed complete: true rich-content pagination; advanced DOCX/ODT fidelity (merged/complex tables, floating images, section-specific headers/footers and fields); Bangla spellcheck; user font management; full ribbon localization; large-document performance/recovery; Android physical-device and printer/Word/LibreOffice visual acceptance.


## Latest chat continuation — Writer larger page and compact ribbon (2026-11-19)

- User reconfirmed the approved Writer design: retain the previously shown compact desktop-style ribbon and make the white document page larger; keep the zoom controls and status bar.
- User explicitly requested that all remaining work be audited, implemented and tested together, not as repeated one-at-a-time tasks.
- User reaffirmed the existing GitHub Actions Artifact ZIP delivery method. Do not switch to GitHub Releases/direct APK publishing. Preserve the installed app update identity and signing certificate.
- Latest completed baseline CI: Build #459, run ID `44507489031`, commit `91497af50dfd88442ea43dc974f23d083eb02b22`; Analyze, tests, Android release APK, signature/package validation and `OFFYNEXBD-Android-APK` artifact upload all succeeded. Artifact ID `14519534438`, expires 2026-12-03.
- New UI batch changes on this branch:
  - Reduced Writer ribbon action tiles from 96x72 to 84x56 and tightened Home ribbon padding/spacing.
  - Changed the secondary Quill toolbar to a single-row display to reduce vertical space used by controls.
  - Increased viewport usable width from viewport minus 24 px to viewport minus 8 px so the document page occupies more of the phone screen.
  - Updated viewport regression expectations for the wider Full Page and Page Width fit.
  - Added Bangla labels for Page Color, page color choices, Page Border, revision capture, custom size and common text formatting tooltips.
- These new changes are committed but are NOT yet verified by CI. Trigger and inspect a fresh PR workflow run against the latest branch head before calling them complete.
- Still open: true rich-content pagination/page breaks; advanced DOCX/ODT fidelity and section-specific headers/footers/fields; Bangla spellcheck; user font import/management and Bangla shaping validation; full dialog/control localization; large-document stress/recovery; expanded widget tests for editing/scroll/pinch; real Android device and physical printer/Word/LibreOffice acceptance.
- Keep the previously selected Option 2 logo, App Info creator attribution and portrait work intact. Do not add GitHub work history or release records inside App Info.


---

## Writer UI localization continuation — 2026-11-19

- [x] Expanded the Writer translation dictionary for page size, orientation, page margins, margin presets, custom margin fields, reset, and common review/document dialog actions.
- [x] Applied language-aware labels to the Layout ribbon and its margin menu; stored page-size/orientation/margin values remain unchanged for document compatibility.
- [x] Localized the custom margins dialog controls and the existing Writer review/document dialogs that use the shared label helper.
- [x] Added a widget regression test covering the Layout ribbon in Bangla and English.
- [ ] CI Analyze, full automated tests, Android Release APK build, signing validation and artifact upload must pass on the final latest branch head. Build #472 succeeded for its earlier Slides-preview commit; it does not verify these later Writer changes.
- [ ] Writer still requires further completion work: true rich-content pagination/page breaks; complex DOCX/ODT fidelity and section-specific headers/footers/fields; Bangla spellcheck; user font import/management and glyph-shaping checks; full localization of remaining validation/error messages; large-document stress/recovery; physical Android/printer and Word/LibreOffice acceptance.
- [ ] Do not call Writer complete until the remaining items above are implemented or explicitly scoped as platform-dependent, tested, and the final CI run is successful.


### Writer localization + View controls follow-up — 2026-11-19

- [x] Extended Bangla/English localization to the Writer library import/export/rename/delete dialogs and common editor fields.
- [x] Added a View ribbon widget test for Full Page, Page Width, zoom control presence and the interactive pinch/pan canvas.
- [x] Fixed the Symbols ribbon chip after converting its label to a runtime localized string.
- [ ] Latest source/test checkpoint: `f324340b7b3d9f1dab053f7bdee5f7187ea7bad4` (includes test commit `bcc24ce00021939af34d2beb65d2aad67abfa95e`). GitHub Actions Build #479 (run ID `44519427002`) is running against the latest source checkpoint; Analyze, full tests, Android release APK, signing verification and artifact upload are not yet confirmed.
- [ ] The new tests do not replace physical-device pinch/scroll acceptance. True rich-content pagination, advanced DOCX/ODT layout fidelity, spellcheck, full font manager, remaining message localization, large-document recovery and external Word/LibreOffice print verification remain open.


## Writer DOCX Title Fidelity Correction — 2026-11-19

- Prevented the DOCX exporter from adding a second visible document title when the first body paragraph already matches the Writer document title.
- Retained the automatic title heading when the body begins with different content, and when the document body is empty.
- Added regression tests for both cases. This is a targeted export-fidelity correction; it does not imply complete DOCX/Word compatibility.
- Verification: pending the next GitHub Actions Analyze, automated test and Android release run.

 
## Writer PDF title fidelity correction — 2026-11-19

- PDF export avoids adding a duplicate title when the first body paragraph already matches the document title.
- The metadata title remains visible when the body starts with different content; blank titles are not emitted as empty headings.
- Added PDF text-extraction regression tests for both cases.
- CI verification is pending; this correction is not complete until Analyze, full tests, Android release build, signature checks and artifact upload succeed.


## Writer PDF paragraph and list fidelity — 2026-11-19

- PDF export now renders Quill bullet and ordered-list markers, keeps ordered numbering within a consecutive list, and applies bounded indentation levels.
- Existing inline text styles and paragraph alignment remain intact; this change is limited to list markers and bounded indentation.
- Added PDF text-extraction regression coverage for bullet and numbered list output, including a nested indentation level.
- This is a focused PDF fidelity improvement; automatic rich-content page flow, full Word/ODT layout parity and physical print validation remain open.
- Verification: awaiting the next GitHub Actions Analyze, full test suite, Android release build, signing/package checks and artifact upload.


## Writer page fields and final localization pass — 2026-11-19

- Added live Microsoft Word PAGE and NUMPAGES fields to DOCX headers/footers when users enter the existing `{page}` and `{pages}` placeholders; surrounding text remains editable.
- Expanded DOCX export regression coverage to verify both fields in both header and footer parts.
- Localized remaining high-visibility Writer feedback and dialog text in Bangla/English: document statistics, margin validation, hyperlink selection/URL validation, image import outcomes, and Print Preview save errors.
- This does not yet implement section-specific/first/even-page headers or Writer's on-screen page-number field rendering. Analyze, full tests and Android release artifact verification are pending.


## Writer page-break persistence correction — 2026-11-19

- Fixed the Writer document codec allow-list so the existing `offynexbd-writer-page-break` Quill embed is accepted and preserved during library validation, portable backup encoding, and restore decoding.
- Added regression tests for a Bangla document containing a page break and for rejecting malformed page-break payloads.
- This fixes persistence/backup compatibility for explicit page breaks only. It does **not** implement automatic rich-content pagination, page-flow layout for images/tables, or section-specific page formatting.
- Build #495 (run ID `44540926439`) completed successfully on the previous checkpoint: Analyze, full configured test suite, Android release APK, signature/package validation, and artifact upload all succeeded.
- The page-break codec correction and its regression tests are new and require a fresh full CI run before verification.

---

## New Chat Handoff — 2026-11-19 (Writer / PR #3)

### Latest conversation decisions
- User reconfirmed that the Writer page should appear larger on the phone while retaining the compact desktop-style ribbon, zoom controls and status bar.
- User requires all remaining Writer tasks to be audited, implemented, tested and CI-verified as one integrated effort; do not return to one-change-at-a-time patching or claim completion from partial work.
- Keep the current GitHub Actions artifact ZIP delivery flow. Do not switch to GitHub Releases/direct APK links.
- Preserve the existing app ID and signing certificate. Do not merge PR #3 without the user's explicit approval.
- User expects work to continue from the latest branch state without asking them to repeat prior decisions.

### PR #3 latest verified checkpoint
- Repository: `Digital24Online/OFFYNEXBD`
- PR: #3, still OPEN and not merged.
- Head branch: `work/writer-mobile-page-viewport`
- Verified head commit before this handoff update: `4de36f6c9b06d943988bbde03c6e10c57b735e52`
- Build #502 / run ID `44545249771` completed SUCCESS on that exact commit.
- Flutter Analyze: SUCCESS — “No issues found”.
- Full automated test suite: **188 tests passed**.
- Android release APK: SUCCESS (built APK 108.7 MB).
- APK signature verified against the existing certificate SHA-256: `7a132720dbf3c991e75f530eb095fafa6ad9ccbbe8449283b005eb9367268677`.
- Package metadata validation and Actions artifact upload: SUCCESS.
- Artifact: `OFFYNEXBD-Android-APK`, ID `14541611392`, 51,809,876 bytes; expires 2026-12-03 14:42:09 UTC.
- Artifact ZIP SHA-256: `40a277750cedf449dda8f76995286ecd77b594bbe3bf9bd792d5a8747c1a8d6d`.
- APK SHA-256 from build log: `11f6bac0f92fa0588887801b6671691b5488b93f65bc9d2f35c6c50dd56d56fe`.

### Writer implementation confirmed on this branch
- Responsive Full Page, Page Width and Actual 100% viewport calculations.
- Zoom slider, percentage, zoom-in/out, fit controls and pinch/pan interaction.
- Compact ribbon spacing and larger usable page width.
- Explicit page-break embed persistence through the Writer document codec and portable backup.
- DOCX/ODT import/export foundations, Writer PDF export, Bengali font embedding/shaping work, headers/footers, PAGE/NUMPAGES DOCX fields, and localization improvements.
- Rich-content metrics estimate text, images, tables and explicit page breaks for a visual page-count estimate.

### Remaining Writer gaps — do not mark complete
- The current editor still uses one continuous QuillEditor inside painted page rectangles. `WriterContentMetrics` estimates page count; it does **not** provide true Word-like rich-content pagination or guarantee that images, tables and text flow across page boundaries with per-page margins.
- DOCX import currently reduces tables to plain text grids; merged cells, rich cell formatting, floating objects, and complex table layout are not preserved.
- DOCX/ODT import/export still needs section-specific, first-page and even-page headers/footers, richer section breaks and dynamic-field fidelity.
- ODT export currently uses one default master page; section-specific variants and advanced fields remain incomplete.
- Bangla spellcheck has not been proven against a real dictionary/engine.
- User font import/management and broad OpenType shaping/fallback validation remain incomplete.
- Remaining ribbon/dialog/error localization, long-document stress/recovery, and expanded editing/scroll/pinch tests remain open.
- Real Android-device interaction, Bangla PDF visual inspection, physical printer, and Word/LibreOffice interoperability checks remain outside CI and unverified.

### Next continuation actions
1. Continue a consolidated Writer source audit on the current PR head; preserve all existing Delta, table/image embeds, autosave, backup, page layout, review, citation and export behavior.
2. Implement only genuine supported behavior; do not disguise estimated pagination or flattened format import as full compatibility.
3. Add regression tests for each integrated correction and run Analyze, the complete test suite, Android release build, signature/package verification and Actions artifact upload on the final head.
4. Update this handoff with the exact new commit and CI evidence.
5. Keep PR #3 open until the user explicitly approves merging.

## Writer Master Requirements Contract — 2026-11-19

- Added `WRITER_MASTER_REQUIREMENTS.md` as the consolidated, binding A–Z Writer requirements and acceptance contract. It captures the user's requested desktop-style ribbon, mobile page viewport/zoom, true multi-page flow, rich text/tables/images, DOCX/ODT/PDF fidelity, Bangla fonts/spellcheck, storage/recovery, localization, accessibility, preservation rules and mandatory verification gates.
- The contract is a requirements baseline, **not** a claim that all features are implemented. In particular, current painted-page/continuous-Quill layout remains estimated pagination, not true page-flow pagination.
- Added a PDF export regression test covering explicit page-break content on both sides of the break.
- New commits: requirements contract `bd04b329b3ef6b1bd786081793e37abd5549e8a5`; PDF page-break test `d6e79b6eecdb49bd9f7bbeebbfee7b77b7e0d7f5`.
- These commits require a fresh CI run. Do not mark Writer complete until the full contract is implemented and all automated/manual acceptance gates have evidence. PR #3 remains open and must not be merged without explicit user approval.


## Branding and creator attribution refinement — 2026-11-19

- [x] Preserved the approved full OFFYNEXBD logo artwork and added a matching symbol-only SVG asset for small app-header and app-icon contexts, where the full wordmark would become unreadable.
- [x] Updated Home/App Info small logo placements and Android/iOS/Windows/macOS launcher-icon generation to use the symbol-only asset; the original full logo asset remains in the repository.
- [x] Standardized the App Info product tagline to the approved brand tagline: “The Future of Office Productivity”.
- [x] Kept the selected founder portrait, full creator name, Founder & Original Creator attribution, Rajshahi, Bangladesh location and copyright statement in App Info; no GitHub history or release records were added.
- [x] Added App Info regression assertions for the approved tagline and removal of the outdated tagline.
- [ ] Flutter Analyze, full tests, Android release build, icon generation and Actions artifact upload must pass on this commit before the branding batch is considered CI-verified.
- [ ] Visual inspection of launcher icons on a real Android device and cross-platform icon review remain pending.


---

## PR #3 Merge and Branding CI verification — 2026-11-19 (authoritative latest status)

- [x] User authorized the pending merge in the conversation; PR #3 was squash-merged successfully.
- [x] PR #3 is CLOSED and MERGED. Merge commit: `cb6888843763e592508146a644e87504da7fe942`; `main` points to this exact commit.
- [x] Final PR-head CI Build #510 / run ID `44557074087` completed SUCCESS on source commit `963089cf37f3404e73a7d37eb470ad90cb382f72`.
- [x] The Build #510 job completed Flutter Analyze, configured automated tests, Android release APK build, APK signature/install metadata verification, download package verification, and Actions artifact upload successfully.
- [x] Artifact: `OFFYNEXBD-Android-APK`, ID `14547445183`, size 51,778,220 bytes; not expired at verification time.
- [x] App branding and creator attribution changes in the merged commit passed the Build #510 CI checks. This confirms code/build checks, not visual inspection on a physical phone.
- [ ] Physical Android launcher/app-info visual inspection remains pending user-side device testing; iOS/Windows/macOS launcher appearance is not physically verified.
- [ ] Important Writer gap remains: editor still uses one continuous QuillEditor over painted page backgrounds, while page count is estimated from content metrics. True content-aware Word-style page-flow pagination with text/images/tables flowing between pages is NOT implemented or verified. Do not mark Writer complete.
- [ ] DOCX/ODT complex table fidelity, section-specific headers/footers, Bangla spellcheck and user font management, long-document recovery, physical printer checks and Word/LibreOffice interoperability remain outstanding as described in the requirements contract.
- PR #3 is merged; do not describe it as open or pending merge in future handoffs.


## Writer continuation audit and CI recovery — 2026-11-19 (latest)

- Current authoritative base: `main` commit `95278bf585af0b22387abc8b89a16a36ee1743e9`.
- PR #3 is CLOSED and MERGED at `cb6888843763e592508146a644e87504da7fe942`; the earlier New Chat Handoff text claiming it was open is stale and superseded by the authoritative merge section below it.
- PR #5 (`writer-mobile-page-zoom`) remains OPEN but is based on the pre-merge main commit `6cca1bb66b7f94e6265bc1a7d094141e7181c8e7`, is two commits behind current main, and GitHub reports it as dirty/non-mergeable. It is not the continuation base. Its zoom changes must be carried forward only after rebasing/revalidation; do not merge it as-is.
- Build #511 (run `44558963762`) on the PR #3 merge commit: Analyze SUCCESS, full configured Tests SUCCESS, Android APK build SUCCESS, signature/install metadata verification SUCCESS. The final Save Generated Source step failed because the workflow attempted to push a generated-source commit from an outdated checkout after main had advanced; package verification and artifact upload were skipped. This is a workflow push race, not a Dart Analyze/test/build failure.
- Updated the Save Generated Source workflow step to fetch and rebase the generated-source commit onto the latest branch before pushing, with bounded retries. This must be verified by a subsequent non-PR run; PR validation alone skips this step.
- Source audit confirms the current Writer canvas still hosts one continuous QuillEditor inside painted page rectangles. WriterContentMetrics estimates content height/page count; it is not an actual pagination/layout engine and does not reset page-specific content margins. Do not describe this as true Word-like pagination.
- Confirmed outstanding format limitations: DOCX table import currently flattens cells to strings (up to 20 rows × 10 columns), losing merged cells and cell/paragraph formatting; ODT table import similarly reduces cell content to plain text. DOCX/ODT section-specific first/even/default headers and footers and multiple section page settings are not fully represented. ODT export currently emits a single default page/master-page style. Existing DOCX PAGE/NUMPAGES and PDF page fields are narrower implementations, not full dynamic-field parity.
- Confirmed remaining acceptance work from the Writer contract: genuine editable rich-content page flow for text/images/tables; robust complex table model and round-trip; section-aware headers/footers and fields; real Bangla spellcheck; user font import/management; long-document recovery/stress; bottom toolbar overlap and full localization checks; visual Bangla PDF, physical Android/printer and Word/LibreOffice interoperability.
- Preserve Quill Delta, existing table/image/page-break embeds, autosave, backup/restore, layout metadata, comments, citations, revisions and export behavior during the next integrated implementation batch.
- This entry is an audit and CI recovery checkpoint, NOT a declaration that Writer is complete. Every pending acceptance gate remains pending until implemented and verified.


## Writer mobile zoom controls — integrated continuation (2026-11-19)

- Carried forward the useful direct Zoom In / Zoom Out controls from stale PR #5 onto the current main-based integrated branch, while preserving the current supported zoom range (50%–300%) rather than importing PR #5's narrower 50%–200% limit.
- Kept the existing Page / Page Width / Actual modes, persisted zoom, pinch/pan transform behavior and Quill content untouched.
- Added a Writer widget regression test for the zoom slider bounds and both direct zoom actions.
- This is a mobile usability improvement only; it does not solve true content-aware pagination or the other open Writer compatibility gaps.
- CI validation is pending for the integrated branch.


## DOCX/ODT table-grid import hardening — 2026-11-19

- DOCX import expands Word `gridSpan` cells into bounded logical grid slots. The first cell retains its text and extra spanned slots remain blank because the current Writer renderer does not yet support visual merged cells; later columns no longer shift left.
- ODT import expands `number-columns-repeated` and `number-rows-repeated` within the existing 20-row / 10-column safety limits. Covered ODT cells remain blank grid slots.
- Added focused DOCX and ODT archive-import regression tests.
- This improves grid alignment and repeated-cell fidelity; it does NOT implement visual merged cells, rich cell formatting, nested table editing, or full format round-trip.


## Writer compact header order correction — 2026-11-19

- Corrected the keyboard-open Writer header order to match the user's latest instruction: document name first, ribbon tabs second, compact formatting toolbar third.
- Ribbon tabs are now rendered once in the keyboard-open branch after the document-name field, and once in the keyboard-closed branch before the selected full ribbon. The AppBar remains hidden while the keyboard is open; nonessential ruler, zoom and status controls remain hidden in that state to preserve editing space.
- This is a targeted layout correction only. It does not claim true Word-style pagination or close the remaining DOCX/ODT, Bangla spellcheck/font-management, recovery, localization or physical-device acceptance gaps.
- Previous Build #525 / run `44578820556` succeeded on the parent commit `5b751bd6985979f551e851f52dba7cce4d0d24f8` (Analyze, tests, Android release APK, signing/package checks and `OFFYNEXBD-Android-APK` artifact upload). It does not verify this new correction; a fresh PR CI run is required.


## Writer header-order syntax correction — 2026-11-19

- Build #526 / run `44580491288` caught a missing closing collection bracket in the compact-header branch during Flutter Analyze; no test, APK or artifact was produced by that failed run.
- Corrected the nested collection structure while retaining the intended keyboard-open order (document name → ribbon tabs → compact formatting toolbar) and the normal keyboard-closed ribbon layout.
- A fresh CI run on this exact follow-up commit is required. The previous Build #525 result applies only to its earlier parent commit.


## Writer table localization correction — 2026-11-20

- [x] Passed the selected Bangla/English setting into the Insert Table dialog and the table embed editor in both the main Writer editor and editable Print Preview.
- [x] Localized table creation/edit titles, add/remove row and column actions, row/column count, border/fill color labels, cancel/apply actions, empty-table message and edit-table action.
- [x] Added a bilingual Writer widget regression test for the table editor.
- [x] Source committed on active PR #6 branch. Commits: `12f18a984d35983bd9f6bfd3f1539e36505495a0`, `61a91d73c4361da5948daec781d5666565cdea9c`, `2a4e8fe3a8c156bb82e4edb12a56cb9533cc19fe`.
- [x] Build #536 / run `44591359648`: Flutter Analyze SUCCESS and full automated Tests SUCCESS.
- [ ] Android release APK build, signing/package verification and Actions artifact upload are still running/pending at the time of this note.
- [ ] This localization fix does not close the major Writer requirements still open: true content-aware pagination, rich/merged DOCX/ODT tables, section-aware headers/footers, real Bangla spellcheck, user font management, long-document recovery, full ribbon/dialog localization, bottom-toolbar overlap and physical device/printer/interoperability checks.
- [ ] PR #6 remains OPEN and Draft. Do not merge without explicit user approval.
- [x] Build #534 artifact archive was independently downloaded and checked with `unzip -t`; all five entries passed CRC checks and archive SHA-256 matched GitHub artifact metadata. This proves the archive itself is valid, not the cause of Files by Google's device-specific extraction error.

---

## Integrated full-scope audit continuation — 2026-11-20

### Authoritative repository / CI state
- PR #3 remains CLOSED and MERGED; merge commit `cb6888843763e592508146a644e87504da7fe942`.
- PR #6 remains OPEN and Draft; do not merge without the user's explicit approval.
- Active branch: `work/writer-integrated-audit-ci-repair-20261119`.
- Current PR #6 head after the archive-safety regression test correction: `d08d31254d0448a84893115110473c22d113bc92`.
- Build #537 / run `44592317041` completed SUCCESS on `88dd9f53fc198db0a194d923095782b6f9295218`: Analyze, configured tests, Android release build, signing/install metadata, package verification and artifact upload all passed.
- Build #537 artifact: `OFFYNEXBD-Android-APK`, ID `14563559835`, size 51,820,701 bytes; expires 2026-12-03 19:00:50 UTC. Build #537 verifies its own source commit, not the later security patch.
- Archive relationship path hardening: commit `8f5896fedd17c833766ca151106a51d5c72a66de` now rejects DOCX/ODT relationship paths that traverse above the archive package root. Regression test added in `3da02ae8d53248cf3f9ab74c32c96b8c5713cf50`; test-file closure correction committed as `d08d31254d0448a84893115110473c22d113bc92`.
- Build #540 / run `44728176498` is the CI run for the final `d08d312...` head. At the time of this entry it is still in progress; no Analyze/test/APK/artifact success is claimed for the security correction until that run completes.

### Consolidated source audit — actual implementation boundaries
- Writer: rich text, local autosave, backup, basic table/image embeds, layout controls, review/reference tools and DOCX/ODT/PDF conversion foundations exist. The editor still hosts one continuous QuillEditor over painted page backgrounds; `WriterContentMetrics` estimates page count. This is NOT true content-aware page flow. Table cells are still plain strings; merged cells and rich per-cell formatting are not represented. Section-specific/first/even-page headers and footers, full section layout, real Bangla spellcheck, arbitrary user font management, large-document recovery/stress, remaining localization, bottom-toolbar overlap verification, and physical/interoperability acceptance remain open.
- Sheets: offline workbook/grid, formula engine, local persistence, CSV/XLSX subset import/export, validation, find/replace and PDF/print foundations exist. It is not full Excel parity: complete multi-sheet/cross-sheet behavior, advanced formulas, charts/pivots, conditional formatting, robust workbook collaboration and full external compatibility remain open.
- PDF: PDF-to-Writer and image-to-document conversion foundations with OCR exist. Full PDF text editing, merge/split/reorder/compression, annotations/forms/signatures, robust scanned-page rendering/OCR, password-protected input and full visual fidelity are not complete.
- Scan: Android ML Kit multi-page scan and Bengali/English OCR integration exist. Standalone scan-history management, broader platform parity and cloud synchronization remain open; device/Play-services behavior still needs physical-device verification.
- Slides: local slide records and PDF preview/export foundations exist; a full visual slide editor, layout/theme system, shapes/charts/animations, PPTX/ODP round-trip and slideshow feature set remain open.
- Fonts: the current workspace is not a real font manager. Font import, activation, preview/catalogue, license metadata, fallback and export embedding workflows remain open.
- AI Assistant: current workspace stores local prompts/records; no live or bundled AI inference/service integration is present. Provider, credentials, privacy controls and offline model decisions remain open.
- Cloud: local backup/restore utilities exist; there is no production account service, remote object storage, multi-device sync, conflict resolution or server-side version history.
- Forms: basic local form/question and response handling/export foundations exist; professional field types, validation/branching, templates, shareable hosted forms, permissions and multi-device response collection remain open.
- Database: local record/row and CSV workflows exist; relational tables, typed fields, indexes, query builder/SQL, relationships, reports and robust database migrations remain open.
- Backend/security: production authentication, hosted sync/storage, server API, encryption/key lifecycle, authorization and deployment/monitoring architecture are not implemented. Do not treat planned README folders as working backend services.

### Branding / creator proof
- Approved logo assets and App Info creator attribution are present in source; creator name, Founder & Original Creator, Rajshahi, Bangladesh and copyright are covered by widget assertions.
- CI verifies asset generation and app code; physical Android launcher icon / App Info visual inspection and iOS/Windows/macOS icon checks remain pending.

### Required continuation rules
- Continue integrated source changes across related modules while preserving existing saved data, document IDs, Delta embeds, formulas, workbooks, backups and branding.
- Do not call Writer or the ten-module suite complete based only on CI.
- Every manual/device/Word/LibreOffice/printer acceptance gate stays pending until actual evidence is recorded.
- Do not merge PR #6 or change the main branch without explicit user approval.

---

## User-approved PR merge and duplicate-control requirement — 2026-11-20

- User has now stated that merge permission was already granted. Treat this as current authorization for PR #6, superseding the earlier historical instruction to keep PR #6 Draft and unmerged. Merge only after the exact final head has passed required CI and the duplicate-option audit is clean.
- New permanent UX rule: the same command/action must not be exposed twice in the same context. Keep one authoritative control for each action; do not duplicate undo/redo, alignment, list, save, print, zoom or other commands across adjacent toolbars/tabs. Where a compact keyboard toolbar is necessary, avoid duplicating controls already displayed in the active ribbon.
- Audit found duplicate Home actions: Undo, Redo, paragraph alignment and list commands appeared in both the Home ribbon and the secondary Quill toolbar. The secondary toolbar now hides those duplicate commands while retaining indent actions.
- Added a widget regression assertion that each Home action icon is rendered exactly once.
- Restored Writer widget/editor constructor defaults to Bangla, consistent with the app's initial Bangla language setting; the main app continues to pass the explicit user-selected language.
- The user's approval does not waive the quality gate: no merge until latest PR head CI (Analyze, complete tests, signed Android build, signature/package verification and artifact upload) is successful. Recheck mergeability and exact head SHA immediately before merge.



## Integrated Sheets analytics port — 2026-11-20

- Ported the previously isolated Sheets charts / Pivot summaries / conditional-formatting feature batch onto a fresh branch based on the current `main`, rather than merging its stale, diverged PR branch.
- Added bounded cell-range parsing, conditional rules, chart data preparation, Pivot aggregation and validation helpers; added bilingual UI dialogs/widgets.
- Integrated persistent worksheet metadata and live-grid style/chart/Pivot actions into the current Sheets screen and workbook codec.
- Added focused analytics and workbook-codec regression tests.
- Source was ported by applying the reviewed PR #2 hunks to the current `main` files; every hunk matched exactly. Existing newer main-branch changes were retained.
- This is source integration only until a fresh CI run passes Analyze, all tests, signed Android build and artifact verification. XLSX native chart/conditional-rule round-trip and advanced Pivot filtering/drill-down remain known limitations.
- No merge to `main` was performed.


## Integrated Writer + Sheets batch — CI correction record — 2026-11-20

- Current integrated PR: #9, branch `work/integrated-sheets-analytics-20261120`.
- Writer mobile Page/Width/Actual fit modes, 50%–300% zoom slider, direct zoom controls and persisted zoom were verified in current main source; added a mobile widget regression test for zoom bounds/action/persistence.
- Sheets analytics from stale PR #2 was ported by exact-context patch application onto current main files: bounded range parsing, conditional formatting, bar/line chart previews and persisted specs, Pivot summary worksheets, workbook codec validation and tests. Existing current-main workbook code was retained.
- Build #557 / run `44737184125` reached Flutter Analyze and failed on 11 lint findings introduced by the port (deprecated DropdownButtonFormField.value, missing braces, string concatenation and unnecessary double underscore). Analyze failure correctly stopped tests and APK creation; no artifact was produced.
- Corrected all 11 reported lint findings in commits `40e0a77475462a6f4fcd27d55103878bf534b035` and `e12345e99195c022d8243e09f52b4eb619fdaa55`.
- Build #558 / run `44737466194` is queued on exact corrected head `e12345e99195c022d8243e09f52b4eb619fdaa55`. Do not mark the batch verified until Analyze, tests, signed APK, package checks and artifact upload pass.
- Known Sheets interoperability limits remain: native XLSX charts/conditional-rule metadata are not round-tripped; Pivot filtering/drill-down is limited. Writer true content-aware rich pagination and broader office-suite acceptance remain open.
- No changes merged to main.


## Integrated Writer + Sheets CI verification — 2026-11-20 (Build #564)

- [x] Final integrated branch head: `e56eae96e345b81562c6c7345cf2dc792e83efc3`.
- [x] Build #564 / run `44739199116` completed SUCCESS on that exact commit.
- [x] Flutter Analyze and the full configured automated test suite passed.
- [x] Android release APK built; signing and install metadata verification passed; download package contents verified; artifact upload passed.
- [x] Artifact: `OFFYNEXBD-Android-APK`, ID `14629763825`, size 51,995,343 bytes; SHA-256 `ff281464938611593599cb2e366c327115bfa8f386d148e99f35cd658be76359`; expires 2026-12-04 13:00:04 UTC.
- [x] Fixed the Writer mobile AppBar title overflow detected by Build #563 by constraining the title/subtitle to the available width and applying single-line ellipsis.
- [x] PR #9 remains OPEN, Draft, and unmerged; current head is mergeable against main. No merge was performed.
- [ ] This verifies the integrated Writer zoom regression and Sheets analytics batch only. It does not close true Writer pagination, native XLSX chart/rule round-trip, advanced Pivot features, remaining office modules, production backend/security, cross-platform release or physical-device acceptance.

## Integrated Database typed-field batch — 2026-11-20

- Added `DatabaseFieldCodec` with backward-compatible parsing: existing comma-separated field names continue to behave as optional text fields.
- Added typed schema definitions for text, number, email, date and choice fields, including required fields and bounded/unique choice options.
- Integrated schema parsing into the Database table workflow and added bilingual guidance for the field syntax.
- Row editing now provides numeric/email/date controls, date picker, choice dropdown and required/type validation.
- CSV import validates values against the active typed schema before appending any rows; CSV export retains the existing field order and safety behavior.
- Stored row values remain strings in the existing `offynex_database_rows_v1` structure, so existing records and CSV schema are not migrated or discarded.
- Added focused parser and typed-value validation tests. Automated CI for the latest source commit is pending; do not claim this batch verified until Analyze, all tests, signed APK, package/signature checks and artifact upload complete.
- This is a Database data-entry/validation improvement, not a relational engine. Primary/foreign keys, indexes, joins, query builder/SQL, transactions, migrations and reports remain outstanding.
