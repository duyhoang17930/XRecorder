# Floating Ball bugs and fixes

Date: 2026-11-15 | Workspace: `D:\FAU_App\XRecorder` | Branch / HEAD: `main` / `5f8bbb80e6e86c7dfea1f980fddd4283ddba7d29`

## Findings

### FB-01 — Dragging left could snap back to the old saved position (fixed)

- **Severity:** P1 interaction defect.
- **Reproduction:** Start a recording with controls visible at the saved right edge, then drag the toolbar left. A root layout/insets callback could reuse the old normalized position before release and move the window back right. The original behavior is captured in `../../../build/prompt03_floating_ball/evidence/drag_left_step.png` and `drag_left_top.png`.
- **Cause:** The drag updated the live `WindowManager.LayoutParams`, while the old normalized position remained valid. A layout callback could apply that stale value during the same gesture.
- **Fix:** On the first movement past touch slop, invalidate the stale normalized position. Keep the finger-relative drag coordinates, clamp to the current usable bounds, then edge-snap and persist the new normalized position on release. The change is in [`FloatingRecordingControls.kt`](../../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingRecordingControls.kt) with geometry coverage in [`FloatingControlGeometry.kt`](../../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingControlGeometry.kt) and its unit test.
- **Verification:** Rebuilt and installed the APK. A left-edge drag and a right-edge drag both remained at their new positions; collapse and reopen retained the placement. See `fixed_drag_left.png`, `fixed_drag_right.png`, `fixed_collapsed.png`, and `fixed_reexpanded.png`.

### FB-02 — Overlay permission state and recovery were not exposed clearly (fixed)

- **Cause:** The settings flow did not provide a clear, refreshed route through Android's overlay permission screen.
- **Fix:** Added a localized Floating Controls permission row. It launches the Android Settings screen, refreshes `Settings.canDrawOverlays()` when the app resumes, and reports denied/granted state. The capture service removes the window after revocation and can reattach one window to the still-running opted-in session after permission is granted again. Recording itself remains owned by the existing capture service.
- **Verification:** Granted permission through system Settings, revoked it during a recording, confirmed the ball disappeared while capture continued, then granted it again and confirmed one ball returned to the same live session. Permission was restored to its original denied state afterward. Evidence: `overlay_permission_granted_system.png`, `permission_revoked.png`, `permission_regranted.png`, and `permission_restored_denied.png`.
- **Security:** No `appops` changes, accessibility workaround, bypass, or automatic permission grant was used.

### FB-03 — No confirmed touch-through regression

One earlier stop attempt was followed by a Clock alarm editor screen. A controlled repeat stopped the recording while the Clock app was underneath and left that screen unchanged; the save toast and final output were present. The event was not reproducible, so it is recorded as unconfirmed rather than as a defect. See `stop_touch_check.png` and `floating_stop_reproduction.mp4`.

### FB-04 — Low-memory emulator process interruption (environment limitation)

During a separate run, the 2 GiB emulator experienced system memory pressure and killed multiple processes. MediaProjection ended with process death; the app showed an interruption/recovery state, did not restart capture, and did not leave a floating window or publish a partial output. This was not an app crash reproduced under normal operation and is not attributed to the Floating Ball. See `reopened_after_process_death.png`. Prompt01's separate audio/video cadence observations remain unchanged.

## Product behavior decision

- **Idle/ready:** No ball is shown while there is no active recording. Enabling the permission does not create an always-on idle window.
- **Recording:** The user explicitly chooses **Show controls in video** from the existing recording notification. Android overlay permission is still required. The notification warns that these controls can appear in the recorded video; a decoded frame confirms this contract.
- **Controls:** The ball exposes expand/collapse, Pause/Resume, Stop, and Drawing entry where supported. Start remains in the existing capture flow and uses normal MediaProjection consent. Screenshot is not exposed by this Floating Ball contract and no new Screenshot action was added.
- **Session ownership:** The existing `CaptureService` and MediaProjection session remain the only capture engine. The ball is service-owned and does not bind itself to an Activity instance.

## Research considered

- Android documents that `TYPE_APPLICATION_OVERLAY` requires `SYSTEM_ALERT_WINDOW`, sits below critical system windows, and can have its position, size, or visibility changed by the system: [WindowManager.LayoutParams](https://developer.android.com/reference/android/view/WindowManager.LayoutParams).
- The permission flow uses the documented `Settings.canDrawOverlays()` and overlay Settings intent: [Settings API](https://developer.android.com/reference/android/provider/Settings#canDrawOverlays(android.content.Context)) and [Manifest permissions](https://developer.android.com/reference/android/Manifest.permission#SYSTEM_ALERT_WINDOW).
- Android 12+ constrains pass-through touches from untrusted overlay windows; the implementation retains the platform protections and uses a small, touchable control window rather than a full-screen window: [Android 12 behavior changes](https://developer.android.com/about/versions/12/behavior-changes-all).
- Window inset and cutout APIs describe system-bar, gesture, IME, and cutout regions: [WindowInsets](https://developer.android.com/reference/android/view/WindowInsets) and [display cutout guidance](https://developer.android.com/develop/ui/views/layout/display-cutout).
- The similar symptom in this [Stack Overflow Android 14 overlay position report](https://stackoverflow.com/questions/79224256/android-14-overlay-button-service-type-application-overlay-glitches-to-previo) has no verified fix and discusses changing view dimensions. This checkout reproduced a different cause: stale normalized app position applied during a drag. No community code or workaround was copied; the local repair was verified on the AVD.
- Capture continues to use the documented [MediaProjection flow](https://developer.android.com/media/grow/media-projection) and existing [foreground service type](https://developer.android.com/develop/background-work/services/fgs/service-types).

## Remaining limitations

- The emulator has no cutout, so cutout placement was not exercised. The keyboard/IME case, large text, TalkBack, and OEM-specific behavior remain unverified.
- Position persistence was exercised across collapse/reopen, but the existing scale/opacity update path was not changed during QA and was not separately adjusted at runtime.
- All three MP4s fully decoded, but FFmpeg reported non-monotonic DTS warnings. Container/decode validity is verified; recording cadence/audio quality is not declared PASS and remains separate from Prompt01 findings.
- The full Flutter test suite had nine failures in localization expectations and settings test mocks after adding the permission row. Those expectations/mocks were corrected, but a rerun could not start because the Flutter SDK was locked by the active VS Code Flutter daemon. The failed initial run is not represented as a pass.
- Physical-device/OEM QA was not run. The concise `docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md` remains the hardware handoff; it was not expanded with emulator cases.

## PROMPT03B — UI/UX FOLLOW-UP

Date: 2026-11-15. This addendum records the visual refinement pass and the later timer-only label request.

### FB-03B-01 — Hide the word “Recording” in the expanded ball

- **Requested result:** Keep the colored status dot and elapsed timer; remove the visible status word to make the row compact.
- **Change:** `FloatingRecordingControls.kt` now sets the app-owned status `TextView` to `View.GONE` on every render. The timer remains visible. Its accessibility description still includes the localized recording/paused state, elapsed time, collapse hint, and drag hint.
- **Build/install:** `:app:testDebugUnitTest` and `:app:assembleDebug` passed. The installed APK and workspace APK have the same SHA256: `EA64DF23AD06DFCCF5782FCB6809EFEB95F26DE6C6E8C87040B89AB6F574BF76`.
- **Runtime status:** The screenshot that still displays “Recording” (`64_ball_right_edge.png` / `65_floating_paused.png`) predates this label change. A later full-screen capture was started and finalized as MediaStore ID 234, but its notification action **Show controls in video** was not selected, so that run did not display the ball. There is no post-change screenshot of the expanded ball; visual disappearance is therefore **PARTIAL / not confirmed on-device**. Android’s own screen-recording chip and recording notification remain system UI and are intentionally unchanged.

### UI refinements completed

- Replaced Android framework icons in the native floating controls (pause/play, stop, drawing, undo, clear, drawing style, and camera) with Lucide-style Android vector drawables. Flutter Settings uses the existing `lucide_flutter` package for `video` and `picture-in-picture-2`; no icon dependency was added.
- Reworked the existing floating panel into a timer/status and Pause/Stop/Collapse row plus a separate Drawing/Undo/Clear/Style row. Drag starts on the status/timer area, keeping action buttons out of the drag hit target. Earlier Prompt03B captures show this layout and Lucide assets (`64_ball_right_edge.png`); they predate the timer-only label patch.
- Changed the active-recording in-app footer to a compact status/action strip and isolated its updates from unrelated library rebuilds. Automated coverage passed; this follow-up did not obtain a fresh on-device screenshot of that footer.
- Grouped Recording settings and Floating controls into the Settings Capture card, using distinct Lucide icons and sentence-case English. Current AVD screenshot `103_settings_tab2.png` shows the grouped card and compact Settings header. `16_editing_studio_final.png` is the Editing Studio comparison.
- Reduced root header spacing and adjusted affected English labels to sentence case. The changed ARBs and native capture strings preserve non-English capitalization conventions.

### Overlay pixels in MP4

The current product behavior remains explicit opt-in: the notification action says **Show controls in video**, and the controls are composed into the recording when selected. Prompt03 decoded output already demonstrates that behavior. This follow-up did not produce a new output with the controls visible. The available MediaProjection flow captures the display; the public APIs used here do not provide a supported per-window exclusion switch. `FLAG_SECURE` would suppress protected pixels and can leave a blank area, so it is not a safe way to meet the requested clean-pixel result. Keep the choice opt-in and clearly labeled. References: [MediaProjection](https://developer.android.com/media/grow/media-projection), [WindowManager.LayoutParams](https://developer.android.com/reference/android/view/WindowManager.LayoutParams), and [AOSP SurfaceControl](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android12-release/core/java/android/view/SurfaceControl.java).

### Verification and preservation

- Flutter full suite: **556 passed** (`build/prompt03b_uiux_20261115/evidence/flutter_full_suite_final.log`); focused regressions: **66 passed**. Native `:app:testDebugUnitTest`, `flutter analyze --no-pub`, formatting, localization structure check, and `git diff --check` passed. The Flutter run resolved the earlier SDK-lock block; the final Screenshot-specific Android run remains outstanding.
- Android 17 / API 37 Pixel_7 AVD: Settings Capture group and permission screen were captured after the update. The AVD was heavily delayed; `uiautomator dump` stalled and Settings took about 34 seconds to draw. The final timer-only panel could not be captured.
- New task capture ID 234 (`Recording_1794723007969.mp4`) is published (`is_pending=0`, MP4 MIME, 477,750 ms, 2.6 MiB). It was not independently decoded and is not evidence for overlay inclusion/exclusion.
- Audio source and countdown were restored through the app UI to **Mixed Stream** and **3s**. Overlay permission was restored through Android Settings UI to **Not allowed**. C: 14.85 GiB free; D: 18.50 GiB free. No data clearing, uninstall, AVD reset, media deletion, or commit/push occurred.

### Prompt11 localization backlog

See [`PROMPT11_LOCALIZATION_BACKLOG.md`](PROMPT11_LOCALIZATION_BACKLOG.md) for the short list of suspicious translations and long UI strings requiring native-speaker/layout review.
