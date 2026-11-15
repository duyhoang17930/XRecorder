# Prompt04 — Facecam and Drawing test matrix

## Environment and candidate identity

- ADB device: `emulator-5554`, online; Pixel_7 AVD alias, Android 17 / API 37, virtual x86_64 device (`sdk_gphone16k_x86_64`). This is emulator camera evidence, not optical camera evidence.
- Installed app: `com.xrecorder.xrecorder`, version 0.1.0, debug APK SHA-256 `A128DBD7FB57A53C818A1D1CEAF95561E8BF68C6482DB8B8DE4C7F9EBE893DF0`. Installed in place with `adb install -r`; no app data was cleared.
- Final orientation formula changes are covered by native tests and the final APK build. The MP4s listed below were recorded before that last formula adjustment; no post-adjustment camera clip was made.
- All candidate media were finalized under unique MediaStore IDs and fully decoded with FFmpeg. The separate historical output 271 also decoded but has timestamp warnings.

## F01–F20

| ID | Result | Evidence / limit |
|---|---|---|
| F01 Camera permission denied, granted and retried | PARTIAL | Camera was granted through normal Android UI, then revoked through Settings after testing. A full cancel/deny/retry sequence was not completed. Declining MediaProjection consent displayed the compact error footer. |
| F02 Facecam opens with emulator camera frames | PASS | Virtual camera image is visible in decoded MP4 272 and combined output 279. The virtual front feed is mostly static, so changing-frame freshness is not established by 272 alone. |
| F03 Front/back camera switching | PASS | MP4 291 changes from the front virtual green scene to a distinct back virtual room/chessboard scene after switching. Hardware-camera quality is not inferred. |
| F04 Small/medium/large and drag | PARTIAL | The camera menu exposed Small, Normal, Large and None. This candidate run did not re-verify all sizes and drag/clamp behavior; TASK10 history is not counted as a new pass. |
| F05 Orientation and mirroring | PARTIAL | Final sensor/facing formula has 14 focused geometry tests and official Camera2 formula alignment. No rotated final-build preview or MP4 was captured. |
| F06 Effects and unsupported cases | PARTIAL | AVD reports only CONTROL_EFFECT_MODE_OFF; unsupported effects are omitted. Other effects cannot be evaluated on this virtual camera. |
| F07 Disable/revoke/Stop cleanup | PARTIAL | Stop finalizes output and final app state has camera permission denied. Active camera revocation and retry while recording were not exercised end to end. |
| F08 Drawing over another app | PARTIAL | Drawing and screen controls were exercised during recording in 3HRecorder. An annotation session over a separate app was not captured in this candidate. |
| F09 Pen colors, widths and continuous strokes | PARTIAL | Two orange strokes are visible in output 279. All palette colors and stroke widths were not repeated. |
| F10 Undo/Redo/Eraser/Clear state | PARTIAL | Current reachable actions are Undo and Clear; this source has no Redo or Eraser action. Clear was exercised, but the candidate frame sequence did not provide conclusive post-clear persistence evidence. |
| F11 Existing shapes and styles | NOT RUN | Source supports freehand strokes, color and width; no shape tool is currently exposed. |
| F12 Touch pass-through after closing Drawing | PARTIAL | Historical TASK10 evidence exists, but a fresh candidate outside-app pass-through check was not recorded. |
| F13 Drawing pixels in recorded output | PASS | Two orange annotation strokes were independently seen in decoded MP4 279; screen content remained visible around them. |
| F14 Facecam pixels in recorded output | PASS | Facecam region was independently seen in decoded MP4s 272 and 279. The virtual source is static and does not represent real-camera quality. |
| F15 Facecam and Drawing together | PARTIAL | Both appear in decoded output 279, but exact overlap, active drawing over a camera view, and all rotation/layer combinations were not exhausted. |
| F16 Floating Ball integration and overlap | PARTIAL | Expanded controls and collapsed ball were exercised with Facecam/Drawing and remain operable. Normal output contains those controls, which violates the exclusion requirement. |
| F17 Pause/Resume/Stop with overlays | PARTIAL | Stop finalized the sessions through native/notification controls. A complete confirmed pause-resume cycle with both overlays was not recorded. |
| F18 Background/foreground and rotation | PARTIAL | The app was moved to Android Settings during an overlay recording experiment. Rotation with active Facecam and Drawing was not tested. |
| F19 Permission revoke/failure/retry | PARTIAL | Camera permission was revoked through Android Settings while idle and left denied at handoff. Active revocation and post-revoke retry were not verified. |
| F20 Combined performance and lifecycle | PARTIAL | Combined sessions lasted about 110–144 seconds; no crash/ANR was observed. CPU/memory were not sampled. Decoded rates varied roughly 10–23 fps, below configured 30 fps and consistent with the separate known capture-cadence concern. |

**Android cases:** 4/20 PASS, 14 PARTIAL, 2 NOT RUN. This count treats only complete case-level evidence as PASS; it does not elevate historical TASK10 checks into new candidate passes.

## Recorded output evidence

| MediaStore ID | Local evidence | Result |
|---|---|---|
| 272 | `build/prompt04_qa/f04_candidate_facecam.mp4` | H.264, 720×1280, 143.96 s, 3327 frames. Full decode succeeded; Facecam pixels visible. |
| 279 | `build/prompt04_qa/f04_candidate_facecam_drawing.mp4` | H.264, 720×1280, 110.61 s, 1857 frames. Full decode succeeded; Facecam and two orange strokes visible; floating controls also visible. |
| 291 | `build/prompt04_qa/f04_candidate_camera_switch.mp4` | H.264, 720×1280, 110.39 s, 1093 frames. Full decode succeeded; decoded pixels change from front to back virtual-camera scene. |
| 305 | `build/prompt04_qa/f04_secure_controls_exclusion.mp4` | H.264, 720×1280, 127.79 s, 764 frames. Full decode succeeded; controls are hidden but their secure window becomes a black rectangle over changing content. Experiment rejected and reverted. |

Historical task output 271 is a fifth QA-created MediaStore item. It fully decoded with timestamp warnings and is not candidate evidence. There are four candidate attempts above, all decoded; no duplicate output was identified. All five items remain preserved in the app gallery.

## Overlay composition contract

| Layer or property | Result |
|---|---|
| Screen content | Recorded via full-display MediaProjection. |
| Facecam | Included when enabled — pixel-confirmed on the virtual camera. |
| Drawing | Included — pixel-confirmed in output 279. |
| Floating Ball and expanded controls | Excluded — FAIL. Normal capture records them; secure-window experiment creates a black hole. |
| Pixels under controls | The normal panel covers its visual footprint; the surrounding screen is present. `FLAG_SECURE` additionally blacks out the window region. |
| Rotation consistency | NOT RUN with the final orientation formula. |

## Automation and related regression checks

- Full Gradle native unit suite: `:app:testDebugUnitTest` — **162/162 PASS across 28 suites**, including FacecamGeometry (14) and DrawingStrokeEngine (10). Do not add the focused 24 again; these classes are included in the full count. The final debug APK build succeeded and was installed in place.
- Direct Dart analysis of `lib/features/recording/recording_service.dart` and `test/recorder_ui_test.dart` reported no issues. Both files were formatted.
- Earlier `flutter test --no-pub test/recorder_ui_test.dart` and `flutter analyze --no-pub` attempts stalled without producing results; they were interrupted. The Flutter widget suite and full regression suite are therefore not reported as passing.
- `git diff --check` passed. Full Flutter suite, localization checker and physical-device checks were not run in this prompt.

## Data preservation

- Initial host free space was C: 14.85 GiB and D: 18.50 GiB, above the requested minimum. A post-build free-space query was blocked by host filesystem access policy, so no post-build host value is claimed.
- App was updated in place; first install time remains 2026-11-05. No uninstall, data clear, AVD wipe or destructive cleanup occurred.
- At handoff camera permission is denied and SYSTEM_ALERT_WINDOW is denied, matching the initial state. Recording preferences are Mixed Stream and Facecam off. The QA media and owner-provided screenshots are retained.

## PROMPT04A — FOCUSED QA CLOSURE

This section supersedes the earlier Prompt04 statuses where new evidence exists. The earlier rows remain as the history of the initial candidate.

### F01–F20 current status

| ID | Result | Focused closure evidence / remaining limit |
|---|---|---|
| F01 Camera permission denied, granted and retried | PARTIAL | Camera permission was granted through Android Settings UI and later revoked through the same UI. The initial denied state was restored. Full deny/cancel/regrant retry as a single flow was not completed. |
| F02 Facecam opens with emulator camera frames | PASS | Live AVD virtual-camera preview and Facecam pixels are visible in decoded MediaStore videos 382, 393 and 404. The virtual scene is static; no real-camera freshness or optical quality claim. |
| F03 Front/back camera switching | PASS | Existing candidate 291 independently shows the distinct front green and back room/chessboard virtual scenes. Not repeated in this follow-up. |
| F04 Small/medium/large and drag | PARTIAL | The three size choices remain exposed in the source/UI; this follow-up only recorded default size/placement. Size-by-size pixel comparison, drag and clamp were not tested. |
| F05 Final orientation formula and recorded orientation | PARTIAL | Post-fix landscape capture 404 is fully decodable and shows Facecam after rotation. The track stays 720×1280 without rotation metadata while the screen is landscape (2400×1080), leaving the screen letterboxed in the portrait canvas. No dynamic output orientation pass. |
| F06 Effects and unsupported cases | PARTIAL | AVD exposes only effect OFF; unsupported effects are not offered. No additional effect can be verified with this virtual camera. |
| F07 Disable/revoke/Stop cleanup | PARTIAL | Camera disconnect/closed state was observed after Stop and permission was revoked while idle through Settings. Active revoke, occupied-camera handling and retry without stale ownership remain untested. |
| F08 Drawing over another app | PASS | Drawing-mode swipes on the Android Launcher are visible during the combined recording 393; the Launcher remains visible around the annotation. This is the AVD Home app only. |
| F09 Pen colors, widths and continuous strokes | PARTIAL | Orange short and long marks are visible in 393. Palette and width variations, and broad slow/fast/curved stroke coverage, were not confirmed in this follow-up. |
| F10 Undo/Redo/Eraser/Clear | PARTIAL | Portrait Undo/Clear taps did not land on the toolbar row (input y≈845 vs toolbar at a lower screen position); old marks remained in the screenshot. The rotated attempt produced a point but no verified long stroke. Current UI implements Undo and Clear; Redo/Eraser are absent. Do not claim Clear failed in the product or passed in QA. |
| F11 Existing shapes and styles | NOT RUN | No shape tool is exposed in the current drawing UI. Shapes are not implemented; no shape result is claimed. |
| F12 Touch pass-through after closing Drawing | PARTIAL | Drawing input was seen during active mode. A direct underlying-app tap after closing drawing, without any invisible touch surface, was not confirmed. |
| F13 Drawing pixels in recorded output | PASS | Orange stroke pixels are visible in decoded frames from 393 (for example `build/prompt04_qa/f04a_393_t162.png` and `_t178.png`). This proves drawing output before the mis-targeted Clear attempt only. |
| F14 Facecam pixels in recorded output | PASS | Facecam pixels are visible in the fully decoded 382, 393 and rotated 404 candidates. AVD feed is not optical camera evidence. |
| F15 Facecam + Drawing together | PASS | Video 393 contains both Facecam and orange annotation pixels in the same decoded frames. Exact drawing-over-camera overlap and all gesture conflicts are not exhausted. |
| F16 Floating Ball controls and overlap | PARTIAL | Notification “Show controls in video” displayed the expanded panel; its spacing is visibly inset in `prompt04a_controls_enabled.png` and in the rotated screen capture. Controls were explicitly opted into capture and remain visible in video. Full hit-test matrix is incomplete. |
| F17 Pause/Resume/Stop with overlays | PARTIAL | Notification Stop finalized the tested sessions. A confirmed Pause→Resume cycle with Facecam and Drawing active was not completed. |
| F18 Background/foreground and rotation | PARTIAL | Home/notification shade and rotation were observed during capture. Rotated video 404 decodes but keeps a portrait canvas with a letterboxed landscape screen. No return-to-portrait decoded segment or full lifecycle matrix. |
| F19 Permission revoke/failure/retry | PARTIAL | Camera grant and idle revocation used genuine Settings UI. Active camera revocation and post-revoke retry were not tested. Overlay access is denied at handoff. |
| F20 Combined performance and lifecycle | PARTIAL | No crash or ANR surfaced; no CPU/RAM sampling. Combined session 393 ran 236 seconds active and exceeded the suggested bound; rotated video 404 has a 224.783-second container duration for a roughly three-minute UI timer and repeated non-monotonic DTS warnings. Decoded cadence remains far below target 30 FPS (separate Prompt01 issue). |

**Prompt04A Android cases: 6/20 PASS, 13 PARTIAL, 1 NOT RUN.** PASS cases are F02, F03, F08, F13, F14 and F15. The F03 evidence is the previously verified candidate 291; it was not recaptured in this follow-up.

### Prompt04A output evidence

| MediaStore ID | Local evidence | Independent result |
|---|---|---|
| 382 | `build/prompt04_qa/f04a_facecam_mute_382.mp4` | H.264 720×1280, 193.286 s, 571 frames; full decode exit 0. Facecam pixels visible. |
| 393 | `build/prompt04_qa/f04a_combined_393.mp4` | H.264 720×1280, 238.727 s, 1,198 frames; full decode exit 0. Facecam and orange strokes visible together; controls were explicitly enabled in-video. Mis-targeted Clear/Undo taps mean no persistence claim. |
| 404 | `build/prompt04_qa/f04a_rotation_1794738804965.mp4` | H.264 720×1280, 224.783 s, 1,399 frames; full decode exit 0 with repeated non-monotonic DTS warnings. Landscape screen pixels and Facecam are present inside a portrait canvas; continuous rotated drawing was not verified. |

All three are finalized in MediaStore and remain in the app library. Screenshot output is MediaStore ID 359 (`Screenshot_1794736842233.png`, 1080×2400, 1,391,134 bytes) and is preserved. The output file exists, but shows Android Launcher after the consent flow rather than the 3HRecorder page that launched Screenshot, so the Screenshot regression is **PARTIAL**. The earlier Prompt02 result remains 15/16 scenarios and is not replaced by this single check.

### Flutter/native closure and workspace state

- Focused: `flutter.bat --verbose test --no-pub --reporter expanded --timeout 30s test\recorder_ui_test.dart` — exit 0, **4/4**.
- Full: `flutter.bat test --no-pub --reporter expanded --timeout 60s` — exit 0, **557/557** (`build/prompt04a_qa_flutter_full.log`). The apparent hang was SDK cache lockfile access from the sandbox, not a test awaiting camera/overlay state; approved execution access resolved it.
- Analysis: `flutter.bat analyze --no-pub` — exit 0, no issues.
- Native: `.\gradlew.bat :app:testDebugUnitTest --no-daemon` from `android` — exit 0, **162/162 in 28 suites**.
- Dart format check and `git diff --check` passed. Localization was not changed; no localization checker was rerun.
- Host free space at closure: C: **14.61 GiB**, D: **18.34 GiB**. AVD remains `emulator-5554`, Pixel_7 alias/API 37. Camera and overlay permissions were returned to denied; audio Mixed Stream, Facecam off, 3-second countdown, and portrait/auto-rotation were restored. No app data or pre-existing media was cleared or removed.

### Composition contract — current candidate

| Layer / property | Prompt04A result |
|---|---|
| Facecam included when enabled | **YES**, pixels confirmed in 382, 393 and 404. |
| Drawing included when enabled | **YES**, pre-Clear orange marks confirmed in 393. |
| Floating controls excluded | **FAIL / OPEN**. With notification opt-in, the controls/bubble appear in captured frames. |
| Pixels under controls preserved | **NO** under the visible controls footprint; the control UI covers it. No new exclusion approach was tried. The old FLAG_SECURE black patch remains rejected. |
| Landscape recording behavior | **PARTIAL**. Landscape screen pixels are captured but letterboxed in a fixed portrait 720×1280 track. |

Floating-control exclusion remains an independent release-blocking requirement. No overall app release readiness is implied.

