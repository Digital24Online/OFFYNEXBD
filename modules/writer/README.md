# OFFYNEX Writer

OFFYNEX Writer is the document-editing module of OFFYNEXBD. It uses Flutter Quill and stores editable Quill Delta documents locally.

## Implemented foundations

- Create, rename, edit, clear and delete documents.
- Automatic local save with queued writes and document-library recovery copies.
- Versioned native Writer archive JSON import/export. Existing document IDs are preserved; duplicate IDs are not overwritten.
- Rich text: bold, italic, underline, strike-through, numeric font size, text color, highlight, paragraph alignment, lists, indentation, undo and redo.
- Bundled Bengali Noto Sans / Noto Serif font selection and Unicode fallback for PDF export.
- Insert and edit Writer tables; insert local images with file validation and app-private storage.
- Hyperlinks, date, symbols, citations, bibliography, footnotes, endnotes, captions and table of contents.
- Review comments, Find/Replace and revision snapshots with restore, delete and clear actions.
- Page setup: A4, A5, Letter and Legal; portrait/landscape; normal/narrow/moderate/wide/custom margins; page color and border.
- View controls: Page, Page Width and Actual/100% fit; zoom slider and direct zoom actions; pinch/pan, ruler, status bar and focus mode.
- DOCX and ODT import/export foundations for supported paragraphs, common inline formatting, headings, lists, basic tables, images and page setup.
- DOCX default header/footer text and supported PAGE/NUMPAGES placeholders; PDF repeating header/footer and dynamic page placeholders.
- PDF export, editable Print Preview and system printing, with bundled Bengali font embedding and OpenType shaping support.
- PDF-to-Writer and image-to-document conversion foundations with Bengali/English OCR where the platform OCR engine is available.
- Writer ribbon labels and the main library/editor shell follow the app's Bangla/English language selection.

## Important format and fidelity boundaries

- The native Writer archive is JSON, not DOCX or ODT; it remains the loss-minimizing editable backup.
- DOCX/ODT interchange is a supported subset, not lossless Microsoft Word / LibreOffice compatibility. Unsupported advanced constructs may be simplified and must not be assumed to round-trip exactly.
- The on-screen canvas still hosts one continuous QuillEditor over painted page backgrounds. Page count/height is estimated from content metrics; this is **not** true content-aware page-flow pagination. Text, images and tables do not yet have independently laid-out per-page editing regions.
- Writer table embeds currently store plain-text cell values in a row/column grid. Visual merged cells, rich per-cell formatting, nested tables and full table-width/layout fidelity are not implemented.
- Multiple section page settings and section-specific, first-page or even-page headers/footers are not fully represented. ODT export currently uses a single default master-page layout.
- PDF generation has its own pagination; visual Bangla shaping, line wrapping, mixed-script output and physical printer fidelity still require representative rendered-PDF and device checks. Font embedding alone is not proof of identical rendering on every platform.
- PDF-to-Writer conversion and OCR are text-first foundations; complex multi-column positioning, scanned-page rendering fallbacks, encrypted PDFs and exact source-layout reconstruction remain incomplete.
- A complete font catalogue/import manager, arbitrary user-installed fonts, Bijoy ANSI conversion, genuine Bangla spellcheck dictionary integration and cloud synchronization are not implemented.
- Long-document stress/recovery, remaining dialog/error localization, bottom-toolbar overlap, physical Android interaction, printer output and Word/LibreOffice interoperability still require acceptance testing.

## Validation

Automated checks are maintained under `test/writer_*.dart`. A source change is verified only after Flutter Analyze, the complete test suite, Android release APK build, existing signing-certificate validation, package verification and Actions artifact upload pass on the same code commit. Manual/device and interoperability gates must be recorded separately.
