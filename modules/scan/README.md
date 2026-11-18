# OFFYNEX Scan

OFFYNEXBD's document scanning and OCR module.

## Android native scanner

The Android app uses Google's ML Kit Document Scanner through
`google_mlkit_document_scanner` 0.4.1. The scanner provides:

- Automatic document detection and capture
- Automatic edge detection and crop
- Perspective correction and rotation
- Full scanner mode with filters and cleanup tools
- Multi-page capture (up to 50 pages per session)
- PDF and JPEG page output
- Optional gallery import in the native scanner
- Bengali + English OCR on captured page images
- Saved PDF in app documents and a share action
- Recognized text saved as a Writer document

The scanner UI and image-processing resources are provided by Google Play
services. The first use may require an internet connection to download scanner
components. No app camera permission is required by this ML Kit flow.

## Platform behavior

- Android: native ML Kit document scanner with multi-page PDF output.
- Other platforms: existing image-picker OCR route remains available; the
  native ML Kit scanner is Android-only in this dependency version.
- OCR uses the existing Tesseract Bengali and English language data.

## Limits and notes

- Native scanner PDF output is limited to 50 MB.
- Each OCR page image is limited to 30 MB.
- Scanner capabilities depend on Google Play services and device support.
- This implementation does not yet provide a standalone scan-history manager
  or cloud synchronization of captured PDFs.

## Status

Native Android scanning and multi-page OCR integration added; automated
Analyze, tests and release APK validation are pending.
