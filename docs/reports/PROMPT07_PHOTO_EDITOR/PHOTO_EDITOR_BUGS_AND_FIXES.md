# Prompt07 — Photo Editor bugs and fixes

**Assessment:** PARTIAL. A reachable Eraser defect was reproduced and fixed. Host tests now verify a swipe erases every crossed mark, catches a sparse stroke between stored vertices, and participates in Undo/Redo. Android decode/MediaStore output acceptance remains blocked by the preserved AVD's 558 MiB free storage.

## Capability inventory

| Area | Present/reachable | Host coverage | Prior actual output evidence | Current gap |
|---|---|---|---|---|
| Entry and preview | Library/preview to Photo Tools; content URI decode; capped 2048-edge preview | Entry/layout and decode-path tests | Task10 PNG/JPEG and parity-fix outputs | Current APK URI/EXIF/device handling not rerun |
| Crop/transform | Free horizontal/vertical crop, 90° turns, horizontal/vertical flip | Synthetic crop/rotation/flip raster test | Prior saved-copy output checks | No fresh Android output oracle |
| Resize/export | Max-edge output choice 480/720/1080/2048; quality control | Output renderer tests | Prior 922x2048 PNG/JPEG | No separate aspect-ratio resize editor; current MediaStore output not run |
| Adjustments/filters | Not implemented | N/A | None claimed | Not exposed as functional controls |
| Annotations | Pen, Eraser, rectangle, circle, arrow, text, Star/Heart sticker and ink/width controls | Photo painter and widget tests | Task10 pen, shape, text, Star/Heart output | Gesture cases beyond the audited host coverage need device validation |
| Undo/Redo/state | Snapshot history limited to 50; crop/transform/marks; no photo drafts | Mixed editor HCI and photo processing tests | Task10 Undo/Redo output | Current device interactions and open-another-image lifecycle not rerun |
| Save copy | PNG/JPEG, quality, max edge, new URI and Library refresh | Host raster path; native save path source audit | Prior full PNG/JPEG decode, source hash and parity checks | Current Android encode/publication/retry not run |

## Reproduced defect — PHOTO-ERASER-SWIPE

**Before:** the UI checked only the pan-start point against stored vertices, removed at most one whole annotation, and had no eraser `onPanUpdate` behavior. A swipe across two sparse pen strokes left both marks in place. The new widget regression failed against the original implementation.

**Cause:** hit testing sampled annotation vertices only and treated the eraser as a point tap. Sparse line segments and marks crossed later in the swipe were never considered.

**Fix:** add `erasePhotoMarks`, mapping normalized mark coordinates into source pixels and measuring swipe-to-stroke segment distance. Rectangle/circle outlines, arrow shaft/head and text/sticker bounds are hit tested. One undo snapshot is captured on the first removed mark in a swipe; subsequent removals update the canvas without adding redundant history entries. The existing whole-mark erase behavior is retained.

**Evidence:** widget test erases two separate strokes with one swipe, Undo restores both and Redo removes both. Raster test verifies the negative-control swipe leaves the mark, the crossing sweep detects a pen segment between its endpoints, the rendered copy shows the underlying source pixels, and source pixels stay unchanged.

## Files changed for the fix

- `lib/features/media/photo_tools_screen.dart`
- `test/editor_hci_test.dart`
- `test/photo_tools_test.dart`

No new dependency, native code, localization key or destructive source-image operation was added.

## Other defects

No crop/rotate/flip or save-publication defect was reproduced in this continuation. Earlier preview/output parity and missing sticker functionality were fixed and independently checked in Task10; their historical conclusions remain as recorded there.

## Performance and preservation

Erasing operates on annotation geometry rather than decoded image pixels and stores one existing lightweight mark snapshot per swipe. No large-image benchmark was possible here. The source image is not modified; the synthetic raster test compares its source pixels before/after. No user photo or saved copy was opened, overwritten, or deleted in this continuation.

## PROMPT 06+07A — Focused Android evidence

No new Photo Editor defect was reproduced. The previously fixed Eraser behavior passed on the AVD: several marks were added, one continuous swipe crossed multiple marks, Undo restored the crossed marks as one history action, and Redo removed them again. The source image remained byte-identical.

One PNG and one JPEG copy were created from the existing 1080×2400 PNG input. Both fully decoded on the host; the PNG contained the expected star/source palette and the JPEG had the expected dimensions. Library refresh showed both distinct new MediaStore items. Exact crop/rotation/flip pixel-coordinate equivalence, text entry, invalid files and large-image stress remain unverified.

The final APK UI polish only touched Video Editor files. No Photo Editor app source or localized resource changed in this continuation. New outputs, captures and decoder evidence are under `build/verification/prompt06_20261116_005147/`.
