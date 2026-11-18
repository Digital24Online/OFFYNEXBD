# OFFYNEX Writer

OFFYNEX Writer is the document-editing module of OFFYNEXBD. It is built on Flutter Quill and stores editable Quill Delta documents locally.

## Implemented

- Create, rename, edit, clear and delete documents.
- Automatic local save with queued writes and document-library recovery copies.
- Versioned native Writer archive JSON import/export. Existing document IDs are preserved; duplicate IDs are not overwritten.
- Rich text: bold, italic, underline, strike-through, font size, text color, highlight, paragraph alignment, lists, indentation, undo and redo.
- Bundled Bengali Noto Sans / Noto Serif font selection and Noto Sans Unicode fallback for PDF export.
- Insert and edit Writer tables; insert local images with file validation and private app storage.
- Hyperlinks, date, symbols, citations, bibliography, footnotes, endnotes, captions and table of contents.
- Review comments, Find/Replace and revision snapshots with restore, delete and clear actions.
- Design and page layout: A4, A5, Letter, Legal; portrait/landscape; normal/narrow/moderate/wide/custom margins; page color and border.
- View: page/width/actual fit, zoom, ruler, status bar and focus mode.
- PDF export, print preview and system printing with Bengali OpenType shaping, mixed Bengali/English text, images, tables, margins, repeating header/footer and dynamic `{page}` / `{pages}` footer placeholders.
- DOCX export for supported rich text, headings, tables and embedded image bytes. Image paths are not written as broken device-local links.
- Writer ribbon labels and main library/editor shell follow the app's Bangla/English language selection.

## Important format and fidelity boundaries

- The native Writer archive is JSON, not DOCX or ODT.
- DOCX export is a conversion to Office Open XML. Some advanced Quill-specific constructs or exact Word layout may be simplified; the native Writer archive remains the loss-minimizing editable backup.
- DOCX import into the native Quill editor is not yet implemented.
- ODT import/export is not implemented.
- The on-screen multi-page canvas currently estimates page count from plain text; it is not a full Word-style rich-content pagination engine. The generated PDF uses its own actual pagination.
- Page headers/footers are included in PDF output; DOCX header/footer export is not yet wired to Writer metadata.
- Font catalogue management, arbitrary user-installed fonts, Bijoy ANSI conversion, native spell-check dictionary integration, and true cross-device/cloud sync are not part of the current Writer implementation.
- Physical printer output and visual parity on every supported desktop/mobile platform still require device-level verification.

## Validation

Automated checks are maintained under `test/writer_*.dart`. A Writer change is considered verified only after Flutter Analyze, the complete test suite, Android release APK build and artifact upload all pass for the same source commit.
