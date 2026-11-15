# Prompt02 Screenshot - bugs and fixes

## Summary

**Result: PARTIAL.** The Create-sheet localization/delay issue from the prior Prompt02 checkpoint is fixed. The current profile candidate passed the runtime Screenshot paths, consent/cancel/retry, all supported delays, rotation, MediaStore, Library, Photo Editor, active-request tap suppression, and the saved `View` action. No reproducible Screenshot P0/P1 defect remains. S15 stays PARTIAL because this AVD has no safe `FLAG_SECURE` fixture.

## Action and native-path inventory

| User action/state | Current implementation | Runtime evidence |
|---|---|---|
| Video Library Screenshot quick action | `StudioLibraryQuickActions` -> `requestLibraryScreenshot` -> `CaptureController.screenshot` | URI `/62`; repeated use also produced S01-S14 cases |
| Create (`+`) sheet Screenshot | `openQuickCreate` -> same `requestLibraryScreenshot` path | URI `/70`; exactly one new screenshot row |
| Recording settings Screenshot action | `RecordingSetupSheet` -> `CaptureController.screenshot(delay)` | URI `/71`; exactly one new screenshot row |
| Permission and timing | `CaptureBridge` -> fresh Android MediaProjection consent -> `CaptureService` countdown | Accepted and cancelled through the system dialog; delays 1/3/5/10 seconds |
| Pixels and output | `ImageReader` -> `ScreenshotPixels` row packing -> PNG encode -> `MediaOutput` validation/commit | 15 PNGs fully decoded and compared byte-for-byte with MediaStore reads |
| Cancel and notification | In-app `cancelScreenshot` or notification Cancel -> shared native cancel path | S06/S07 idle with no URI/new row; no stale countdown notification |
| Saved feedback and viewer | Capture event -> `CaptureController` feedback -> `/photo-preview/:id` | Background return showed Saved/View; View opened the actual `/69` PNG |

`CaptureBridge` explicitly requests default-display capture for Screenshot. The Android consent picker offered "Share entire screen"; its "Share one app" choice was marked "Not supported by the app". No Screenshot Floating Ball control is exposed by the current contract. `openStudioCreate`/`StudioQuickTools` has no production caller in the current source; the live Create (`+`) route was tested instead.

## B02-01 - Create Screenshot action localization and dispatch

- **Observed issue:** The older Create tools component used a literal English Screenshot label and read the configured delay after beginning sheet dismissal.
- **Root cause:** The component did not use the existing ARB key at its action boundary; the async callback could outlive its sheet context before reading the delay.
- **Changed files:** `lib/core/widgets/studio_create_sheet.dart`, `lib/features/recording/recording_service.dart`, `test/refinement_test.dart`.
- **Fix:** Use the existing localized Screenshot label; capture the selected delay before dismissing; use localized countdown accessibility text and Cancel.
- **Actual validation:** Focused Create/Screenshot/localization tests 94 PASS; full Flutter baseline 554 PASS; current focused regression 49 PASS and analyzer clean. Real Create (`+`) screenshot URI `/70` and Recording settings URI `/71` each produced exactly one valid PNG. The old `openStudioCreate` widget dispatch is also covered by the host regression.
- **Remaining limitation:** No `FLAG_SECURE` content fixture was available; see S15.

## B02-02 - ADB transport blocker (historical; resolved)

- **Observed issue:** The earlier checkpoint had no online ADB transport.
- **Resolution:** The user started the existing `Pixel_7`; it booted without wipe/restart. Current identity is serial `emulator-5554`, API 37, model `sdk_gphone16k_x86_64`.
- **Candidate:** Profile APK `com.xrecorder.xrecorder` 0.1.0, 116,518,593 bytes, SHA-256 `C0BE5E78E1C3F7E17675C051BC2C7CA9EAE9BD6FC2C85059ACF651B418CD4307`; installed with `adb install -r`.
- **Actual validation:** 15/16 Android cases PASS and S15 PARTIAL; 15 Screenshot PNGs passed full FFmpeg decode, dimension/signature checks, and byte-exact MediaStore readback. Controlled Settings capture matched a fresh reference at 99.6789% exact pixels (mean channel difference 0.43215).
- **Remaining limitation:** No safe secure-window fixture. App-window capture is not an exposed Screenshot mode; the system picker explicitly reports it unsupported by the app.

## B02-03 - isolated QA helper expected a TASK10 registry

- **Observed issue:** The first reused helper completed S01, then failed before writing its timeline because the isolated Prompt02 evidence directory had no TASK10 registry file.
- **Root cause:** The helper assumed it ran in the historical TASK10 report directory.
- **Changed files:** Only ignored `build/prompt02_screenshot/screenshot_acceptance.py`; no app source.
- **Actual validation:** Recovered S01 from its native journal and MediaStore URI; all subsequent capture cases and the final preservation audit passed.
- **Remaining limitation:** None for the app. The first S01 consent-to-capture timeline was not retained by that helper run.

## Runtime and regression notes

- Every new request used the Android consent flow. Consent Cancel, in-app Cancel, notification Cancel, process interruption, and retry left no broken/pending output.
- Three taps during an accepted countdown left the same native session active; it completed with exactly one new Screenshot row (`/72`).
- Photo Editor copy `/60` is a valid 922x2048 PNG, MIME `image/png`, pending 0. The original Screenshot `/59` remained byte-exact; the existing editor export cap is 2048 px on the long edge.
- Final preservation audit: eight project drafts byte-exact; four original MediaStore images retained metadata and SHA-256; no unexpected private changes or pending media; effective delay restored to 3s. The only private-file change was Android's `files/profileInstalled` runtime optimization marker.
- Current focused tests: Flutter 49 PASS; native screenshot pixels/timing/request/notification tests 28 PASS; analyzer clean. Historical full baseline remains Flutter 554 and native 161 PASS / 28 suites. No dedicated Screenshot Android instrumentation class exists; the actual projection/consent path was exercised on Pixel_7 through ordinary Android UI. Unrelated Recording-only instrumentation was not run.
- No reproducible platform capture defect required an external workaround or code patch in this continuation. Prompt01 recording audio continuity, A/V sync and cadence remain outside Screenshot scope and unchanged.
