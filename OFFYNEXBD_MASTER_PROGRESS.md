# OFFYNEXBD MASTER PROJECT

## Brand
Name: OFFYNEXBD
Tagline: The Future of Office Productivity

## Platforms
- Android
- iPhone
- Windows
- macOS

## Main Modules
1. OFFYNEX Writer
2. OFFYNEX Sheets
3. OFFYNEX Slides
4. OFFYNEX PDF
5. OFFYNEX Fonts
6. OFFYNEX AI
7. OFFYNEX Cloud
8. OFFYNEX Forms
9. OFFYNEX Scan
10. OFFYNEX Database

## Project Requirements
- Desktop-class office features
- Bengali and international font support
- DOCX, XLSX, PPTX, ODT, ODS, ODP and PDF
- Offline-first with online synchronization
- Security, backup and accessibility
- Open-source technology preferred

## User Working Rules
- User works only from Android phone.
- User does not know coding.
- Do not ask user to upload documents or images.
- Give one simple instruction at a time in easy Bangla.
- Avoid repeating completed work.
- Preserve project continuity across new chats.

## Project Status
- Brand selected.
- Main feature plan prepared.
- GitHub repository created: OFFYNEXBD.
- Master progress file being created.

## Next Step
Complete and save this master progress file.
Then prepare the project folder structure.

## Completed Repository Structure

- [x] Android app folder
- [x] iPhone app folder
- [x] Windows app folder
- [x] macOS app folder
- [x] OFFYNEX Writer
- [x] OFFYNEX Sheets
- [x] OFFYNEX Slides
- [x] OFFYNEX PDF
- [x] OFFYNEX Fonts
- [x] OFFYNEX AI
- [x] OFFYNEX Cloud
- [x] OFFYNEX Forms
- [x] OFFYNEX Scan
- [x] OFFYNEX Database
- [x] Backend
- [x] Database Architecture
- [x] Security

## Current Status

Repository structure created.
Actual application development has not started.

## Next Development Tasks

1. Verify technology choices and licenses.
2. Finalize cross-platform architecture.
3. Set up the development environment.
4. Build the first working application.
5. Test Android application.
6. Expand to other platforms.

## Important Rules

- Never mix OFFYNEXBD with Digital 24 Online or INAB BD.
- Do not ask the user to upload documents or images.
- Do not repeat completed steps.
- Preserve this progress after important changes.

## Verified Development Checkpoint — 2026-11-16

### Current Repository
- Repository: `Digital24Online/OFFYNEXBD`
- Active branch: `main`
- Android Build: **SUCCESS**
- Latest verified workflow run: `43918721213`
- Android APK artifact: `OFFYNEXBD-Android-APK` (28.5 MB)
- Automatic Build is enabled for source changes under `lib/**`, `modules/**`, and workflow changes.

### OFFYNEX Writer — Verified Serial Status
- [x] Serial 14.6 — Image Support: Insert Image button, image file selection and size/format checks, local image persistence, Quill image embed rendering and preview.
- [x] Serial 15 — Layout Tab: A4/A5/Letter/Legal paper sizes; Portrait/Landscape; Normal/Narrow/Moderate/Wide presets; Custom Margins; Reset Layout; responsive page display; per-document Layout Auto Save.
- [ ] Serial 16 — References, Review and View: existing basic controls are present in `writer_screen.dart`; complete feature audit and enhancement are still required before marking complete.

### Important Technical Notes
- Writer screen: `lib/lib/modules/writer/writer_screen.dart`
- Writer table embed: `lib/lib/modules/writer/writer_table.dart`
- Preserve existing table embed identifier: `offynexbd-writer-table`.
- Image files currently live in the app's private `offynexbd_images` directory. Portable document export/import must package images with the document; do not treat local file paths as portable.
- Existing documents, Quill Delta content, table embeds, images, autosave, page layout, comments, citations and revisions must remain compatible during future changes.
- Keep the app bilingual (Bangla and English) and preserve the Android-first workflow.

### Next Work
Continue with Serial 16 — complete References, Review and View features as one coherent change. Audit the full existing code first; retain working controls and do not repeat completed work. Run automatic GitHub Build and verify the APK artifact before reporting completion.
