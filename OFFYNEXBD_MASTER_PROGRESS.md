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
- [ ] Slides, Fonts, AI Assistant, Cloud, Forms, Scan and Database are not yet implemented as working modules.
- [ ] A production backend, cloud authentication/synchronization service, and complete database/security architecture are not yet implemented.
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
