# OFFYNEXBD Writer — Master Requirements and Completion Contract

**Purpose:** This file is the consolidated, binding Writer scope for implementation and acceptance. It is not a declaration that every item is already implemented. A feature is complete only when the implementation exists, regression tests pass, and the relevant device/interoperability checks are recorded.

## 1. Product and design direction

- Writer is a professional office word processor, not a basic note editor.
- Visual and interaction quality should be comparable in spirit to Microsoft Word/Office, WPS Writer and Google Docs while retaining OFFYNEXBD branding.
- Use a compact desktop-style ribbon adapted carefully for Android phones. Ribbon controls must remain usable and must not cover the document or bottom controls.
- The page must be visibly large and legible on a phone. Users must be able to see the whole page, zoom in/out, use Page Width and Full Page fit, and pinch/pan naturally.
- Provide a clean paper canvas, page boundaries, margins, ruler, status information and a professional editing workspace.
- Preserve the selected OFFYNEXBD logo/branding and existing app navigation.

## 2. Ribbon and editing commands

Required ribbon structure:
- File
- Home
- Insert
- Design
- Layout
- References
- Review
- View

Required editing behavior:
- Numeric font-size choices and font-family selection; do not replace numeric sizes with vague Small/Large controls.
- Bold, italic, underline, strikethrough, text color, highlight, alignment, bullets, numbering and indentation.
- Undo/redo, select all, save, autosave and document rename.
- Clear-document action must be guarded against accidental data loss.
- Formatting must apply to the selected text and preserve existing selection behavior.
- Tables and images must be inserted from the Insert ribbon.
- Keep keyboard/focus behavior predictable on Android.

## 3. Page and layout

- A4, A5, Letter and Legal paper sizes.
- Portrait and Landscape orientation.
- Normal, Narrow, Moderate and Wide presets plus custom margins and reset.
- Ruler and page-boundary visibility controls.
- Full Page, Page Width and Actual/100% view modes.
- Persistent zoom controls, zoom percentage, zoom in/out, slider, pinch zoom and pan.
- The page must remain editable in every view mode.
- True multi-page document layout is required: content must flow across pages with page-specific content areas and margins. A painted page-count estimate over one unbounded editor is not accepted as true pagination.
- Text, styled runs, lists, images and tables must not be clipped, overlapped, duplicated or silently lost at page boundaries.
- Explicit page breaks must persist through editing, autosave, backup/restore and export.
- Page breaks and automatic page flow must work together.
- Print Preview must show the output layout while retaining a route back to editable document content; preview must not become a destructive or read-only dead end.

## 4. Insert and rich content

- Tables: create, edit, add/remove rows and columns, preserve cell content and formatting, and handle long cells and page boundaries.
- Images: import, size, align, preserve aspect ratio, and retain the image through save/reopen/backup/export.
- Rich text: preserve inline styles, paragraph styles, alignment, lists and indentation.
- Embedded content must have explicit validation and safe failure behavior; malformed embeds must not corrupt the document.
- No placeholder button or decorative control may claim functionality that is not implemented.

## 5. Document storage and reliability

- Preserve existing document records, IDs, titles, Quill Delta content, page layout and metadata.
- Maintain backward compatibility with previously saved document formats.
- Autosave must serialize writes safely and avoid stale writes overwriting newer edits.
- Save/reopen, app restart, backup/restore, rename, duplicate and delete flows must be tested.
- Failed writes/imports/exports must produce understandable localized feedback and must not destroy the source document.
- Long documents must not freeze the UI or silently truncate content; add stress and recovery tests.

## 6. File compatibility

### DOCX
- Import and export paragraphs, rich inline formatting, headings, lists, tables, images, page setup, headers and footers.
- Preserve table structure, merged cells, cell formatting and widths; flattening tables into text grids is not acceptable for a complete compatibility claim.
- Preserve section breaks and section-specific page settings.
- Support default, first-page and even-page headers/footers where represented in the source.
- PAGE and NUMPAGES fields must remain dynamic where supported.
- Unsupported constructs must be reported clearly rather than silently discarded.

### ODT
- Import and export document styles, tables, images, page layout and section/master-page variations.
- A single default master page is not sufficient for claiming full section/header/footer fidelity.
- Preserve supported fields and make unsupported features explicit.

### PDF and print
- Export must preserve Bangla shaping, conjuncts, kar/fola, mixed Bangla/English text, font styles, paragraph layout, lists, images, tables, headers/footers and page breaks.
- Embed suitable fonts and use correct fallback; do not silently substitute fonts that change the visible Bangla layout.
- PDF-to-Writer conversion must preserve extractable text and supported styling/images/tables; OCR should be available for scanned pages when configured.
- Print Preview and saved/printed PDF must be checked for consistent page geometry and text flow.
- Automated text extraction tests alone do not prove visual glyph shaping or physical-printer fidelity.

## 7. Bangla language and fonts

- Bangla text, যুক্তাক্ষর, কার, ফলা and mixed-script paragraphs must display and export correctly.
- Provide font-family selection and a genuine user font management/import workflow.
- Font fallback must preserve glyph coverage and avoid tofu, broken conjuncts or unexpected line-height changes.
- Bangla spellcheck must use a real dictionary/engine; a decorative toggle or generic English checker is not completion.
- Verify representative Bangla documents visually in the app and in exported PDF, including long paragraphs and line wraps.

## 8. Review, references and localization

- Review tools and reference tools exposed in the ribbon must perform real actions or be clearly disabled/not exposed until implemented.
- Localize visible ribbon labels, dialogs, errors, confirmations, status messages and import/export feedback in Bangla and English.
- Changing language must not corrupt document content or saved preferences.

## 9. Accessibility and phone usability

- Touch targets must be practical on Android.
- Ribbon overflow and lower-toolbar overlap must be resolved; the Apps option or other bottom navigation must not obscure Writer controls.
- Support keyboard visibility, scrolling, zoom/pan and focus transitions without losing selection or edits.
- Test narrow and wide phone viewports, landscape orientation and system font/display scaling.

## 10. Security and data handling

- Validate imported archives and embedded payloads; enforce size/type limits for images and documents.
- Avoid path traversal when extracting DOCX/ODT media.
- Do not silently ignore malformed or unsupported data.
- Preserve local user documents and never replace content with sample/demo data.

## 11. Required verification gates

A final Writer completion claim requires all of the following:
1. Source audit against every section in this contract.
2. Implementation of every in-scope requirement, or an explicitly approved and clearly disclosed exclusion (no hidden omissions).
3. Unit tests for codecs, pagination, tables, embeds, formatting, storage and conversion.
4. Widget tests for ribbon actions, page editing, zoom/pinch/pan, dialogs, localization and bottom-toolbar layout.
5. Regression tests for old documents, autosave ordering, backup/restore and malformed input.
6. Flutter Analyze and the full automated test suite passing.
7. Android release APK built, existing signing certificate verified, package metadata validated and Actions artifact uploaded.
8. Manual Android-device checks for page fit, zoom, keyboard, selection, scroll, Bangla rendering and long-document behavior.
9. Visual inspection of exported Bangla PDF and interoperability checks with Microsoft Word/LibreOffice for representative DOCX/ODT files.
10. Every unverified/manual gate remains marked pending; CI success alone must not be described as full Writer completion.

## 12. Preservation rules

- Do not remove or regress existing Writer functions, saved data, document formats, page-layout preferences, branding or autosave behavior while adding features.
- Do not merge PR #3 without explicit user approval.
- Work should be integrated across the relevant source files and tests, not delivered as a chain of isolated partial patches.
- Report completion only after the gates above have evidence.
