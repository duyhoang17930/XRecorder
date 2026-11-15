# Prompt04 — Facecam and Drawing defects and fixes

Date: 2026-11-15<br>
Candidate: package com.xrecorder.xrecorder, version 0.1.0, debug APK SHA-256 `A128DBD7FB57A53C818A1D1CEAF95561E8BF68C6482DB8B8DE4C7F9EBE893DF0`<br>
Device: Pixel_7 AVD alias, serial `emulator-5554`, Android 17 / API 37, virtual x86_64 camera.

## Defects and changes

| ID | Finding and cause | Change | Evidence / remaining limit |
|---|---|---|---|
| P04-FC-01 | Facecam rotation did not use the sensor orientation and facing-specific display compensation consistently. The old helper ignored sensor metadata. | `FacecamGeometry.calculateRotation` now uses sensor orientation, subtracts display rotation for front-facing buffers, adds it for back-facing buffers, then normalizes. The no-metadata overload uses typical front 270° / back 90° values. | 14 geometry tests now cover front/back, four display rotations, aspect scaling, invalid dimensions, position and action state. Camera frames were recorded before this final formula correction; a rotated live preview and post-correction MP4 were not captured, so live orientation remains PARTIAL. Formula follows the official [Camera2 preview orientation guidance](https://developer.android.com/media/camera/camera2/camera-preview). |
| P04-FC-02 | On open/runtime failure the Facecam control could imply a usable camera and leave stale UI state; a camera failure should not terminate screen recording. | Facecam reports one failure, hides stale preview while switching until a fresh timestamped frame arrives, closes camera resources, and CaptureService removes the camera action on failure while keeping screen recording active. Unsupported effects are omitted from the menu. | Candidate camera open, front/back switch and MP4 imagery were exercised before the final orientation adjustment. Runtime permission revocation while camera is active and occupied-camera retry remain unverified. |
| P04-FB-01 | The contents of the expanded floating panel sat too close to its rounded outer stroke. Width calculations also assumed a fixed number of drawing actions even when camera options were unavailable. | Increased inner panel padding to 8 dp horizontally and 6 dp vertically; width fitting now follows the visible action count. The Facecam action is added/removed with camera availability. | Candidate AVD screenshot showed the additional inset and the floating controls remained usable in the tested session. Cutout, rotation and large-font cases remain unverified. |
| P04-UI-01 | The terminal recording error footer used a separate heading and message row, leaving a large gap and taking up more vertical screen area. In the supplied screenshot, the red rectangles were drawn by the owner and are not app UI. | Terminal errors now use a compact one-row “Error · message” footer, with the existing Help and dismiss actions kept available; normal active recording status is unchanged. | Triggered by declining the normal screen-capture consent on the AVD; compact footer was visually verified. This is an app-owned bottom status surface, not a full-screen system overlay. |
| P04-OV-01 | Full-display MediaProjection records the composed display, including the app's floating controls. The current pipeline has no supported per-window exclusion stage that can remove those controls while retaining the pixels behind them. | No unsafe workaround was retained. A controlled experiment applied public `FLAG_SECURE` only to the control window; it removed control pixels but the decoded MP4 contained an opaque black rectangle in their place, so the change was reverted. | MP4 URI 305 was independently decoded while changing the screen behind the controls. The black patch moved with/covered the control region and obscured changing content. This fails the required exclusion contract. See [Android MediaProjection](https://developer.android.com/media/grow/media-projection) and [WindowManager.LayoutParams](https://developer.android.com/reference/android/view/WindowManager.LayoutParams). |

## Composition and interaction contract

- Facecam: included in decoded MP4 frames when enabled — verified on the AVD virtual camera.
- Drawing: included in decoded MP4 frames — two orange strokes verified in the combined candidate output.
- Floating controls: excluded from MP4 — **FAIL / OPEN**. With the normal pipeline the ball and expanded controls are recorded. With the tested secure-window experiment their area becomes black.
- Pixels behind controls: visible outside their footprint in normal output; obscured by the control UI footprint itself. With `FLAG_SECURE`, pixels in the footprint are black and lost.
- Rotation consistency: not verified in a recorded session after the final sensor-orientation formula change.
- Overlap: current ordering places Facecam above captured screen content and drawing annotations above the screen layer; the combined video showed both. Exact drawing-versus-camera overlap and hit-testing through a camera window were not exhaustively tested.

The smallest clean direction is a capture/composition architecture that can keep the control plane separate from recorded content while preserving the independently captured screen and user-requested Facecam/drawing layers. Android supports capturing either the full display or a user-selected app window; single-app sharing excludes unrelated apps/system UI, so it does not meet 3HRecorder's requirement to continue across supported external apps. In the current full-display pipeline, public `FLAG_SECURE` masks secure-window pixels rather than restoring the pixels behind them. No public-API, pixel-clean exclusion solution was demonstrated here. Keep this release requirement open rather than describing the secure-window experiment as a pass. See the official [MediaProjection guide](https://developer.android.com/media/grow/media-projection) and [FLAG_SECURE reference](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#FLAG_SECURE).

## Preserved behavior and data

- No app uninstall, app-data clear, emulator wipe, source reset, commit or push was performed.
- The debug candidate was installed with `adb install -r`; the app's first-install time remained 2026-11-05 and MediaStore outputs were preserved.
- Camera permission and overlay permission were returned to their initial denied states after QA. Recording preferences were restored to Mixed Stream and Facecam off.
- Five QA recordings were created under distinct MediaStore IDs 271, 272, 279, 291 and 305. All remain in the app gallery; no existing media, drafts, recovery inputs, protected resources or model files were removed.
- The two owner-provided annotated screenshots remain untouched. Red outlines in the supplied image are owner annotations, not app controls.

## PROMPT04A — FOCUSED QA CLOSURE

### Rechecked owner UI feedback

- The AVD screenshot `build/prompt04_qa/prompt04a_home2.png` shows the recording failure footer on one compact row (`Error · message`) without the former large gap. The red boxes in the owner's screenshot are hand-drawn annotations.
- `build/prompt04_qa/prompt04a_controls_enabled.png` shows the expanded controls inset from the panel border. The owner-requested footer spacing and floating-panel padding fixes were already present in the Prompt04 candidate and remain visually verified. No new source change was needed in Prompt04A.

### Focused findings

| ID | Reproduction / evidence | Root cause or conclusion | Follow-up |
|---|---|---|---|
| P04A-ROT-01 | Rotated the active AVD from portrait to landscape during recording. Android changed to a 2400×1080 display; Facecam remained open and was visible in landscape portions of MediaStore video 404. The complete file is 720×1280 with no rotation metadata, so the landscape display is letterboxed inside a portrait canvas with black above and below. | The video encoder receives fixed `CaptureConfig.width/height` at session start and is not reconfigured by the service's rotation callback. The callback only transforms/repositions Facecam, controls and drawing windows. | **Open / partial.** Do not claim orientation-complete output. A dynamic encoder/composition change is outside this focused QA closure. No post-rotation rebuild or unsafe crop was attempted. |
| P04A-DRAW-01 | The portrait session screenshots show the old orange marks still present after the intended Undo/Clear taps. Comparing the screenshot bounds with the input coordinates shows those taps were sent above the expanded toolbar, so the buttons were not actually activated. In the rotated session, the toolbar collapsed on entering drawing; only a point, not a continuous stroke, is confirmed in the decoded output. | This is a QA input-targeting failure, not evidence that `DrawingStrokeEngine.clear()` is defective. Unit coverage passes, but the overlay gesture/actions were not validly exercised through the rotated UI. | **Unresolved verification.** F10 and rotated drawing remain PARTIAL. Do not describe Clear as passing or as a reproduced product defect. |
| P04A-AUDIO-01 | A Mixed Stream attempt ended with `Audio capture was interrupted. Try a different audio source or mute.` A later Mute Facecam session completed. | Matches the separate Prompt01 audio-capture issue; this task did not change audio capture. | Keep the Prompt01 issue separate; do not infer audio or 30 FPS quality from these clips. |

### Test-hang resolution

- Focused command: `flutter.bat --verbose test --no-pub --reporter expanded --timeout 30s test\recorder_ui_test.dart` — exit 0, **4/4 passed**.
- Full command: `flutter.bat test --no-pub --reporter expanded --timeout 60s` — exit 0, **557 passed**. Log: `build/prompt04a_qa_flutter_full.log`.
- Analysis: `flutter.bat analyze --no-pub` — exit 0, no issues.
- Root cause: Flutter's wrapper could not open its SDK cache lockfile at `D:\Android\flutter\bin\cache\lockfile` from the workspace sandbox and retried without surfacing the bootstrap error. No active lock owner or test waiting on an app callback was found. Running the commands with approved access to the existing SDK/cache resolved the stall; no tests were removed or weakened.
- Native command: `.\gradlew.bat :app:testDebugUnitTest --no-daemon` from `android` — exit 0, **162/162 passed across 28 suites**. This is a rerun of the complete suite, not an added count.
- Formatting command: D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib\features\recording\recording_service.dart test\recorder_ui_test.dart — exit 0.
- Formatting/checks: Dart format check and `git diff --check` passed. Localization was unchanged; its checker was not rerun.

### Output and preservation

- Three Prompt04A video outputs were independently fully decoded: MediaStore IDs **382**, **393**, and **404**. ID 404 (`Recording_1794738804965.mp4`, 2,750,019 bytes) is the post-fix rotated candidate; H.264 720×1280, 1,399 frames, 224.783 s container duration, FFmpeg decode exit 0. FFmpeg reports repeated non-monotonic DTS warnings, and measured cadence remains below the configured 30 FPS. It contains AVD Facecam pixels after rotation, letterboxed landscape screen pixels, and a point annotation; it does not prove continuous rotated drawing or clean output timing.
- Screenshot output ID **359** is a finalized 1080×2400 PNG (`Screenshot_1794736842233.png`, 1,391,134 bytes). It was saved through the real screenshot flow, but depicts the Android Launcher after consent rather than the 3HRecorder page from which the flow was started. Screenshot regression is therefore PARTIAL, not a source-pixel PASS.
- No source files were changed in Prompt04A. QA reports and the physical-device handoff are the only project-file updates. Camera permission was revoked again through Android Settings; overlay access remains denied; Facecam was turned off and recording audio/countdown settings were restored to Mixed Stream / 3s. Rotation was restored to portrait. All QA media remain in MediaStore; no app data or old files were deleted.

Floating-control exclusion remains **FAIL / OPEN**. MediaProjection output contains the visible floating bubble/controls when enabled. No clean pixel-preserving exclusion was discovered or claimed.

