# OFFYNEXBD Global Product & Interface Design System

Status: Master design specification  
Scope: Android, iOS, Windows and macOS; phone-first with tablet/desktop adaptations.  
Rule: Every module uses one coherent OFFYNEXBD design language. No isolated, inconsistent screens or decorative redesigns that make controls harder to find.

## 1. International product review

This specification is informed by official product documentation and feature pages, not by copying another product's branding:

- Microsoft 365 / Word / Excel / PowerPoint: ribbon-based editing concepts, contextual tools, page/layout controls, track/review, spreadsheet PivotTables and charts, slide presenter tools. Mobile capabilities differ by device and subscription. https://support.microsoft.com/en-us/office/foundations-experiences/microsoft-365-mobile-apps
- WPS Office: one integrated suite for documents, spreadsheets, presentations, PDF, conversion, scanning/OCR, AI and cloud workflows. https://www.wps.com/feature/ and https://www.wps.com/office/ios/
- Adobe Acrobat: PDF reading, search, comments, annotations, forms, signatures, editing, conversion, page organization, compression and protection; feature availability differs by plan. https://helpx.adobe.com/acrobat/mobile/get-started/faqs.html
- CamScanner: capture, edge detection, auto crop/enhancement, OCR, PDF creation, cloud sync and sharing. https://www.camscanner.com/
- Notion: connected docs, databases, forms, mobile capture and AI; mobile/desktop capabilities differ, so OFFYNEXBD must make phone actions explicit rather than hide them behind desktop-only patterns. https://www.notion.com/product/features and https://www.notion.com/help/notion-for-mobile

Product decisions: adopt familiar interaction patterns, not competitor logos, colors, layouts or proprietary assets. Never advertise an option as functional until the underlying operation exists and has tests. Clearly label unavailable integrations and plan-dependent/online features.

## 2. Global visual language

### Brand and surfaces
- Brand identity: OFFYNEXBD wordmark and selected icon remain unchanged.
- Primary: deep navy #142C55; action blue #246BCE; teal #168C91.
- Canvas: #F4F7FB; surface: #FFFFFF; primary text: #172B4D; secondary text: #718096; border: #E5EAF2.
- Semantic status colors are reserved for success, warning, error and information. Do not use module accent colors as status indicators.
- Each module may have one restrained accent for its icon, active marker and small highlights only. Toolbars, surfaces, typography, buttons, fields and spacing remain shared.
- Light theme is the baseline. Dark theme must use semantic tokens, not inverted hard-coded colors.

### Layout, spacing and shape
- Base spacing unit: 4 dp. Standard spacing steps: 4, 8, 12, 16, 20, 24, 32.
- Standard control height: 44–48 dp; touch target minimum: 48 dp where practical.
- Surface radii: 8 dp compact controls, 12 dp fields/buttons, 16 dp panels, 20 dp major cards/dialogs.
- Use thin neutral borders and restrained elevation. Avoid excessive gradients, shadows, oversized rounded cards, decorative circles, and nested cards.
- Keep a consistent content grid, page margins and alignment across modules.
- On phones, use a single primary content column, scrollable tool panels and bottom-reachable primary actions. On tablets/desktops, expand to navigation rail/sidebar, inspector panels and multi-pane layouts without changing terminology.

### Typography and language
- Use a consistent type scale: 12 caption, 14 body-small, 16 body, 18 section title, 22 page title, 28 display.
- Use font weights consistently: 400 body, 500 emphasis, 600 control/section, 700 heading.
- Bangla must use a tested Unicode font with correct যুক্তাক্ষর, কার, ফলা, punctuation and line-height. Never force Latin-only font into Bangla document output.
- UI labels support Bangla and English with equal layout quality. Allow wrapping; never clip or truncate essential action labels.
- Document fonts and app UI fonts are separate concerns. UI font fallback must not silently change a user's document font.

### Navigation and interaction
- Home dashboard groups the ten tools in a consistent grid/list; search, recent files and create actions use predictable placement.
- Each editor has: top app bar (back/file name/save state/more), contextual workspace toolbar, main work canvas, and a compact bottom action area where appropriate.
- Use familiar names and icons; every icon-only control needs a tooltip/accessible label.
- Contextual tools appear only for the selected object/element, but the user must be able to discover them through a stable menu.
- No hidden horizontal-only control strips on phone. Wrap or scroll tool groups with visible affordances.
- Confirm destructive actions; support undo/redo where editing semantics permit.
- Loading, empty, error, offline, permission-denied and success states are designed for every workflow.
- Keep unsaved changes visible; autosave status must distinguish Saving, Saved, Offline and Failed.

## 3. Shared screen templates

1. Dashboard: branded header, search/recent access, clear create-new actions, module grid, cloud/sync status and app info. No oversized promotional hero that pushes work tools off-screen.
2. Editor: top file bar, module ribbon/toolbar, content canvas, contextual selection tools, bottom status/zoom. The canvas receives the largest available area.
3. Library: search, sort, filter, list/grid toggle, folders, file metadata, multi-select and safe bulk actions.
4. Settings: grouped settings, current value visible, short explanation, reset/default action and confirmation for destructive changes.
5. Inspector/dialog: compact title and close action, scrollable content, clear primary/secondary actions; must fit 360×640 dp without overflow.

## 4. Module-by-module option and screen blueprint

### Writer
- Home/library: New blank document, templates, open/import, recent, pinned, search, sort, folders, rename, duplicate, move, export/share, delete/recover.
- File: New, Open, Save, Save As, AutoSave status, Version History, Export DOCX/ODT/PDF/TXT, Print, Print Preview, Document Info, Protect.
- Home: font family, numeric size, increase/decrease size, bold/italic/underline/strikethrough, text/highlight color, clear formatting, paragraph styles, alignment, line/paragraph spacing, indent, bullets, numbering, borders.
- Insert: page/section break, table, image/camera, link, shape, text box, header/footer, page number, date/time, symbol, equation, footnote/endnote.
- Layout: page size, orientation, margins, columns, page color/border, line numbers, hyphenation, paragraph spacing.
- References: table of contents, footnotes, citations/bibliography, captions, cross-references, index.
- Review: spelling/grammar, comments, track changes, accept/reject, compare, word count, read aloud.
- View: page/continuous/web view, navigation pane, ruler, zoom slider/fit page/fit width, focus mode.
- Table contextual tools: select cell/row/column/table, insert/delete rows/columns, merge/split, distribute, cell size, alignment, text direction, borders, shading, repeat header, convert text/table.
- Phone layout: full-page preview and zoom must be reachable without hiding editing controls; ribbon categories remain stable and scrollable.

### Sheets
- Workbook: create/open/import XLSX/CSV, sheet tabs, add/rename/duplicate/move/hide/protect/delete, undo/redo, save/export.
- Home: font, size, bold/italic/underline, fill/text/border colors, alignment, wrap, merge, number formats, decimal places, styles.
- Insert: rows/columns/cells, table, chart, image, link, checkbox, pivot table.
- Formulas: function browser/search, formula bar, named ranges, calculation options, error inspection.
- Data: sort, filter, validation, remove duplicates, text-to-columns, subtotal, group/outline, import/refresh.
- Review/View: comments, protect sheet/workbook, freeze panes, gridlines, zoom, formula view, find/replace, selection/navigation.
- Charts: type, data range, title, legend, axes, labels, style, accessibility description.
- Large sheets must use virtualization and explicit safe resource limits; never claim Excel's maximum grid unless implemented and load-tested.

### Slides
- Presentation library: create blank/from template/import PPTX, duplicate, rename, export PDF/PPTX, present, share.
- Slide navigator: thumbnails, reorder, duplicate, hide, delete, sections.
- Insert: text, image/camera, shape, table, chart, audio/video where supported, icons, links.
- Design: themes, layout, background, size, variants, alignment guides.
- Transitions/Animations: effect, duration, order and preview; only show effects actually supported by renderer/exporter.
- Present: full screen, presenter notes, timer, pointer/ink, next/previous, audience view where supported.
- Provide a consistent slide canvas and inspector; do not imitate desktop ribbon at a scale that becomes unusable on a phone.

### PDF
- Library: open, recent, search, sort, folders, import, create, share, rename, duplicate, delete.
- View: page thumbnails, continuous/single page, fit width/page, zoom, search, bookmarks, outline, rotate view.
- Annotate: highlight, underline, strikeout, note, freehand, shape, stamp, attachment.
- Edit: text/image edit, add text/image, redact, links, headers/footers, page labels—only when actual PDF writing engine supports it.
- Organize: insert, extract, reorder, rotate, delete, replace, merge, split.
- Convert/OCR: PDF↔DOCX/images/text, OCR language selection, searchable text, review OCR result.
- Protect/Sign: password, permissions, certificate/signature, fill/sign forms, redact.
- Optimize: compress, flatten, repair, metadata, accessibility checks.
- Distinguish read-only, annotation and true content editing. Never show disabled edit controls as completed features.

### Fonts
- Font library, installed/available/imported tabs, search, category, language/script filter, preview, sample paragraph, size/weight/style.
- Import TTF/OTF/WOFF only where supported; validate file, family metadata, license and duplicates.
- Activate/deactivate, favorite, remove, restore defaults, document font embedding/export status.
- Bangla preview must include যুক্তাক্ষর, কার, ফলা, রেফ, য-ফলা and punctuation test strings.
- Never imply system-wide font installation when only in-app document use is supported.

### AI Assistant
- Chat, new conversation, history, search, rename, delete/export, model/service status, language, tone and privacy controls.
- Actions: draft, rewrite, proofread, summarize, translate, explain, extract, outline, formula help, slide outline, PDF Q&A.
- Context controls: current selection/document, attached file, selected pages/sheet/range; always show what content is being sent.
- Results: preview, insert/replace/copy, compare changes, regenerate, citations/source references where available.
- Clear online/offline and quota states. Never fabricate AI answers or claim service availability without configured backend credentials.

### Cloud
- Account/profile, storage usage, upload/download, folders, search, sort/filter, sync status, conflict resolution, version history, trash/restore, sharing permissions and device sessions.
- Show offline queue, retry and last successful sync. Local-only storage must not be labelled cloud sync.
- Security: sign-in state, encryption/backup explanation, access/revoke, sign-out, delete account/data workflow when backend supports it.

### Forms
- Builder: title/description, sections, question types (short/long text, number, email, phone, date, time, single/multiple choice, dropdown, rating, file upload where backend exists), required, validation, options, branching/logic, preview.
- Publish/share: link, QR, access window, audience and response limits only when server supports them.
- Responses: list, search, filter, detail, edit/delete, export CSV/XLSX/PDF, analytics, duplicate/empty question checks.
- Draft, published, closed states must be visible. Local-only forms must be labelled local and not pretend to collect remote responses.

### Scan
- Capture camera/gallery, document/ID/book modes, auto/manual shutter, edge detection, crop/perspective correction, rotate, reorder, retake.
- Enhancement: original, color, grayscale, B&W, contrast, brightness, shadow/glare cleanup.
- OCR: language, searchable PDF, editable text, review/correct recognized text, preserve original scan.
- Output: multipage PDF/JPEG, filename, destination, share, print, save, reopen.
- Camera permission, low light, no edges, blurry capture, OCR failure and storage failure states all need recovery actions.

### Database
- Workspace/table list, create/import/export, schema editor, field types (text, long text, number, date/time, boolean, choice, relation, attachment when supported), required/default/unique constraints.
- Grid and record-detail views, add/edit/delete, sort/filter/group, search, column hide/reorder/resize, saved views.
- Relations, lookups, formulas, validation, indexes, audit/version history and role-based permissions only when implemented.
- CSV import/export must preserve duplicate labels, empty values and type information. Destructive schema edits must preview affected data and allow cancel/backup.

## 5. Responsive behavior and quality gates

- 360×640 dp phone: no RenderFlex overflow; every primary action reachable; no essential clipped labels; keyboard does not cover save/submit.
- Phone landscape: preserve canvas, allow scrollable contextual tools; do not force desktop density.
- Tablet: navigation rail + canvas + optional inspector.
- Desktop: sidebar, ribbon/toolbar, multi-pane inspector, keyboard shortcuts, window resizing.
- Accessibility: contrast target WCAG AA, scalable text, screen-reader labels, focus order, keyboard navigation, reduced motion.
- Localization: test Bangla and English separately at narrow widths, including long labels and numeric values.
- Performance: large file loading, virtualized grids, image memory, cancellation and background progress.
- Data safety: autosave, recovery, round-trip import/export tests, corruption handling and non-destructive failure paths.

## 6. Design acceptance checklist

A module is not design-complete until:
- It uses shared OFFYNEXBD tokens and screen templates.
- Its full option inventory is mapped to real actions and contextual states.
- Phone/tablet/desktop layouts have been reviewed at representative sizes.
- Bangla and English layouts pass overflow and readability checks.
- Loading/empty/error/offline/success/destructive states are present.
- Every visible control is functional or clearly marked as unavailable/coming later.
- Accessibility and touch-target checks pass.
- Automated widget tests and import/export/data-preservation tests pass.
- Screenshots are reviewed against this specification before release.

Non-negotiable: Do not ship a visual-only button for an unfinished feature. Do not call a placeholder a completed editor, cloud service, AI integration or PDF editor.
