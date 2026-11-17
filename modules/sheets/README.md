# OFFYNEX Sheets

OFFYNEX Sheets is an offline-first, single-worksheet spreadsheet workspace with a mobile-friendly grid and desktop-style Ribbon.

## Implemented and CI-tested foundations

- Cell selection, editing, formula bar and formula recalculation.
- Local workbook autosave and reload using SharedPreferences.
- Row and column growth; populated edge rows/columns are protected from removal.
- Cell formatting: bold, italic, underline, font size, font color, fill, horizontal/vertical alignment, wrapping, borders and basic number formats.
- XLSX import/export for the active worksheet, including a supported subset of cell values, formulas and formatting. Import explicitly lets users choose one worksheet from a multi-sheet file; other worksheets remain in the original XLSX and are not silently merged or discarded. Worksheets larger than the supported 1,000 × 100 grid are rejected before replacing saved data.
- A4 landscape PDF export and print pipeline with Bengali OpenType shaping, English/Unicode fallback, supported cell styles, gridline visibility and page numbering.
- Formula engine with 31 functions:
  `SUM, AVERAGE, COUNT, MIN, MAX, PRODUCT, ABS, ROUND, ROUNDUP, ROUNDDOWN, SQRT, POWER, MOD, INT, SIGN, MEDIAN, LARGE, SMALL, CEILING, FLOOR, PI, EXP, LN, LOG, LOG10, SIN, COS, TAN, ASIN, ACOS, ATAN`.
- Formula parsing supports arithmetic precedence, parentheses, cell references, ranges, nested calculations, circular-reference detection and range-error propagation.
- Bangla and English UI labels.

## Known limitations — not Excel parity

- Workbook currently has one active worksheet; multi-sheet tabs and cross-sheet references are not implemented.
- Formula compatibility is partial. Logical, text, date/time, lookup, conditional aggregate, array/dynamic and financial function families are not implemented.
- Charts, sorting/filtering, pivot tables, data validation, conditional formatting, named ranges, external links and macros are not implemented.
- XLSX import/export preserves only the supported subset; complex workbook structures, charts, merged cells, formulas outside the supported engine and advanced styles need compatibility work.
- ODS and CSV import/export are not implemented.
- Print preview controls, custom page scaling, repeated print titles and page-break editing remain pending.
- The mobile grid virtualizes rows; very large workbook performance and full desktop keyboard navigation need further testing.

## Verification policy

A feature is considered verified only after GitHub Actions Flutter Analyze, all automated tests, Android release APK build and artifact upload succeed. CI does not replace visual inspection on physical devices and printers.
