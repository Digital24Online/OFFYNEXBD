# OFFYNEX Slides — implementation and completion specification

## Current implemented foundation
- Local presentation records and autosave through the shared workspace record model.
- Text-per-slide representation, a 16:9 read-only slide preview with navigation, and PDF export.
- This is not yet a full presentation editor and must not be advertised as one.

## Remaining implementation — complete as one integrated presentation workflow
### Presentation model and editor
- Replace newline-only slide text with a versioned presentation document model: slides, layouts, theme, masters, elements, z-order and speaker notes.
- Add a real canvas editor with text boxes, images, shapes, tables, charts, selection, move/resize/rotate, alignment guides, grouping and layer ordering.
- Add slide add/duplicate/delete/reorder, thumbnails, section grouping and undo/redo.
- Add layout templates, theme colors/fonts, background, master slide and reusable design assets.

### Playback and interchange
- Add presenter/slideshow mode, keyboard/touch navigation, notes and screen-fit controls.
- Add transitions and animations with reduced-motion/accessibility controls.
- Implement PPTX and ODP import/export with explicit unsupported-feature reporting and round-trip tests.
- Preserve Bengali fonts, mixed-script shaping, images, charts, slide size and notes through PDF/PPTX export.

### Acceptance gates
- Editing, save/reopen, reorder, duplicate, theme/layout, asset positioning and slideshow tests.
- PPTX/ODP fixtures round-trip through PowerPoint/LibreOffice and preserve Bengali visual output.
- Analyze, full tests and signed Android build pass; phone/tablet/desktop canvas and slideshow checks recorded.
