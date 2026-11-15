# PROMPT03 Floating Ball final handoff

Date: 2026-11-15 | Branch / HEAD: `main` / `5f8bbb80e6e86c7dfea1f980fddd4283ddba7d29`

AVD: `Pixel_7`, `emulator-5554`, Android 17 / API 37, 1080×2400 at 420 dpi. App: `com.xrecorder.xrecorder` 0.1.0 (versionCode 1).

APK: `build/app/outputs/flutter-apk/app-debug.apk` | SHA256: `4C61FA826E83A2EED6A357FDEC2D3DE889B2617465292E30D5430F5FA8484BFF`

## Acceptance summary

| Gate | Result | Evidence-based note |
|---|---|---|
| G1 Visibility | PASS | Hidden while idle; explicit notification action shows it on Home and over Clock during recording. |
| G2 Permission | PASS | Real grant, denied return, revoke during recording, and regrant recovery tested through Android Settings. |
| G3 Interaction | PASS | Drag fix verified at both edges; expand/collapse, outside tap, and underlying-app touch tested. |
| G4 Recording | PASS | Pause/Resume/Stop operated on the active capture; three finalized MP4 outputs verified. |
| G5 Lifecycle | PASS | Background/foreground retained one overlay; stop/revoke/process interruption cleaned up; no auto-restart. |
| G6 Data/security | PASS | No permission bypass or deletion; completed MediaStore rows and recovery behavior checked. |
| G7 UI/accessibility | PARTIAL | Localized permission copy and 48 dp touch targets; TalkBack, large text, cutout, keyboard, and OEM cases not run. |
| G8 Regression | PARTIAL | Native/Dart/localization checks pass; Flutter suite rerun and final Screenshot regression gate are blocked by the SDK lock. |

## Required status fields

| Field | Result |
|---|---|
| ADB/AVD | PASS |
| BALL OUTSIDE APP | PASS |
| BALL OVER OTHER APPS | PASS |
| OVERLAY PERMISSION | PASS |
| DRAG & EDGE SNAP | PASS |
| EXPAND/COLLAPSE | PASS |
| FLOATING PAUSE/RESUME/STOP | PASS |
| CAPTURE OUTPUT | PARTIAL — all three MP4s are complete and fully decode, with non-monotonic DTS warnings; audio/cadence quality is not asserted. |
| ROTATION & LAYOUT | PARTIAL — portrait/landscape and current system insets checked; cutout/IME not tested. |
| TOUCH PASS-THROUGH | PASS |
| SESSION/OVERLAY CLEANUP | PASS |
| ACCESSIBILITY | PARTIAL |
| AUTOMATED TESTS | PARTIAL |
| EMULATOR QA | PARTIAL |
| DATA PRESERVATION | PASS |
| PHYSICAL DEVICE | NOT RUN |

- ANDROID CASES: **14/18 PASS** (4 PARTIAL, 0 FAIL)
- ACTUAL RECORDING OUTPUTS VERIFIED: **3**
- CHANGED FILES: **46** (41 implementation/test/localization files, 2 TASK10 status documents, and these 3 reports)
- REMAINING DEFECTS: No reproduced P0/P1 Floating Ball defect remains. Unverified: full Flutter test rerun, accessibility/large text, keyboard/cutout, scale/opacity runtime adjustments, extended command stress, and physical/OEM behavior. The three MP4 decode runs emitted timestamp warnings; Prompt01 recording-quality findings remain separate.

PROMPT03 FINAL: **PARTIAL**

## Implementation summary

- Idle controls stay hidden. An active recording gets one ball only after the user explicitly chooses **Show controls in video** from the existing notification and has granted overlay permission.
- Overlay grant state is exposed in Settings and refreshed on return from Android Settings. Revocation removes the ball without stopping the capture; regrant can restore the ball to the same live session.
- Dragging invalidates the stale saved ratio once movement passes touch slop. The ball clamps and edge-snaps within current usable bounds, then persists its new normalized position.
- Existing capture service ownership is retained. Floating Pause/Resume/Stop and Drawing entry use the existing session; no second capture engine, floating Start, Screenshot button, AccessibilityService, or full-screen touch window was introduced.
- New strings were added to all current ARBs and native locale resources. Permission/recording settings were restored to their pretest values, and overlay permission was restored to denied.

## Verification and limits

- `:app:testDebugUnitTest` succeeded (Gradle reported the task up to date). `dart analyze`, Dart formatting, `tool/check_l10n.py`, and `git diff --check` passed.
- The first `flutter test --no-pub` full run reported 9 failures: the new regional string was not in the intentional Portuguese difference list, and existing settings test mocks did not answer the new permission method. Both test fixtures were corrected. A focused rerun then blocked at Flutter startup because the active VS Code Dart/Flutter daemon held the SDK lock. It was left running; the Flutter suite and final Screenshot regression rerun remain unverified.
- All three task recordings were published (`is_pending=0`), FFprobe-valid and fully decoded. One decoded frame shows the active Clock screen and the floating controls. DTS warnings make cadence/audio quality a separate unresolved recording concern; do not interpret this as a Prompt01 regression.
- C: had 14.92 GiB free and D: 18.54 GiB free after QA. Original video rows 45 and 47–53 remain unchanged; task-created rows 135, 171, and 202 were retained. No app data was cleared, no app was uninstalled, no AVD userdata was wiped, and no commit/push occurred.

The raw local screenshots, UI hierarchies, and video samples are under `../../../build/prompt03_floating_ball/`. The build directory is Git-ignored. The concise physical-only handoff remains at [`docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md`](../../qa/PHYSICAL_DEVICE_QA_HANDOFF.md); it was not expanded with emulator cases.

## PROMPT03B — UI/UX FOLLOW-UP

**AVD:** Pixel_7 / `emulator-5554`, Android 17 / API 37, 1080×2400 at 420 dpi. Package `com.xrecorder.xrecorder` 0.1.0 (code 1). Workspace and installed APK SHA256: `EA64DF23AD06DFCCF5782FCB6809EFEB95F26DE6C6E8C87040B89AB6F574BF76`.

### Final status

| Gate | Result | Evidence-based note |
|---|---|---|
| LUCIDE ICONS | PASS | Flutter uses existing `lucide_flutter`; native controls use Lucide-style vector assets. |
| FLOATING PANEL UI | PARTIAL | Compact two-row panel is implemented. Timer-only status text is in the installed APK; no post-patch expanded-panel screenshot was captured. |
| IN-APP RECORDING BAR | PARTIAL | Compact footer and state guards are implemented and automated coverage passed; no fresh active-footer device screenshot/sequence. |
| SETTINGS ICONS/GROUP | PASS | Group and distinct `video` / `picture-in-picture-2` icons captured on AVD. |
| HEADER SPACING | PASS | Settings and Editing Studio snapshots show the adjusted spacing. |
| ENGLISH CAPITALIZATION | PASS | Affected English labels use sentence case. |
| TARGETED LOCALIZATION | PARTIAL | Changed translations and placeholder structure checked across 14 ARB files; human RTL/native-speaker review remains. |
| OVERLAY EXCLUDED FROM MP4 | PARTIAL | Explicitly opted-in controls appear in capture; no safe supported per-window exclusion in this MediaProjection architecture. |
| RESPONSIVE UI | PARTIAL | Automated layout tests cover narrow widths/large text; not all native device combinations were run. |
| ACCESSIBILITY | PARTIAL | State descriptions and labels retained; TalkBack/human focus verification not run. |
| FLUTTER REGRESSION | PASS | Full suite: 556 passed; focused follow-up: 66 passed. |
| NATIVE REGRESSION | PASS | `:app:testDebugUnitTest` and debug APK build passed after the timer-label change. |
| SCREENSHOT REGRESSION | PARTIAL | Screenshot UX tests passed within Flutter suite; final Android Screenshot UI case not rerun. |
| DATA PRESERVATION | PASS | No clear/uninstall/reset/deletion. Audio `Mixed Stream`, countdown `3s`, and overlay permission `Not allowed` restored. |

- **Android UI scenarios passed:** 8/16 PASS; 8 PARTIAL; 0 FAIL.
- **Independently full-decoded MP4s:** 3 from Prompt03. The additional task output ID 234 is metadata-validated only and was retained.
- **Changed files:** 74 currently changed files across the Prompt03/03B working set, including the inherited Prompt03 implementation, localization, tests, and reports; no commit or push was made.
- **Remaining defects/limits:** The timer-only overlay label has no post-change AVD screenshot. Overlay exclusion remains a platform limitation; the explicit opt-in behavior remains. In-app footer native visual sequence, 320/360/393/411 dp × 100/150/200% on device, RTL visual QA, TalkBack, and Android Screenshot runtime regression remain unverified.

### PROMPT03B implementation notes

- Native pre-change icons used Android framework drawables (`ic_media_pause`, `ic_menu_close_clear_cancel`, `ic_menu_edit`, `ic_menu_revert`, `ic_menu_delete`, `ic_menu_manage`, `ic_menu_camera`). They now use local `ic_lucide_*.xml` VectorDrawables. Settings uses the existing Lucide Flutter package; no library was added.
- The expanded overlay has a status-dot/timer row with Pause/Resume, Stop, and Collapse; Drawing, Undo, Clear, drawing style, and optional Facecam remain in the secondary row. The word “Recording” is `GONE` visually; the timer’s content description still exposes recording/paused state to screen readers.
- The user’s earlier image of the ball still showing “Recording” was captured before this label patch. The current app-owned change compiled and was installed (matching APK hash above). During the latest test, Android accepted screen-recording consent and ID 234 was finalized, but the notification’s **Show controls in video** action was not selected, so the ball was not shown and the label was not visually rechecked. The Android system chip/notification text is system-owned and remains visible.
- Current Settings group and permission state evidence: `103_settings_tab2.png`, `111_permission_loaded.png`, `114_overlay_permission_denied.png`. Audio/countdown restoration is visible in `106_restored_settings.png` and `107_restored_countdown.png`.
- Localization review was targeted to the changed labels and screen-reader hints; structural checker passed. Suspicious pre-existing text for Prompt11 is recorded in [`PROMPT11_LOCALIZATION_BACKLOG.md`](PROMPT11_LOCALIZATION_BACKLOG.md).
- The final Flutter run resolved the earlier SDK-lock block: 556 tests passed. C: 14.85 GiB free; D: 18.50 GiB free. The full report and U01–U16 matrix are in the companion files.

**PROMPT03B FINAL: PARTIAL** — source/build/test gates pass, but the timer-only overlay has not yet been confirmed in a fresh expanded-ball screenshot, and several requested visual/device gates remain partial.
