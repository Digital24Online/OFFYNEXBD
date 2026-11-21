# OFFYNEX PDF — implementation and completion specification

## Current implemented foundation
- Validated PDF selection and read-only PDF preview with print/share.
- PDF-to-Writer and image-to-Document conversion foundations; Bengali/English OCR attempt where supported.
- Scan history can hand saved PDFs to the Reader. Original source bytes are retained during conversion.
- Current Reader is read-only: preview, print and share are not PDF editing.

## Remaining implementation — full document lifecycle
### Page and content editing
- Add page thumbnails, reorder, rotate, insert blank page, extract, duplicate, delete, merge and split.
- Add text/object editing where technically possible, replace/add images, crop and reposition objects.
- Add annotations: highlight, underline, strike-through, freehand drawing, shapes, sticky notes and comments.
- Add secure redaction that removes underlying content rather than drawing over it.

### Forms, signatures and security
- Support interactive form fields, fill/validate/save/export filled forms.
- Add digital signature creation, certificate chain validation and signature verification UI.
- Add password-protected open/save, encryption, permissions and encrypted import/export; never log passwords.
- Add metadata/bookmark/outline editor, full-text search and batch operations.

### Conversion, OCR and performance
- Add OCR review/correction, searchable text layer, page selection and conversion progress/cancel.
- Handle multi-column layouts, tables, mixed scanned/text pages, malformed/encrypted/large PDFs and renderer fallback.
- Add compression/optimization presets with measurable output size and quality comparison.
- Keep original files immutable unless the user explicitly saves a new edited copy.

## Required source/test areas
- `pdf_reader_screen.dart`, `pdf_to_document_screen.dart`, `pdf_to_document_service.dart`
- `scan_document_service.dart`, Writer import/export integration and PDF tests.

## Acceptance gates
- PDF fixtures for text, image, tables, scanned Bangla/English, encrypted, malformed and large files.
- Verify page ordering, text layer, annotations, redaction, forms and signature behavior.
- Analyze, full tests and signed Android build pass; physical device, PDF viewer and printer checks recorded.
