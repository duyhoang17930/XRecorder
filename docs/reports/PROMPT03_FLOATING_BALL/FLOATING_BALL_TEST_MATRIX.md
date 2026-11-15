# Floating Ball test matrix

- Run date: 2026-11-15
- AVD: `Pixel_7`, serial `emulator-5554`, Android 17 / API 37, 1080×2400, 420 dpi, gesture navigation
- Package: `com.xrecorder.xrecorder`, version `0.1.0` / code `1`
- Evidence root: `../../../build/prompt03_floating_ball/evidence/` (local, Git-ignored raw evidence)

## Native emulator cases

| Case | Result | Evidence / notes |
|---|---|---|
| B01 — Launch with Floating Controls disabled / idle | PASS | No idle ball at Home; `idle_home_no_ball.png`. Idle behavior remains hidden even when overlay permission is available. |
| B02 — Enable controls and request permission | PASS | Real Android overlay Settings flow; grant state returned to the app. `settings_hub.png`, `overlay_permission_settings.png`, `permission_granted_return.png`. |
| B03 — Deny/cancel and recover | PASS | Left the system switch off, returned, confirmed denied state, then granted through Settings and recovered. `permission_cancel_return.png`, `permission_granted_return.png`. |
| B04 — Home visibility | PASS | Active-session ball shown on Home. `ball_home.png`. |
| B05 — Other app visibility | PASS | Ball shown and used over Android Clock. Android protected Settings surfaces may hide it. `expanded_over_clock.png`, `clock_overlay.png`. |
| B06 — Drag and both edge snaps | PASS | Reproduced stale-position defect, installed fix, dragged left and right, collapsed and reopened. `fixed_drag_left.png`, `fixed_drag_right.png`, `fixed_collapsed.png`, `fixed_reexpanded.png`. |
| B07 — Expand/collapse, rapid tap, outside tap | PASS | Tap, repeated toggles, and tap outside behaved as expected. `rapid_toggle.png`, `outside_collapse.png`. |
| B08 — Start using existing route | PASS | Existing start route and normal MediaProjection consent used; no floating Start action added. `manual_record_consent.png`, `recording_notification.png`. |
| B09 — Floating Pause/Resume and timer | PASS | Pause changed to Resume and timer froze; Resume continued the same visible session. `floating_pause.png`, `paused_over_clock.png`, `floating_resume.png`, `resumed_over_clock.png`. |
| B10 — Floating Stop and publication | PASS | Three task recordings finalized and published as complete MediaStore rows; see output validation below. `stop_touch_check.png`, `final_stopped.png`. |
| B11 — Background/foreground without duplicates | PASS | Home/app round trip retained one service-owned overlay. `foreground_roundtrip.png`; WindowManager showed one Floating Controls window. |
| B12 — Rotation and insets | PARTIAL | Portrait/landscape and return placement checked. No cutout AVD or keyboard/IME case. `landscape.png`, `landscape_expanded.png`, `rotation_return_check.png`. |
| B13 — Revoke and recover permission | PASS | Revocation removed overlay while recording continued; regrant restored one overlay to the live session. `permission_revoked.png`, `permission_regranted.png`. |
| B14 — End/failure cleanup | PASS | Stop removed service/window. Low-memory process death did not auto-restart capture or leave an orphan overlay; see `reopened_after_process_death.png`. |
| B15 — Drawing entry/exit and touch-through | PASS | Drawing controls opened and exited. A tap outside the ball reached the underlying Clock screen. `drawing_entry.png`, `drawing_exit.png`, `touch_passthrough.png`. |
| B16 — Reopen, preference persistence, session identity | PARTIAL | Settings restored and permission state refreshed. The same live session survived permission revoke/regrant, but no machine-readable session-ID correlation was captured across app reopen. `final_preferences_check.png`, `permission_regranted.png`. |
| B17 — Narrow layout, font scale, touch targets | PARTIAL | 411 dp layout and 48 dp target sizes checked. Large text, TalkBack, and runtime scale/opacity adjustments were not exercised. `floating_expanded.png`, `ball_in_app_expanded.png`. |
| B18 — Rapid commands/service stress | PARTIAL | Rapid expand/collapse taps tested. No command storm or extended foreground-service stress run. `rapid_toggle.png`. |

**Result: 14 PASS / 18; 4 PARTIAL / 18; 0 FAIL.** A partial case is not counted as a pass.

## Capture output validation

| MediaStore ID | Duration | Size | Stream | Validation |
|---:|---:|---:|---|---|
| 135 | 539.271 s | 77,913,561 bytes | H.264, 720×1280, 13,165 frames | Completed row (`is_pending=0`); FFprobe valid; full FFmpeg decode exit 0. |
| 171 | 496.452 s | 47,837,974 bytes | H.264, 720×1280, 12,548 frames | Completed row (`is_pending=0`); FFprobe valid; full FFmpeg decode exit 0. |
| 202 | 58.909 s | 4,979,395 bytes | H.264, 720×1280, 1,462 frames | Completed row (`is_pending=0`); FFprobe valid; full FFmpeg decode exit 0. |

Local MP4 copies are `floating_stop_recording.mp4`, `floating_stop_permission_recovery.mp4`, and `floating_stop_reproduction.mp4`. A decoded frame at 55 seconds shows the Clock screen with the controls visible as expected by the explicit “Show controls in video” action: `recorded_frame_55s.png`. FFmpeg emitted non-monotonic DTS warnings on all three files; output integrity is verified, but cadence/audio quality is not.

## Automated and preservation checks

| Check | Result |
|---|---|
| Android `:app:testDebugUnitTest` | PASS; Gradle completed successfully, task was up to date. |
| Flutter full suite | PARTIAL / not green: initial run had 9 test-harness failures; permission mocks and regional localization expectation were fixed. Rerun/focused run could not start because an active VS Code Flutter daemon holds the SDK lock. |
| Dart analyzer | PASS: `dart analyze`, no issues. |
| Localization checker | PASS: 12 locale key sets, descriptions, Unicode, and placeholders. |
| Dart formatting | PASS: changed Dart files format clean. |
| `git diff --check` | PASS; only line-ending warnings for two test files and the existing localization sync script. |
| Screenshot regression | No Screenshot-named test failed in the initial full Flutter run; the suite was not rerun after its settings/localization fixture fixes. Prompt02's 15/16 Android result and FLAG_SECURE limitation are unchanged. |
| Storage | PASS: C: 14.92 GiB free; D: 18.54 GiB free (above required thresholds). |
| Preservation | PASS: original MediaStore video IDs 45 and 47–53 remain; three task-created outputs 135/171/202 were retained. No app-data clear, uninstall, AVD wipe, or user-media deletion. Recording settings and rotation were restored; overlay permission returned to its initial denied state. |

The AVD remained online as `emulator-5554`. Package and APK identity are recorded in `FLOATING_BALL_FINAL_HANDOFF.md`.

## PROMPT03B — UI/UX follow-up matrix

AVD: Pixel_7 / `emulator-5554`, Android 17 / API 37. Current workspace and installed APK hashes matched (`EA64DF23AD06DFCCF5782FCB6809EFEB95F26DE6C6E8C87040B89AB6F574BF76`). Evidence is under `../../../build/prompt03b_uiux_20261115/evidence/`.

| Case | Result | Evidence / notes |
|---|---|---|
| U01 — New expanded overlay layout and timer-only label | PARTIAL | Redesigned panel was visible in `64_ball_right_edge.png`; that image predates hiding the status word. The latest APK compiled and installed, but no post-change expanded-panel screenshot was captured. |
| U02 — Lucide-style native overlay icons | PASS | Vector resources compile; the refined panel icons are visible in `64_ball_right_edge.png`. |
| U03 — Drag/expand/collapse without accidental actions | PASS | Left/right edge and expand/collapse interaction evidence from Prompt03 remains valid; drag hit testing is limited to status/timer/bubble. See `63_ball_left_edge.png`, `64_ball_right_edge.png`. |
| U04 — Floating Pause/Resume/Stop | PASS | Prompt03 native controls changed the active session and finalized output. `65_floating_paused.png` is from before the label-only patch. |
| U05 — Overlay visible during recording | PASS | Previously verified on Home and Clock with explicit notification opt-in (`62_ball_on_home.png`, `clock_overlay.png`). The later test recording did not opt in to showing controls. |
| U06 — Actual MP4 overlay behavior | PARTIAL | Earlier decoded frame shows controls when **Show controls in video** is selected. The owner’s preferred clean-pixel exclusion was not implemented because this MediaProjection path has no supported per-window exclusion. New ID 234 did not show the ball and was not decoded. |
| U07 — Compact in-app Recording status bar | PARTIAL | Source and widget tests cover the compact bar; no fresh on-device active-bar screenshot was captured in this follow-up. |
| U08 — Status bar spacing from Bottom Navigation | PARTIAL | Layout/widget coverage passed; large-text/native runtime comparison remains unverified. |
| U09 — Recording → Pause → Resume → Stop status flow | PARTIAL | Floating Pause/Resume/Stop itself is covered by U04. The new in-app footer state sequence was not run on-device. |
| U10 — Settings Capture group and distinct icons | PASS | Current AVD screenshot `103_settings_tab2.png` shows the grouped rows and Lucide `video` / `picture-in-picture-2` icons. |
| U11 — Settings header spacing vs Editing Studio | PASS | Current Settings image `103_settings_tab2.png` and Editing Studio image `16_editing_studio_final.png` show the adjusted root-header rhythm. |
| U12 — English sentence case | PASS | Affected English labels are sentence case in Settings and the library/editor snapshots (`13_settings_final.png`–`16_editing_studio_final.png`, `103_settings_tab2.png`). |
| U13 — Vietnamese and Arabic/RTL layout | PARTIAL | Translations are present and structurally valid. No real-AVD Vietnamese or RTL visual pass was captured. |
| U14 — Portrait/landscape/narrow/large text | PARTIAL | Flutter layout tests cover compact widths and 200% text. The final native overlay and Settings views were not exercised at all requested dimensions/scales. |
| U15 — Permission and overlay cleanup | PASS | Android Settings showed `Not allowed` after restoration (`114_overlay_permission_denied.png`); `SYSTEM_ALERT_WINDOW` app-op is `deny`. Prompt03 grant/revoke/recovery coverage remains in the earlier matrix. |
| U16 — Screenshot integration regression | PARTIAL | The full Flutter suite, including Screenshot UX tests, passed. The final real-Android Screenshot regression was not rerun. |

**U-case result: 8 PASS / 16; 8 PARTIAL / 16; 0 FAIL.** Partial means no complete on-device proof for that case.

### Follow-up capture output

| MediaStore ID | File | Duration | Size | Validation |
|---:|---|---:|---:|---|
| 234 | `Recording_1794723007969.mp4` | 477.750 s | 2.6 MiB | Published (`is_pending=0`, MP4 MIME, MediaStore duration available). No independent full decode; no overlay was opted into for this run. |

This task-created output was retained. Previous user-media rows were not deleted; the three prior Prompt03 decode-verified outputs remain separately reported above.
