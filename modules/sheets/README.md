# OFFYNEX Sheets — implementation and completion specification

## Current implemented foundation
- Offline workbook with multiple worksheets, cell selection/editing, formula bar, local autosave and recovery.
- Lazy/virtualized grid, fixed header, row/column operations, formatting, wrapping, borders and number formats.
- XLSX and CSV import/export for supported subsets; Bengali/UTF-8 CSV handling and safety limits.
- Formula engine with arithmetic, references, ranges, error propagation, circular-reference protection and a growing function set.
- Freeze top row, find/replace, validation dropdowns, display-only sorting/filtering, PDF export and print.
- Source contains chart data creation/gallery, Pivot summary creation/refresh, conditional-format rules and related tests. These are foundations; do not document them as absent or as full Excel parity.

## Remaining implementation — all must be addressed
### Formula and workbook compatibility
- Expand text, date/time, lookup/reference, conditional aggregate, financial, statistical, dynamic-array and modern Excel function families.
- Improve Excel-compatible coercion, blank/text/boolean handling, dates, error types, formula locale separators and formula serialization.
- Add named ranges, structured table references, external workbook behavior and robust cross-sheet reference semantics.
- Improve XLSX round-trip for styles, merged cells, widths/heights, validations, charts, conditional formats, named ranges, print settings and unsupported-feature warnings.
- Add ODS import/export and verify with real LibreOffice/Excel files.

### Analysis and visual tools
- Make charts fully editable: type, series, labels, axes, legend, titles, colors, data range, move/resize and export.
- Expand Pivot tools: multiple row/column/value fields, filters, grouping, sort, subtotal/grand-total choices and refresh behavior.
- Complete conditional formatting: multiple prioritized rules, formula rules, color scales/data bars/icon sets where supported.
- Add named ranges, robust data validation types and validation interoperability.

### Printing, navigation and scale
- Add editable print preview, page breaks, margins/orientation/scale, repeated titles, print area and page headers/footers.
- Freeze columns and arbitrary panes; improve desktop keyboard navigation, accessibility and large workbook performance.
- Validate formula dependencies, undo/redo, autosave/recovery and import cancellation.

## Required source/test areas
- `sheets_screen.dart`, `sheets_formula_engine.dart`, `sheets_analytics.dart`, `sheets_analytics_widgets.dart`
- `sheets_workbook_codec.dart`, `sheets_xlsx_validation_codec.dart`, `sheets_data_validation.dart`, `sheets_pdf_export_service.dart`
- Tests: all `test/sheets_*.dart`

## Acceptance gates
- Formula regression and workbook import/export round-trip tests using real fixtures.
- Charts, pivots, conditional formatting and validation tested after save/reload and export.
- Analyze + complete tests + signed Android build/package checks pass on the same commit.
- Physical device, large workbook, Excel/LibreOffice and Bengali print/PDF comparisons recorded separately.
