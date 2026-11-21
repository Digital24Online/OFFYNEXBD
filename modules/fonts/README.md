# OFFYNEX Fonts — implementation and completion specification

## Current implemented foundation
- Writer exposes bundled Bengali Noto Sans / Noto Serif choices and Unicode fallback for PDF export.
- Fonts workspace currently stores local font-related records/notes; it is not a font installation or management engine.

## Remaining implementation
- Import TTF/OTF safely from device storage; validate file signature, metadata, tables, glyph count, size and malformed-font safety before activation.
- Provide specimen preview for Bangla/English, numerals, punctuation, যুক্তাক্ষর, কার/ফলা/রেফ and variable-font axes.
- Add search, family/style/weight categories, favorites, collections, duplicate detection and font metadata.
- Provide app-scoped font activation and document font assignment; do not silently install fonts system-wide.
- Embed fonts only when license permissions allow; preserve font references and report substitutions on export.
- Add shaping diagnostics and cross-platform fallback tests; WOFF2 support only if a secure decoder is selected and tested.
- Add font licensing/source metadata and remove/uninstall behavior without breaking documents.

## Acceptance gates
- Valid, invalid, spoofed, oversized and malformed font fixtures.
- Bengali shaping visual tests on Android and desktop; DOCX/PDF embedding/substitution tests.
- Analyze, full tests and signed Android build pass; licensing and performance review recorded.
