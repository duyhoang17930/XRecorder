# Phase 13 — Release hardening and remaining gates

Implementation hardening is complete for the current local feature set; this is **not production release signoff**. P10/P12 remain explicitly deferred by the owner under [issue #1](https://github.com/duyhoang17930/XRecorder/issues/1).

## Changes

- Android API 24 minimum and API 36 target are explicit. Recording, microphone, camera and overlay access remain scoped to requested capture tools; no broad storage permission or Internet permission is present in the release APK. Media3 contributes network-state/wake-lock declarations, which do not grant Internet access.
- Private preferences, journals, project references and trash are excluded from cloud backup and device transfer; cleartext traffic is disabled. Published MediaStore files remain subject to the user's separate gallery/backup settings. See [privacy description](PRIVACY.md).
- Removed packaged reference/sample media and unused demo widgets. Hidden AI/live, account/monetization, floating recording controls and shake settings cannot simulate success. Region editing is clearly post-capture; English/dark resources only.
- Bundled Manrope OFL, Apache-2.0, checker-qual upstream license and resolved Android runtime inventory in the app license registry. Flutter/Dart notices use Flutter's generated registry. No FFmpeg runtime is included.
- Release signing no longer uses debug keys. All four `XRECORDER_STORE_FILE`, `XRECORDER_STORE_PASSWORD`, `XRECORDER_KEY_ALIAS`, `XRECORDER_KEY_PASSWORD` environment variables are required together; omitting all builds an unsigned artifact. Signing files are ignored by Git.
- Added `tool/verify_release.py` to check license/sample packaging and native 64-bit ELF/ZIP 16 KB alignment.

## Verification

On 2026-11-04: analyzer clean; 18 host tests passed. The host suite covers persistence corruption/retry, native-state truthfulness, catalog errors/tab state, non-destructive edits and speed-aware split, image pixels, help search, support consent, compact screens and large text. Phase-specific API 36 integrations cover recording/audio/pause, screenshot/facecam, media actions/playback, editor/export and support handoff; P2 also ran on API 37. See individual phase evidence documents for precise coverage and limits.

`flutter build apk --release` produced an unsigned universal APK (~52 MB). `tool/verify_release.py` and SDK `zipalign -c -P 16 4` passed. Packaged ARM64 and x86_64 libraries have 65536-byte ELF LOAD alignment; ARMv7 libapp uses 16384 and libflutter 65536. `apksigner verify` correctly fails because no signing credentials were supplied. This does not constitute a 16 KB device boot test. Build emitted a Flutter Cupertino font tree-shaker warning; the Android app uses Material icons and no Cupertino UI.

Final release APK SHA-256: `23BDCB830512B729651272A1AAA5D1468D7106D57483324809114A41CD1A3654`. Manifest inspection confirmed min 24 / target 36, backup disabled, extraction rules present, cleartext disabled and no debuggable flag.

The API 36 interrupted-export fixture test passed: an injected running-job journal recovered as failed/retryable with no output URI, its incomplete temporary was removed, and an unrelated sentinel file was preserved. This exercises journal recovery without introducing a production test-only channel; it does not substitute for killing a real encoder during MediaStore publication. Reproduce with `flutter test integration_test/export_recovery_test.dart -d emulator-5556` and, while it waits, `python tool/seed_export_recovery.py` on a disposable debug test install. The helper refuses to overwrite existing export history.

The final editor integration also passed missing-source failure without an output URI or source mutation, and portrait export. Independent inspection of `phase13-portrait.mp4` reports H.264 1280×720 with a -90° display matrix, exactly 3 seconds, and AAC 3.004626 seconds. FFmpeg full decode and an extracted frame confirmed upright 720×1280 display. The test run required dismissing an emulator System UI ANR after host build-memory contention; this is recorded rather than counted as physical reliability evidence.

## Open production gates

| Gate | Current evidence / remaining work |
|---|---|
| Physical device matrix | API 36/37 emulator evidence only. Run API 24/28 legacy storage, 29/30 audio, 33 notifications, 34+ consent/FGS on physical devices. |
| Sustained recording | 125-second emulator capture decoded; physical thermal, battery, long recording, device-lock and competing-camera/mic tests remain. |
| Audio quality | Four recording modes and edited audio pipelines execute; audible mixed gain/noise suppression/pitch/music and long A/V sync require physical assessment. |
| Fault injection | Additional low-disk, provider revocation, process-kill during trash/restore/publication and encoder failure scenarios remain. Recovery must never remove published originals. |
| Accessibility | Compact/large-text widget tests passed; TalkBack focus, contrast, touch targets and device accessibility review remain. No untranslated locales/RTL are offered. |
| Release identity | Resolve XRecorder versus product-spec 3HRecorder, final icon/application ID and store text with the owner. |
| Distribution | Supply production signing credentials, review the final license inventory/privacy policy/store disclosures, test a signed install/update and a real 16 KB device, then approve publication. Nothing was pushed or published. |

The source implementation and phase commits are reviewable. These gates must stay open until the corresponding hardware, credentials and owner decisions are available; emulator results must not be relabeled as physical certification.
