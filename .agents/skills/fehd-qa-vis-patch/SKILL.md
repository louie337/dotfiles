---
name: fehd-qa-vis-patch
description: Patch FEHD QA visual-inspection PDFs by replacing specified blank or grey camera-photo cells with a user-selected reference camera image while preserving the original PDF styling, typography, and layout.
---

# FEHD QA VIS PDF Patch

Use this skill when the user asks to repair grey, blank, or missing camera photos in an FEHD QA visual-inspection PDF.

## Inputs and placeholders

Use only values the user has provided. When the user supplies a concrete value, represent it as:

- Input PDF: `{INPUT_PDF}`
- Replacement image source: `{SOURCE_PERIOD_TIME}` and `{SOURCE_CAMERA}`
- Cells to replace: `{TARGET_PERIOD_TIME_RANGE}` and `{TARGET_CAMERA}`
- Output PDF: `{OUTPUT_PDF}`

Do not invent a period, timestamp, camera, target range, filename, or placeholder specification. If the user identifies a starting timestamp and camera but does not specify a replacement timestamp, inspect the document for candidates and automatically select the nearest valid photo, preferring a later timestamp; if no later valid photo exists, use the nearest earlier valid photo. Ask for confirmation only when the source/camera mapping remains ambiguous.

## Required workflow

1. Locate `{INPUT_PDF}` and inspect its page count, text, and embedded-image inventory with `pdfinfo`, `pdftotext -layout`, and `pdfimages -list`.
2. Map timestamps to pages and image order. Never assume that the third or fifth image is the requested source without checking the rendered page visually; camera images alternate by row, and pages may begin or end mid-sequence.
3. Extract the exact `{SOURCE_PERIOD_TIME}` image from `{SOURCE_CAMERA}`. Render the relevant page and inspect the image together with its row label to confirm the timestamp and camera before patching. When the user only gives a target start timestamp, select the closest valid source photo from the same camera, preferring the next later timestamp.
4. Identify every target cell in `{TARGET_PERIOD_TIME_RANGE}` for `{TARGET_CAMERA}` and confirm that those cells are black, grey, blank, or otherwise invalid placeholders. Detect invalid cells by combining the rendered page with the embedded-image inventory: compare dimensions, color/brightness characteristics, and visible placeholder markers such as `可见光`; do not rely on image order alone. A run beginning at a user-specified timestamp extends through the contiguous affected cells until the first valid cell or the end of the requested period/report, as appropriate.
5. Preserve the original document styling. Prefer replacing only the affected embedded image streams or applying a vector/PDF overlay. Do not rasterize whole pages, rebuild the report from screenshots, or otherwise re-render the original text; those approaches change font weight and typography.
6. If replacing image streams in place, preserve PDF integrity: use the original source PDF, replace only the intended image data, keep stream lengths/offsets valid, and rewrite the PDF with a PDF tool if needed. If a replacement stream must be length-preserving, recompress the source image only as much as necessary and pad the stream safely without changing its declared dimensions.
7. Write the result to `{OUTPUT_PDF}` without overwriting `{INPUT_PDF}` unless the user explicitly requests that.
8. Validate the output with `pdfinfo`, render the affected pages, and visually confirm that every target cell uses the exact selected source image, no grey placeholder remains in the requested range, the page count is unchanged, and the surrounding labels, counts, borders, font weight, and layout match the original.

## Safety and reporting

- Do not modify unrelated camera photos or report text.
- Do not substitute a nearby timestamp merely because its image looks similar when the user specified an exact source timestamp.
- If the user did not specify a source timestamp, use the nearest valid same-camera photo, preferring a later timestamp and falling back to the nearest earlier timestamp only when necessary.
- If the source image mapping or the extent of the affected run is uncertain, stop and ask; correctness of the selected timestamp/camera takes priority over completing the patch.
- Report the exact source timestamp/camera used, target range/camera patched, output filename, and validation performed.
