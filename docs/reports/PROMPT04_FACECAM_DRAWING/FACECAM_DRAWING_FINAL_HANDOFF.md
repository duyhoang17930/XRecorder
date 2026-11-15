# Prompt04 final handoff — Facecam and Drawing

**Candidate:** `com.xrecorder.xrecorder` 0.1.0, debug APK SHA-256 `A128DBD7FB57A53C818A1D1CEAF95561E8BF68C6482DB8B8DE4C7F9EBE893DF0`<br>
**AVD:** Pixel_7 alias, `emulator-5554`, Android 17 / API 37.<br>
**Source:** branch `main`, HEAD `87d3c2534c8b201fb75aaccb26ead876c4ef75d8`; changes are uncommitted.<br>
**Full details:** [bug and fix report](FACECAM_DRAWING_BUGS_AND_FIXES.md) · [test matrix](FACECAM_DRAWING_TEST_MATRIX.md)

## Required status summary

ADB/AVD: **PASS** — online emulator-5554, Pixel_7 AVD alias, API 37<br>
FACECAM PERMISSIONS: **PARTIAL** — normal grant and later revoke exercised; deny/cancel/retry and active revoke not all completed<br>
FRONT/BACK CAMERA: **PASS** — virtual front/back scene change confirmed in MP4 291<br>
FACECAM DRAG/RESIZE: **PARTIAL** — menu lists Small/Normal/Large; candidate drag and all size pixel checks not rerun<br>
FACECAM EFFECTS: **PARTIAL** — AVD supports OFF only and hides unsupported effects; other effects not available to test<br>
FACECAM RECORDED PIXELS: **PASS** — Facecam region decoded in MP4s 272 and 279<br>
DRAWING STROKES: **PARTIAL** — responsive strokes exercised; broad speed/color/width matrix not repeated<br>
DRAWING COLORS/WIDTHS: **PARTIAL** — orange strokes pixel-confirmed; full palette and widths not repeated<br>
UNDO/REDO/ERASER/CLEAR: **PARTIAL** — source exposes Undo/Clear; no Redo/Eraser implementation; candidate post-Clear persistence is inconclusive<br>
DRAWING RECORDED PIXELS: **PASS** — two orange annotations visible in decoded MP4 279<br>
TOUCH PASS-THROUGH: **PARTIAL** — prior TASK10 evidence exists; not rerun for this candidate<br>
MULTI-OVERLAY INTEGRATION: **PARTIAL** — Facecam and Drawing coexist in MP4 279; full overlap and hit-test matrix is incomplete<br>
BACKGROUND/ROTATION: **PARTIAL** — background app was exercised; final-build rotation with overlays was not run<br>
CAMERA/DRAWING CLEANUP: **PARTIAL** — Stop finalizes; active camera revoke/retry and all rotation cleanup paths remain unverified<br>
PERFORMANCE: **PARTIAL** — no crash/ANR seen in bounded sessions; decoded cadence below configured 30 fps, no CPU/memory sampling<br>
FLOATING CONTROLS EXCLUDED FROM MP4: **FAIL / OPEN** — regular capture includes controls; FLAG_SECURE experiment replaced their region with black<br>
AUTOMATED TESTS: **PARTIAL** — full native suite 162/162 across 28 suites PASS and APK build PASS; Flutter widget/full-suite execution stalled<br>
EMULATOR QA: **PARTIAL**<br>
DATA PRESERVATION: **PASS** — installed in place, no data/media deletion; permissions and recording preferences restored<br>
PHYSICAL DEVICE: **NOT RUN**

ANDROID CASES: **4/20 PASS**<br>
REAL MP4 OUTPUTS VERIFIED: **4 candidate outputs** (plus one historical pre-fix output)<br>
FILES CHANGED: **13 logical project files** (excluding the two untouched owner screenshots)<br>
REMAINING ISSUES: Floating control exclusion needs a clean capture/composition solution; final orientation formula has no post-change rotated MP4; full permission, drawing, lifecycle, Flutter regression and physical-device cases remain open.

## Overlay composition contract

- Facecam included in recording? **YES**, confirmed in decoded AVD virtual-camera output.
- Drawing included in recording? **YES**, two annotation strokes confirmed in decoded output.
- Floating controls excluded? **NO**. Controls remain visible in ordinary MediaProjection recordings.
- Are pixels behind controls preserved? The ordinary video contains the surrounding screen but control UI covers its footprint. `FLAG_SECURE` hides the controls and creates a black rectangle, so the covered screen pixels are not preserved.
- Consistent after rotation? **NOT RUN** with the final orientation adjustment.

No black masking, private API, root access, capture bypass or control disabling was kept. Floating control exclusion remains an explicit release blocker; this handoff does not claim the feature set complete.

## Owner screenshot follow-up

The red rectangles in the owner-provided screenshot are annotations added to the screenshot, not app UI. Both requested UI defects are fixed and were visually checked on the AVD: the terminal Error footer now places label and message on one compact row with Help/dismiss actions; the floating control panel has wider inner padding so its controls no longer sit against the outer border.

## Repository and artifact state

- No commit or push was made. The 13 logical project files are seven source/test files, two TASK10 registers, three Prompt04 reports and one renamed physical-device handoff.
- Five QA videos with unique MediaStore IDs 271, 272, 279, 291 and 305 remain in the app gallery. Four candidate files were fully decoded; historical item 271 decoded with timestamp warnings.
- User screenshots `Screenshot 2026-11-15 151245.png` and `image.png` remain untouched.
- The physical-device follow-up list is `docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md` and contains only hardware/OEM checks.

**PROMPT04 FINAL: PARTIAL**

## PROMPT04A — FOCUSED QA CLOSURE

This continuation closes the Flutter test stall and adds a post-orientation-change MP4. It does not claim overall release readiness.

### Final status

ADB/AVD: **PASS** — emulator-5554, Pixel_7 AVD alias, Android 17/API 37, online; portrait state restored.<br>
FACECAM PERMISSIONS: **PARTIAL** — real Settings UI grant and idle revoke verified; full deny/cancel/retry and active revoke/retry remain incomplete.<br>
FRONT/BACK CAMERA: **PASS** — virtual front/back change independently confirmed in MP4 291.<br>
FACECAM SIZE/DRAG: **PARTIAL** — default placement recorded; all three sizes, drag/clamp and edge interaction not rerun.<br>
FACECAM ROTATION: **PARTIAL** — camera remains visible after rotation, but video remains fixed portrait 720×1280 and letterboxes the landscape screen; mirror/freshness over rotation are not fully proven.<br>
FACECAM OUTPUT PIXELS: **PASS** — decoded Facecam pixels in MP4s 382, 393 and 404; AVD virtual camera only.<br>
DRAWING STROKES: **PARTIAL** — orange stroke pixels in 393, but the rotated attempt only confirms a point, not a continuous stroke.<br>
DRAWING COLORS/WIDTHS: **PARTIAL** — orange default style confirmed; palette and width matrix not tested.<br>
DRAWING RECORDED PIXELS: **PASS** — orange strokes independently decoded in 393 before the invalid Clear tap.<br>
UNDO/CLEAR: **PARTIAL** — input taps missed the toolbar in the portrait run; no valid end-to-end Clear persistence result. Redo/Eraser are not implemented.<br>
TOUCH PASS-THROUGH: **PARTIAL** — no fresh verified underlying-app tap after drawing exits.<br>
MULTI-OVERLAY: **PASS** — Facecam and annotation pixels coexist in decoded MP4 393. Broader hit testing remains incomplete.<br>
CAMERA CLEANUP: **PARTIAL** — camera closed after Stop; active permission revoke, occupied camera, retry and every rotation path remain open.<br>
FACECAM EFFECTS: **PARTIAL** — the AVD only supports effect OFF.<br>
BACKGROUND/ROTATION: **PARTIAL** — launcher/notification use and rotation were observed, but rotated output is letterboxed and portrait return was not decoded.<br>
PERFORMANCE: **PARTIAL** — no crash/ANR observed; no CPU/RAM sampling; encoded cadence remains under 30 FPS.<br>
FLUTTER FULL SUITE: **PASS** — 557/557.<br>
NATIVE SUITE: **PASS** — 162/162 across 28 suites.<br>
AUTOMATED TESTS: **PASS** — focused/full Flutter, analysis, full native suite and diff check passed.<br>
SCREENSHOT REGRESSION: **PARTIAL** — PNG MediaStore ID 359 finalized, but captured the Launcher rather than the app page that opened the flow.<br>
REAL MP4 VERIFICATION: **PARTIAL** — three follow-up candidates fully decoded; 404 confirms rotated pixels and Facecam, but has portrait letterboxing and non-monotonic DTS warnings.<br>
EMULATOR QA: **PARTIAL** — 6/20 Android cases PASS; remaining cases and output limitations are listed in the matrix.<br>
CAMERA/DRAWING CLEANUP: **PARTIAL** — camera closed after Stop; rotated Drawing close/pass-through was not confirmed.<br>
DATA PRESERVATION: **PASS** — no app data/media deletion; test settings and permission state restored.<br>
PHYSICAL DEVICE: **NOT RUN**.

FLOATING CONTROLS EXCLUDED FROM MP4: **FAIL / OPEN** — normal MediaProjection records the ball/controls when shown; the previous secure-window approach creates black pixels and remains rejected.<br>
ANDROID F01–F20: **6/20 PASS**, 13 PARTIAL, 1 NOT RUN.<br>
REAL MP4S VERIFIED IN THIS FOLLOW-UP: **3** — MediaStore IDs 382, 393 and 404. Screenshot PNG ID 359 is a separate output.<br>
FILES CHANGED IN PROMPT04A: **4** — three Prompt04 reports and the single physical-device handoff; no source file changed.<br>
UNRESOLVED PRODUCT DEFECTS: clean Floating Ball exclusion; landscape video aspect/orientation adaptation; valid rotated Drawing gesture and Undo/Clear UI verification; permission retry and active revoke; screenshot source-screen parity; known Prompt01 audio/cadence issues.

### Flutter hang root cause and regression gates

- Focused Flutter command: flutter.bat --verbose test --no-pub --reporter expanded --timeout 30s test\recorder_ui_test.dart — exit 0, 4/4 passed.
- Full Flutter command: flutter.bat test --no-pub --reporter expanded --timeout 60s — exit 0, 557/557 passed. Log: build/prompt04a_qa_flutter_full.log.
- flutter.bat analyze --no-pub — exit 0, no issues. Dart formatting check, git diff --check, and full native Gradle tests also passed.
- Cause of the old stall: Flutter bootstrap could not access the SDK cache lockfile outside the writable workspace, then retried without showing its bootstrap error. No active lock owner or hanging test callback was found. With approved access to the existing SDK cache, the unchanged tests completed; no assertions or tests were removed.
- Screenshot CTA saved PNG ID 359 (1080×2400, 1,391,134 bytes), but its decoded pixels show Android Launcher after consent; report Screenshot Regression PARTIAL. Historical Prompt02 15/16 remains separate.

### Rotated candidate 404

content://media/external/video/media/404 (Recording_1794738804965.mp4) is finalized and preserved. H.264, 720×1280, 1,399 frames, 224.783 s container duration; complete FFmpeg decode exited 0 with repeated non-monotonic DTS warnings. Decoded landscape frames show screen pixels and Facecam after rotation, but the landscape screen sits letterboxed in the fixed portrait track. The recorded Facecam is an emulator virtual image. The output proves capture continued; it does not pass dynamic orientation, 30 FPS cadence, or continuous rotated drawing.

### Owner screenshot follow-up — reconfirmed

The red rectangles are owner-drawn marks. The AVD image build/prompt04_qa/prompt04a_home2.png reconfirms the compact one-row Error footer; build/prompt04_qa/prompt04a_controls_enabled.png reconfirms inset panel controls. These two requested UI corrections were already in the Prompt04 candidate before this closure. No additional source edits were necessary.

Host free space at closure was C: **14.61 GiB** and D: **18.34 GiB**. Camera and overlay permissions were returned to denied via Android Settings UI; audio source Mixed Stream, Facecam off, 3-second countdown and portrait/auto-rotation were restored. The app stayed installed with its data, drafts, recovery inputs and previous media intact. All new media remain in MediaStore.

**PROMPT04A FINAL: PARTIAL** — Flutter and native gates pass, Facecam and Drawing have decoded output evidence, but rotation/output parity and valid Drawing clear/gesture verification are incomplete. Floating control exclusion remains an independent release blocker.<br>
**PROMPT04 FINAL: PARTIAL**
