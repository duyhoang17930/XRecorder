# Prompt07 — Photo Editor test matrix

Current Android scenarios were blocked by the preflight storage gate. Scenario status combines available host/prior proof with the current block; prior Task10 output evidence is identified separately and does not count as current-Prompt Android execution.

| ID | Scenario | This run | Prior direct evidence / remaining |
|---|---|---|---|
| P01 | Library entry to Photo Editor | BLOCKED | Source/routes and host interaction coverage; not reopened on current APK |
| P02 | Preview, orientation and image identity | BLOCKED | Task10 preview/save parity evidence; current EXIF/device open not repeated |
| P03 | Crop and aspect ratios | BLOCKED | Synthetic raster crop test passes; real Android presets/exports remain |
| P04 | Rotate and flip | BLOCKED | Synthetic raster mapping tests pass; fresh saved-copy geometry not produced |
| P05 | Resize | BLOCKED | Output max-edge selection exists; no separate resize control; native output not repeated |
| P06 | Brightness/contrast | NOT IMPLEMENTED | No adjustment controls exposed |
| P07 | Filters/effects | NOT IMPLEMENTED | No filter controls exposed |
| P08 | Text placement | BLOCKED | Historical saved text output and preview parity proof; current APK not run |
| P09 | Stickers | BLOCKED | Historical Star/Heart pixels and Undo/Redo proof; current APK not run |
| P10 | Drawing and eraser | PARTIAL | Pen/shape history and new Eraser swipe geometry pass on host; Android gesture blocked |
| P11 | Layer order and transforms | BLOCKED | Painter/source logic audited; full device workflow not run |
| P12 | Mixed Undo/Redo | PARTIAL | New swipe Eraser Undo/Redo widget proof plus existing host coverage; device not run |
| P13 | Open another image/no stale state | BLOCKED | Lifecycle code audited; device session switch not run |
| P14 | PNG export and full decode | BLOCKED | Two historical PNG outputs were fully decoded; no new PNG this run |
| P15 | JPEG export and full decode | BLOCKED | One historical JPEG output fully decoded; no new JPEG this run |
| P16 | Save copy and preserve original | PARTIAL | Historical source SHA checks plus new synthetic source-pixel preservation; current Android save blocked |
| P17 | Library refresh | BLOCKED | Refresh call is present; current MediaStore row/navigation not exercised |
| P18 | Invalid and large images | BLOCKED | 2048-edge capped software preview and error paths audited; device/OOM cases not run |
| P19 | UI, touch targets and accessibility | PARTIAL | Flutter interaction/layout suite passes; no current-device accessibility or physical-touch pass |
| P20 | Combined edited-image workflow | BLOCKED | Historical real workflow exists; current APK end-to-end flow not run |

**Android cases passed this continuation: 0/20.** Photo acceptance remains independent of Video Editor results.

## Host and build checks

| Check | Result |
|---|---|
| Photo processing suite | PASS — 8/8, including new sparse-stroke and source-pixel test |
| Editor HCI widget suite | PASS — 52/52, including new swipe/Undo/Redo regression |
| Full Flutter suite, final run | PASS — 567/567; focused files are subsets and not added again |
| Flutter analyzer | PASS — no issues |
| Native Android JVM unit tests | PASS — 162/162; supports native compilation, not photo Android runtime |
| Dart format / `git diff --check` | PASS |
| Debug APK build | PASS — 120,023,451-byte x86_64 build, not installed |

Historical actual outputs: two PNG copies and one JPEG copy decoded in Task10; the parity-fixed PNG included tested Star/Heart color pixels, Undo/Redo and exact original-source hash. Current-Prompt real PNG/JPEG outputs: zero. Evidence: [Task10 test evidence](../TASK10_20261113/TASK10_TEST_EVIDENCE.md), [bug register](../TASK10_20261113/TASK10_BUG_REGISTER.md).

## PROMPT 06+07A — Focused Android QA (2026-11-16)

The prior matrix records its original storage-blocked run. This appended matrix records the current focused Photo Editor run and keeps its output evidence separate from historical Task10 results. The Photo Editor source was not changed after the PNG/JPEG run; the final rebuilt APK only changes Video Editor presentation.

| ID | Focused scenario | Result | Evidence / limit |
|---|---|---|---|
| P01 | Library → Photo Editor | PASS | Existing PNG opened from the Photo Library. |
| P02 | Preview, identity and orientation | PASS | Correct 1080×2400 source was previewed; source URI/hash checked. |
| P03 | Crop | PARTIAL | Crop was visible in the saved PNG and output decoded; exact coordinate-to-pixel oracle was not run. |
| P04 | Rotate and flip | PARTIAL | Rotate 90° and horizontal flip were applied; output dimensions decoded, but no exact pixel mapping comparison. |
| P05 | Resize | PARTIAL | Existing max-edge export setting produced bounded output; no separate resize control is claimed. |
| P06 | Brightness/contrast | NOT IMPLEMENTED | No such controls are exposed. |
| P07 | Filters/effects | NOT IMPLEMENTED | No filter controls are exposed. |
| P08 | Text | NOT RUN | Text entry was not exercised. |
| P09 | Stickers | PASS | Star sticker was positioned and appears in the decoded PNG copy. |
| P10 | Drawing and Eraser | PASS | Multiple marks were crossed in one continuous Eraser swipe; all disappeared. |
| P11 | Layer order/transforms | PARTIAL | Sticker plus image transforms were included in PNG; multi-layer ordering was not tested. |
| P12 | Undo/Redo | PASS | One Eraser swipe was one history entry; Undo restored crossed marks and Redo removed them again. |
| P13 | Open another image / stale state | NOT RUN | A clean editor session reopened the source; switching to a different image was not tested. |
| P14 | PNG export and full decode | PASS | New PNG fully decoded at 480×179; expected star/source colors were present. |
| P15 | JPEG export and full decode | PASS | New JPEG fully decoded at 216×480. |
| P16 | Save copy/source preservation | PASS | Distinct PNG/JPEG MediaStore items; original source SHA-256 unchanged. |
| P17 | Library refresh | PASS | Library showed both new copies; 26 photo items total (24 existing + 2 outputs). |
| P18 | Invalid/large images | NOT RUN | No corrupt or memory-stress input was opened. |
| P19 | UI/gestures/accessibility | PARTIAL | Real Eraser gesture and editor navigation were exercised; no TalkBack/large-image benchmark. |
| P20 | Combined edited-image workflow | PASS | Preview, annotation, transform, PNG/JPEG Save copy and Library refresh completed. |

**Focused Android PASS: 10/20; PARTIAL: 5/20; NOT RUN: 3/20; NOT IMPLEMENTED: 2/20.**

### Real output and preservation evidence

- AVD: `Pixel_7`, `emulator-5554`, `sdk_gphone16k_x86_64`, Android 17/API 37. Final installed APK SHA-256: `4FCE6533182FE1792CF7B42D0C660E2C74EA60A3F95378A85236C5F2569CA794` (installed hash matches workspace build).
- Reused original: `Screenshot_1794758287113.png`, MediaStore row 467, 1080×2400, 1,391,956 bytes; SHA-256 `903E81567E321B6DDC6B720627A73DC1E2BA71099E8A34168B385516E22C6F9C`.
- New PNG: row 541, `Edited_1794790713979.png`, 94,691 bytes, `image/png`, 480×179. Host image decoder read all pixels; 1,938 saturated-red pixels were found, consistent with the intended star/source palette.
- New JPEG: row 542, `Edited_1794790917840.jpg`, 23,898 bytes, `image/jpeg`, 216×480. Host image decoder read all pixels and confirmed JPEG signature/dimensions.
- Both files are new copies in `/Pictures/XRecorder/`; the original photo bytes/hash remained unchanged. Final library displayed both outputs. No additional photo output was created during the Video UI follow-up.
- Eraser screenshots: `prompt07a_photo_marks.png`, `prompt07a_photo_eraser_swipe.png`, `prompt07a_photo_eraser_undo.png`, `prompt07a_photo_eraser_redo.png`. Output files and captures are under `build/verification/prompt06_20261116_005147/`.

The final Android verdict remains **PARTIAL** because text creation, stale-state switching, invalid/large-image handling, exact transform pixel mapping and other unimplemented adjustments/effects were not accepted by this focused run.
