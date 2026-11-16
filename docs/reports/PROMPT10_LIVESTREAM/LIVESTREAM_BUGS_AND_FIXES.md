# Prompt10 Livestream Bugs and Fixes

**Date:** 2026-11-16  
**Scope:** Current source audit, retained TASK10 defects, and QA harness privacy hardening. No production livestream code was changed in this turn.

## Findings

| ID | Finding | Evidence/status | Action and remaining work |
|---|---|---|---|
| P10-01 | Current-source end-to-end delivery was not demonstrated during this run. | No current APK build/install or receiver session; emulator identity returned no AVD name and Gradle configuration failed. | Marked L03 BLOCKED and L04 PARTIAL based on retained historical-only decode evidence. Re-run on a verified emulator/device and private receiver after the toolchain issue is resolved. |
| P10-02 | Mixed audio source clocks/continuity remain a material risk. | Historical TASK10 diagnostics report mixed-source timing offset and audio overrun/continuity concerns; older receiver AAC decoded, but current source changed afterward. | No speculative mixer rewrite. Require current synthetic tone/speech test, receiver decode, source correlation and A/V drift measurement before audio PASS. |
| P10-03 | Shared capture cadence has known emulator limitations. | Prompt01 historical handoff measured roughly 9 fps under a nominal 30 fps setting and reported longer-session audio-clock movement. | Treat configured FPS as a request only; no current performance number claimed. Hardware encoder and sustained cadence remain physical-device work. |
| P10-04 | Consent screenshot could retain the destination UI behind Android's projection consent sheet. | Existing instrumentation saved consent/player/failure screenshots. A destination can remain visible underneath the system sheet. | Removed screenshot capture from this livestream instrumentation path. The change is not built or run. |
| P10-05 | The retained fixture source contained a fixed private publish address and predictable synthetic key, and process output could retain diagnostics. | Source review found those literals in the Python gate and Android instrumentation. | The gate now assembles its private endpoint at runtime, generates a fresh ephemeral key, redacts both values from captured output/errors, and runs FFmpeg quietly with stdout/stderr discarded. The harness still creates an empty receiver-log artifact for its established output naming. Change is not executed. |
| P10-06 | UI transport success cannot establish media decode. | Source status becomes `live` on RootEncoder publish success. Historical evidence proves receiver decode is possible but is from a prior capture/audio source revision. | Reports distinguish transport-connected state from receiver-side packet/decode proof. No current UI status is represented as network media PASS. |
| P10-07 | Orientation can letterbox because output encoder dimensions remain fixed. | `onCapturedContentResize` resizes the VirtualDisplay but preserves encoder preset; source comment acknowledges aspect-ratio fit. | Documented as current behavior; no projection recreation or renderer rewrite introduced. Verify receiver orientation on portrait/landscape devices. |
| P10-08 | Fresh trusted RTMPS behavior is unknown. | Code enables TLS hostname verification; prior negative self-signed test rejected the untrusted CA. No trusted success or mismatch case was run here. | No TLS bypass added. Keep RTMPS trusted-endpoint checks outstanding. |
| P10-09 | Stream duration is not shown in the audited live status screen. | Reviewed screen presents connection and throughput counters; no duration timer was found. | Record as a product UX limitation. No localization/UI edits made without a runnable Flutter validation path. |

## Existing safeguards confirmed in source

- Destination validation accepts RTMP/RTMPS only, requires a host and application path, rejects userinfo/query/fragment, and does not echo key material in errors.
- The transport validates H.264 and AAC formats, supplies codec metadata, enables TLS host verification, applies a socket timeout, limits retries, and uses bounded packet/cache handling.
- New capture uses a fresh projection-consent intent; service registration includes `MediaProjection.Callback.onStop()` cleanup and only one VirtualDisplay for the selected screen/region path.
- Duplicate capture starts are guarded; the UI does not auto-start; a separate recording is not silently stopped to make room for livestream.
- Saved destination secrets use Keystore AES-GCM in the app's no-backup storage. Endpoint credentials are not serialized in live state snapshots.

These are source findings, not substitutes for the blocked current Android runs.

## Changes in this worktree

1. `android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveCaptureAudioInstrumentation.kt` — removes screenshot capture and redacts runtime URL/key values from UI diagnostics.
2. `docs/reports/TASK10_20261113/live_capture_audio_gate.py` — generates the destination at runtime, redacts values from output/errors, and runs FFmpeg with quiet logging and output discarded.

These edits reduce accidental exposure of destination text in test artifacts. They are QA-only, unbuilt, and unexecuted. No production capture, audio, encoder, transport, UI, or localization file was edited.

## Historical receiver evidence and limitations

The preserved previous-candidate receiver output contains H.264 720x1280 with 167 decoded frames over 10.239 seconds and AAC-LC mono 48 kHz with 460 decoded frames over 9.813 seconds. Historical transport reconnect/refusal tests were transport-fixture tests. They do not establish current projection/audio behavior, device hardware readiness, or audio source fidelity.

Current tests were blocked by an unidentifiable AVD name, Flutter CLI/lock access limitation, and Gradle's pre-configuration `The settings are not yet available for build ':'` failure. The harness changes above therefore still require compilation and review in a working focused build.

## No data changes

This turn did not build/install, start capture, transmit media, modify preferences, clear app data, delete source media/projects/models, alter SAF grants, or overwrite prior QA evidence. The app and historical receiver artifacts remain available for a later verified run.

## PROMPT 10A - ENVIRONMENT RECOVERY AND CURRENT-SOURCE RECEIVER QA

### Reproduced environment blockers and disposition

- The ordinary Flutter wrapper remains unable to use the SDK cache lock in this restricted environment. This was worked around without changing the installed SDK: the existing Dart snapshot under a temporary overlay returned Flutter 3.47.8/Dart 3.13.7, analyzer passed with no issues, and `test/livestream_test.dart` passed 10 tests.
- Gradle 9.7.1 first encountered an access-denied read of the global C: Kotlin stdlib JAR. Switching to the copied, offline D: cache as the active Gradle user home avoided relying on that C: artifact path, but the focused build still failed after `android/settings.gradle.kts` evaluated. The stack identifies Gradle's `ConfigurationCachePromoHandler.runWithoutBuildDefinition` calling `ResolvedBuildLayout.isBuildDefinitionMissing`, which throws `The settings are not yet available for build ':'`. The reported failure is in Gradle internal lifecycle code; no app source line or proven AGP/Kotlin/Gradle incompatibility was found.
- No APK was produced and no install, current-source receiver session, media transmission, or production livestream source change occurred. Therefore no livestream code defect was reproduced or fixed in Prompt10A. The prior receiver decode remains historical-only for the current `CaptureService`/`SessionAudio` source.
- AVD identity is now verified as `Pixel_7` using `ro.boot.qemu.avd_name`, `emulator -list-avds`, fingerprint/model/API, and package identity. The installed app remained 0.1.0/versionCode 4001/target 36 with last update `2026-11-16 18:36:24`.
- Device `/data` was about 365,396 KiB free at preflight and 356,200 KiB at the latest read-only check. No device-side build/install/capture was performed; this difference is not attributed to Prompt10A. C:/D: host free space after diagnostics was approximately 4.85/7.91 GiB.
- Original media, projects/drafts, Tiny Whisper model, preferences, SAF grants, AVD userdata, installed main app, and pre-existing `.test` package were preserved. Temporary `local.properties`/Gradle build-dir/wrapper edits were restored from pre-attempt backups. Dependency/plugin versions were not changed.

### Current result

Prompt10A Android receiver QA is BLOCKED at APK build. Flutter analysis and the 10 focused Dart tests pass, but there is no current APK hash, install result, receiver packet/decode evidence, or current lifecycle/reconnect result. Continue only after the Gradle build can run successfully in a correctly permissioned environment; do not treat a transport connection or historical TASK10 media as a current-source PASS.