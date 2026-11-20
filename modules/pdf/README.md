# OFFYNEX PDF

## Implemented foundations
- Validated PDF input with a 50 MB safety limit and a 1–1,000 page conversion bound.
- PDF-to-Writer conversion and DOCX output with archive-signature verification.
- Bengali/English OCR attempt for image-only PDFs where the platform OCR engine is available.
- A PDF Reader preview for selected PDF bytes with print and share actions.
- Scanned PDFs can be opened from Scan history in the same Reader preview.
- Original PDF bytes remain unchanged by conversion and preview.

## Not yet complete
- Editing existing PDF text/content and replacing embedded images.
- Merge, split, reorder, insert and delete pages.
- Compression and optimization with measurable quality/size controls.
- Annotation, highlight, comments, drawing and redaction.
- Interactive forms, field validation and saving filled form values.
- Digital signatures and certificate validation.
- Password protection, encryption, permissions and encrypted-PDF import.
- OCR review/correction and searchable text-layer generation.
- Metadata editor, batch operations, bookmarks, thumbnails and advanced search.
- Visual comparison of Bangla glyph shaping and large-file performance on real devices.

## Verification
The Reader and conversion foundations require Flutter Analyze, all automated tests, signed Android release validation and artifact upload on the same commit. Physical device, printer and real PDF interoperability checks remain separate acceptance gates.
