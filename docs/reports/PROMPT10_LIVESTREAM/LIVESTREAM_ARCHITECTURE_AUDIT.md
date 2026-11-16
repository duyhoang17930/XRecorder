# Prompt10 Livestream Architecture Audit

**Audit date:** 2026-11-16  
**Source:** `main` at `cbece07` before this turn's QA-only edits  
**Verdict:** PARTIAL — a real RTMP publishing implementation exists, and retained historical receiver evidence proves a previous candidate delivered decodable media. Current-source end-to-end behavior was not rerun.

## Scope and environment

This audit covers the existing Livestream screen, capture bridge/service, shared video/audio encoders, RTMP transport, permission/lifecycle behavior, focused test infrastructure, and retained Prompt10 evidence. It does not replace the recording engine.

- Connected Android serial: `emulator-5554`; Android 17 / API 37; x86_64.
- `adb emu avd name` returned no name. The connected emulator is therefore not verified as the requested `Pixel_7`; the existing identity-guarded capture harness was not run.
- Installed package: `com.xrecorder.xrecorder`, version `0.1.0` / versionCode `4001`, target SDK 36. No installation or build was performed in this turn.
- Existing profile APK SHA-256: `a495bd41830a12f04290c4a05a29c7fedd1ab9bca245a1fa4d888e90540b25e6`. Its installed-package match was established in preflight; this is not a newly built artifact.
- `/data` available at preflight was 365,780 KiB and at final check 365,588 KiB. No app-generated capture or receiver media was created in this turn.
- Host FFmpeg was already present at `build/task03/ffmpeg/ffmpeg.exe`. No local listener was active at the inspected RTMP test ports. No server/container stack was downloaded or started.

## Capability inventory

| Area | Current implementation | Audit classification |
|---|---|---|
| Livestream UI and navigation | `lib/features/recording/livestream_page.dart`; explicit server/key entry, masked key with reveal control, settings/status and explicit Start/End. No automatic start on screen open. | Existing; source reviewed, current UI interaction not run. |
| Destination persistence | `LiveDestinationStore.kt` stores an explicitly saved secret encrypted with Android Keystore AES-GCM under `noBackupFilesDir`; runtime state keeps the endpoint in memory. | Existing; source reviewed, current save/restore flow not exercised. |
| Protocol | RTMP and RTMPS URL parsing and publish via RootEncoder 2.8.2. No SRT, WebRTC, or HLS output path found. | RTMP implementation exists; RTMPS implementation exists but trusted-certificate success is unverified. |
| Video | MediaProjection VirtualDisplay -> existing `VideoEncoder` Surface -> H.264 encoded output. `LiveCapture` subscribes to those encoded packets; it does not create a second video encoder. | Existing and historically delivered media; current-source delivery unverified. |
| Audio | Existing `SessionAudio` AAC output can be microphone, internal playback, mixed, or muted subject to Android version, permission and source-app capture policy. | Existing; source paths reviewed. Actual source correctness/continuity remains defective or unverified. |
| Transport | `RtmpTransport` passes H.264 SPS/PPS and dimensions/FPS, AAC sample rate/channel metadata, and encoded samples. It uses TLS hostname verification, 5-second socket timeout, at most two library retries, a 90-entry cache, and exposes bytes/bitrate/queue/drop counters. | Existing and bounded by code; no current receiver run. |
| Session coordination | `CaptureBridge` rejects a second active capture, validates the destination before permission flow, and creates a fresh system consent request for each new session. A livestream cannot run concurrently with a separate recording session. | Existing; code-reviewed, race/lifecycle behavior not freshly exercised. |
| Foreground service | Shared `CaptureService` declares MediaProjection plus selected microphone/camera service types and starts with the matching types. Capture remains foreground while active. | Existing; manifest/source reviewed, Android runtime not exercised this turn. |
| Overlay integration | Existing Floating Ball/capture overlays enter the shared encoder output. Floating Ball appearing in the stream is accepted. No independent livestream Facecam/Drawing pipeline was found. | Basic shared overlay path exists; optional compatibility not freshly verified. |
| Receiver and proof | Prior TASK10 harness uses a private RTMP receiver and validates received media. Local FFmpeg exists, but the current run did not start it or capture from the app. | Historical evidence retained; fresh current-source proof missing. |
| Core transport missing? | No core publish protocol is missing in source. Fresh build and current-source receiver verification remain required before calling it complete. | Not a source absence; verification blocked. |

## Data path and ownership

```text
Fresh system capture-consent result
        -> CaptureService / MediaProjection callback
        -> one VirtualDisplay for the selected capture path
        -> VideoEncoder Surface (H.264) -----+
        -> SessionAudio (AAC, if selected) --+-> LiveCapture -> RtmpTransport -> RTMP/RTMPS receiver
                                             +-> existing local MP4/mux path
```

The current product path also saves a local recording while livestreaming and discloses this in the UI. It checks available storage before capture. Live transport failure stops the combined live capture; the service may finalize the local video if capture had already started. This is deliberate shared-session behavior, not a network-only stream.

`RtmpTransport` waits for a video keyframe to establish its timestamp origin, drops earlier non-key video, rejects invalid/negative timestamps and codec-config buffers, then sends codec payloads through RootEncoder. It reports queue and drop counters. The audio mixer aligns source frames by its current capture logic; prior QA found source-clock alignment/continuity problems, so valid AAC framing alone is not proof of the intended sound.

## Session states and UI truth

The capture service uses `idle`, `awaitingPermission`, `countdown`, `starting`, `recording`, `paused`, `stopping`, and `finalizing`. Live transport adds `preparing`, `connecting`, `live`, `reconnecting`, `connection_failed`, `authentication_failed`, `configuration_failed`, `interrupted`, `cancelled`, and `stopped`.

The UI derives its live status and counters from the capture state/event stream. `live` reflects the RTMP client's publish-success callback; it is a transport state, not evidence that a receiver decoded media. The screen exposes sent bytes/bitrate but no live-duration timer was found. The destination key is not included in state snapshots, event maps, or `RtmpEndpoint.toString()`.

## Android MediaProjection and foreground-service audit

The manifest declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, microphone and camera foreground-service permissions; `CaptureService` declares `mediaProjection|microphone|camera`. API 34+ requirements are reflected in the service setup: the bridge obtains a new user-consent result before starting the service, the service obtains the projection from that result, registers `MediaProjection.Callback`, and creates one VirtualDisplay per screen/region capture session. Projection `onStop()` stops the session and enters cleanup. The normal flow does not reuse a consent token.

The resize callback resizes the current VirtualDisplay and keeps the chosen encoder canvas/preset. When aspect ratios differ, the source code documents that content can be letterboxed; orientation behavior was not run in this audit. A selected region is stopped with an explanatory error if the screen coordinate system changes.

The manifest and callback approach is consistent with the [Android MediaProjection guide](https://developer.android.com/media/grow/media-projection) and [foreground-service type requirements](https://developer.android.com/develop/background-work/services/fgs/service-types). This is a source audit, not a fresh API 37 consent/lifecycle test.

## Audio support and limits

- Microphone capture requires `RECORD_AUDIO` and the microphone foreground-service type.
- Internal playback capture requires Android 10+ and is limited by playback-capture policy, usage and source app; protected content may not be captured.
- Mixed mode uses the current `SessionAudio` mixer and AAC output. The implementation uses AAC-LC, 48 kHz mono in the reviewed configuration; transport metadata carries the encoder's reported sample rate/channels.
- The capture pipeline can also run muted/video-only.
- Historical TASK10 investigation found mixed-source clock offsets and audio continuity/overrun concerns. These were not closed by this audit and make current live-source correctness PARTIAL even though receiver-side AAC decode existed for an earlier candidate.

## Security and private QA

The endpoint parser accepts only RTMP/RTMPS host/application-path URLs without embedded userinfo, query or fragment. The stream key is provided separately and is not echoed by validation errors or `toString()`. Saved credentials use Keystore encryption; RootEncoder logging is disabled in the transport, with its protocol logging stripped at the build boundary. No account credentials or live destination secrets were used or placed in this report.

The existing receiver harness has been changed in this worktree so it constructs its private endpoint at runtime, generates an ephemeral key for each invocation, withholds both values from diagnostic output, runs FFmpeg quietly with output discarded, and does not save livestream screenshots. These are QA privacy changes only; Gradle did not build them, and they were not executed.

## Historical receiver evidence boundary

The retained `TASK10_20261113` campaign includes a private receiver capture (`live_main3_receiver_media/received.mp4`) with FFprobe validation: H.264 720x1280, 167 decoded frames over 10.239 seconds, and AAC-LC mono 48 kHz, 460 decoded frames over 9.813 seconds. The matching historical reports also record packet parity and a decoded visible-screen pixel comparison. This is genuine receiver-side evidence for that historical candidate.

The RTMP transport and `LiveCapture` source last changed on 2026-11-14; shared `CaptureService` and `SessionAudio` changed again on 2026-11-15. Therefore the retained receiver file is not proof for the exact current capture/audio source. The current run deliberately did not reuse the earlier task-owned real-media source, did not start a receiver, and did not capture/install a new APK.

## Unsupported or out of scope

- SRT, WebRTC, HLS, and other destination protocols are not implemented.
- Trusted RTMPS certificate success, RTMPS hostname-mismatch behavior, and production service compatibility are not freshly verified.
- Simultaneous independent livestream and recording sessions are not supported.
- Sustained ARM64/hardware performance, long-session thermal/battery behavior, and OEM background policy require physical-device QA.
- Live duration display and dynamic orientation-aware encoder resizing are not established by this audit.

## Files inspected

Primary code: `lib/features/recording/livestream_page.dart`; `lib/features/recording/recording_service.dart`; `android/app/src/main/AndroidManifest.xml`; `android/app/src/main/kotlin/com/xrecorder/xrecorder/live/{LiveCapture.kt,RtmpTransport.kt,RtmpEndpoint.kt,LiveCaptureState.kt,LiveDestinationStore.kt}`; `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/{CaptureService.kt,VideoEncoder.kt,SessionAudio.kt,EncodedOutput.kt,CaptureBridge.kt}`.

Focused test infrastructure: `test/livestream_test.dart`; `android/app/src/test/kotlin/com/xrecorder/xrecorder/live/{RtmpEndpointTest.kt,LiveCaptureStateTest.kt}`; `android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveCaptureAudioInstrumentation.kt`; `docs/reports/TASK10_20261113/live_capture_audio_gate.py`.

## PROMPT 10A - ENVIRONMENT RECOVERY AND CURRENT-SOURCE RECEIVER QA

**Execution date:** 2026-11-17. This section supersedes the earlier AVD-name uncertainty for device identity only; it does not convert historical receiver media into current-source evidence.

- Device identity is high-confidence: `adb devices -l` reports `emulator-5554`; `ro.boot.qemu.avd_name=Pixel_7`; `emulator -list-avds` contains `Pixel_7`; fingerprint is `google/sdk_gphone16k_x86_64/emu64xa16k:17/CP31.260623.012/16064790:user/dev-keys`; model `sdk_gphone16k_x86_64`, API 37. The installed app is `com.xrecorder.xrecorder` 0.1.0/versionCode 4001/target 36, lastUpdateTime `2026-11-16 18:36:24`; no app install/update was performed in Prompt10A.
- Flutter is installed at `D:\Android\flutter` (Flutter 3.47.8, Dart 3.13.7). The normal wrapper cannot acquire/write its SDK cache lock in this environment. Direct invocation of the existing Dart `flutter_tools.snapshot` through an isolated temporary overlay succeeded: `flutter --version --machine`, `flutter analyze --no-pub` (no issues), and `flutter test --no-pub test/livestream_test.dart` (10 tests passed). No SDK reinstall or cache deletion was done.
- Gradle wrapper is 9.7.1. Earlier resolution from the original C: cache failed at Javac with `AccessDeniedException` on Kotlin stdlib 1.8.20. A later offline run used the copied D: dependency cache as the active Gradle user home and did not change dependency/plugin versions. The focused `:app:tasks --offline --no-daemon --stacktrace --debug` diagnostic shows `android/settings.gradle.kts` evaluated successfully; Gradle then fails in its `ConfigurationCachePromoHandler.runWithoutBuildDefinition` / `ResolvedBuildLayout.isBuildDefinitionMissing` path with `IllegalStateException: The settings are not yet available for build ':'`. No project settings line or version incompatibility was identified. APK task did not complete.
- No current-source APK exists, so there is no current APK SHA-256 and no install result. The installed Nov 16 profile APK is historical and was not used as current-source proof.
- No private receiver was started and no livestream session or media transmission occurred. Historical TASK10 H.264/AAC receiver results remain historical-only.
- AVD `/data` availability was about 365,396 KiB at Prompt10A preflight and 356,200 KiB at the latest read-only check (95% used). No device-side build/install/capture was performed; the observed storage delta is not attributed to this work. Host free space was about 4.85 GiB on C: and 7.91 GiB on D: after diagnostics.
- No original media, projects/drafts, Whisper model, preference, SAF grant, app data, or AVD userdata was intentionally changed or removed. The pre-existing main app and `.test` package were left installed. Temporary Android build properties were restored; `android/build.gradle.kts`, `android/gradlew.bat`, and `android/local.properties` match their pre-attempt backups.

Current-source livestream acceptance remains BLOCKED pending a successful Gradle build, in-place APK verification, and a fresh private receiver session.