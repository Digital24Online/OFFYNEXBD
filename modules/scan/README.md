# OFFYNEX Scan — implementation and completion specification

## Current implemented foundation
- Android uses Google ML Kit Document Scanner for automatic capture, edge detection/crop, perspective correction, rotation, filters/cleanup and multi-page PDF output (up to 50 pages per session).
- Saved PDF validation and staged/atomic storage, PDF Reader handoff, sharing and confirmed deletion exist.
- Bengali/English OCR, scan history, Writer handoff and OCR correction synchronization foundations exist.
- Non-Android currently uses image-picker/OCR fallback; native scanner parity is not implemented.

## Remaining implementation
- Verify scanner availability, first-run component download, cancellation, permissions and failure behavior across supported Android devices.
- Add/complete manual crop, rotate, reorder/delete page, brightness/contrast, shadow/glare removal and filter presets where native SDK does not provide required controls.
- Improve OCR review with page-by-page confidence, text correction, language selection and reliable Writer synchronization.
- Add import from gallery, PDF/image batch processing, file naming, tags/search and scan-history management.
- Ensure source images/PDFs are preserved until user confirms deletion; handle interrupted writes and storage-full errors.
- Evaluate native iOS/desktop capture separately; do not label Android-only ML Kit support as cross-platform.
- Benchmark Bengali/English OCR for clean, skewed, low-light, multi-column and small-print samples on physical devices.

## Acceptance gates
- Camera/capture/crop/multipage/PDF lifecycle tests on physical Android devices.
- OCR quality samples, correction persistence and linked Writer document synchronization tests.
- Storage integrity, large-file, cancellation and low-storage tests.
- Analyze, full tests and signed Android build pass; platform parity documented independently.
