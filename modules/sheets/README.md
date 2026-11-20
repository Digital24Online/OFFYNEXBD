# OFFYNEX Sheets

OFFYNEX Sheets is an offline-first, multi-worksheet spreadsheet workspace with a mobile-friendly grid and desktop-style Ribbon.

## Implemented and CI-tested foundations

- Cell selection, editing, formula bar and formula recalculation.
- Local workbook autosave and reload using SharedPreferences.
- Row and column growth; populated edge rows/columns are protected from removal.
- Cell formatting: bold, italic, underline, font size, font color, fill, horizontal/vertical alignment, wrapping, borders and basic number formats.
- XLSX import/export for all worksheets, including a supported subset of cell values, formulas, formatting and fixed dropdown validation. Worksheets larger than the supported 1,000 × 100 grid are rejected before replacing saved data.
- Cross-worksheet formula references for direct cells and bounded aggregate ranges, including quoted worksheet names with spaces; missing sheets, invalid ranges and circular references return formula errors.
- CSV import/export for cell values and formulas, with UTF-8/Bengali text, optional UTF-8 BOM, commas, escaped quotes, CRLF/LF line endings and quoted multiline fields. Import confirms before replacing the active sheet and enforces the same 1,000 × 100 grid limit.
- Display-only sorting and filtering by the selected column: A→Z / Z→A sorting, case-insensitive substring filtering, combined sort + filter, blank cells last, stable original-order ties, and Clear sort/filter. The worksheet's underlying cell data, formulas, styles and formula references are not moved; clearing the view restores original row order. CSV/XLSX import and Clear Sheet reset the view state.
- A4 landscape PDF export and print pipeline with Bengali OpenType shaping, English/Unicode fallback, supported cell styles, gridline visibility and page numbering.
- Formula engine with 36 numeric and logical functions:
  `SUM, AVERAGE, COUNT, MIN, MAX, PRODUCT, ABS, ROUND, ROUNDUP, ROUNDDOWN, SQRT, POWER, MOD, INT, SIGN, MEDIAN, LARGE, SMALL, CEILING, FLOOR, PI, EXP, LN, LOG, LOG10, SIN, COS, TAN, ASIN, ACOS, ATAN, IF, IFERROR, AND, OR, NOT`.
- Formula parsing supports arithmetic precedence, numeric comparisons, parentheses, cell references, ranges, nested calculations, circular-reference detection and range-error propagation. IF and IFERROR evaluate only the selected/result-needed branch. AND/OR/NOT currently operate on numeric truth values; this is not full Excel text/logical-value compatibility.
- Bangla and English UI labels.

## Known limitations — not Excel parity

- Cross-worksheet formula references currently support numeric direct references and aggregate ranges; full Excel reference syntax, external workbook references and 3-D references are not implemented.
- Formula compatibility is partial. Text, date/time, lookup, conditional aggregate (for example COUNTIF/SUMIF), array/dynamic and financial function families are not implemented. Logical functions are numeric-only.
- Charts, pivot tables, data validation, conditional formatting, named ranges, external links and macros are not implemented.
- XLSX import/export preserves only the supported subset; complex workbook structures, charts, merged cells, formulas outside the supported engine and advanced styles need compatibility work.
- ODS import/export is not implemented. CSV does not store cell formatting, workbook formulas are exported as formula text, and CSV import creates unformatted cells.
- Print preview controls, custom page scaling, repeated print titles and page-break editing remain pending.
- The mobile grid virtualizes rows; very large workbook performance and full desktop keyboard navigation need further testing.

## Verification policy

A feature is considered verified only after GitHub Actions Flutter Analyze, all automated tests, Android release APK build and artifact upload succeed. CI does not replace visual inspection on physical devices and printers.
