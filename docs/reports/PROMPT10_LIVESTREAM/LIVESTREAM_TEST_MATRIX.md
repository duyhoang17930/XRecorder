# Prompt10 Livestream Test Matrix

**Execution date:** 2026-11-16  
**Fresh current-source receiver cases:** 0/12 executed  
**Overall:** PARTIAL; no fresh network delivery is claimed.

## Environment and execution constraints

| Item | Result |
|---|---|
| ADB device | `emulator-5554`, online, Android 17/API 37, x86_64. |
| AVD identity | `adb emu avd name` returned empty; exact `Pixel_7` identity could not be verified. The existing test helper's identity guard was not bypassed. |
| Installed package | `com.xrecorder.xrecorder` 0.1.0/versionCode 4001, target 36. No install attempted. |
| Candidate APK | Pre-existing profile APK SHA-256 `a495bd41830a12f04290c4a05a29c7fedd1ab9bca245a1fa4d888e90540b25e6`; no build in this turn. |
| Storage | `/data` available 365,780 KiB at preflight and 365,588 KiB at final check. No app capture or media was produced. |
| Receiver | FFmpeg already existed locally; no test listener was active. No receiver was started because the identity-guarded current-source path could not be run safely. |
| Flutter SDK | `D:\Android\flutter\bin\flutter.bat`; cache reports Flutter 3.47.8/Dart 3.13.7. Direct Dart executable returned version. `flutter --version` produced no output and was stopped after >10 seconds. Four existing Flutter-cache `dart.exe` processes were observed; their command lines and the SDK lock could not be inspected because access was denied. No process was killed and no cache was deleted. |
| Gradle | With a temporary local Gradle home and existing offline dependency cache, focused unit-test/instrumentation assembly failed before configuration: `The settings are not yet available for build ':'` in `ResolvedBuildLayout.isBuildDefinitionMissing` / configuration-cache setup. No retry was made after the targeted attempt. |
| Build/install | NOT RUN successfully. No APK generated or installed in this turn. |

The focused Gradle invocation targeted `:app:testDebugUnitTest` with `RtmpEndpointTest` and `LiveCaptureStateTest`, plus `:app:assembleDebugAndroidTest`, using offline mode and disabling configuration cache; it exited 1 with the settings/configuration error above. Flutter tests and analyzer were not run because the Flutter CLI hang/lock state remained unresolved. No Dart files changed.

## Android L01–L12

Status below distinguishes current-turn execution from retained historical evidence. `PARTIAL` means the source or earlier evidence provides useful coverage, but the specified current-source acceptance was not completed.

| Case | Coverage | Status | Evidence / limitation |
|---|---|---|---|
| L01 — screen and settings | Source review of destination, key visibility, configuration, Start/End and live status. | PARTIAL | No current widget test or app interaction; Flutter CLI blocked. |
| L02 — permission accepted/denied | Reviewed fresh consent request path and denial handling. | NOT RUN | No current Android consent flow. |
| L03 — start to private receiver | Receiver harness and FFmpeg are present. | BLOCKED | No current session; exact AVD name missing and build/toolchain blocked. Current-source network delivery is blocked pending a verified target and successful build. |
| L04 — receiver decodes live video | Historical private receiver decoded 167 H.264 frames at 720x1280 over 10.239s. | PARTIAL | Historical candidate only; shared capture source changed after that evidence. |
| L05 — receiver decodes selected audio | Historical receiver decoded AAC-LC mono 48 kHz, 460 frames over 9.813s. | PARTIAL | Source correctness remains unresolved due prior mixed-audio clock/continuity findings; no current speech/tone verification. |
| L06 — stop, cleanup and restart | Code has combined stop/release; historical session completed and transport fixture lifecycle was exercised. | PARTIAL | No fresh stop/restart, zombie-session, or resource observation. |
| L07 — invalid URL/unavailable endpoint | Parser and transport error mapping have focused test source; historical refusal/retry fixture exists. | PARTIAL | Focused Kotlin tests could not run; current app failure UI not exercised. |
| L08 — controlled disconnect/reconnect | Historical transport-only receiver restart reconnected with decoded media; refusal retry was bounded and cancellation worked. | PARTIAL | Not a current MediaProjection/capture reconnect test. |
| L09 — background, lock or system stop | Projection callback and stop cleanup reviewed in source. | NOT RUN | No current system-stop/background interaction. |
| L10 — orientation and responsive UI | Resize callback updates VirtualDisplay while keeping the encoder preset; differing aspect ratio can letterbox. | PARTIAL | No current portrait/landscape run; fixed encoder surface behavior remains a limitation. |
| L11 — coexistence and safe controls | Source prevents a second capture and does not silently stop an unrelated recording; Floating Ball uses the shared session. | PARTIAL | No current UI/service interaction; independent recording + live is unsupported. |
| L12 — preservation, buffers and performance | Bounded queue/cache policy reviewed; data state and disk checked; prior media/projects/models left in place. | PARTIAL | No slow-network/current memory/FPS/bitrate run. `/data` changed by -192 KiB between checks, with no capture output created. |

## Retained receiver evidence (historical only)

The prior private receiver artifacts are `docs/reports/TASK10_20261113/live_main3_output_validation.json`, `live_main3_receiver_media/validation.json`, `live_main3_packet_alignment.json`, `live_main3_display_pixel_validation.json`, and `live_main3_ui_result.json`. They report 167 received/decoded video frames, 460 decoded AAC frames, successful session stop, no stream key in the journal, and a screen-pixel comparison. Historical packet alignment reports about 0.104 ms relative offset between encoded audio/video packet timestamp origins; another audio diagnostic reports source-clock offsets of roughly 379–1,158 ms. These metrics describe different checks and do not cancel the audio continuity concern.

An earlier transport fixture used a synthetic encoded stream and a local FFmpeg receiver, including bounded reconnect/refusal cases. It does not validate live microphone/internal audio capture or current MediaProjection reconnect. These reports are preserved; no old media was transmitted during this turn.

## Acceptance gates G01–G15

| Gate | Status | Basis |
|---|---|---|
| G01 — Livestream screen functional | PARTIAL | Source reviewed; no current interaction. |
| G02 — MediaProjection permissions correct | PARTIAL | Manifest/service/consent/callback source audit matches current Android requirements; no current runtime permission test. |
| G03 — Live capture starts without breaking recording state | PARTIAL | Single-session guard and shared-service flow reviewed; no current start/regression smoke. |
| G04 — Actual video reaches private receiver | PARTIAL | Historical receiver proves prior candidate only; current source not rerun. |
| G05 — Receiver decodes valid video | PARTIAL | Historical H.264 decode; no current candidate. |
| G06 — Supported live audio reaches receiver | PARTIAL | Historical AAC present; current selected-source continuity unresolved. |
| G07 — Receiver decodes valid audio | PARTIAL | Historical AAC decode, but no current receiver and no current source-quality check. |
| G08 — Start/Stop cleanup reliable | PARTIAL | Source cleanup and historical completion; no current lifecycle run. |
| G09 — Invalid destination fails safely | PARTIAL | Parser/test source and previous fixture evidence; no tests/build this turn. |
| G10 — Network disconnect handled safely | PARTIAL | Historical transport-only retry evidence; capture-level reconnect not verified. |
| G11 — Status/progress truthful | PARTIAL | Status is driven by transport callbacks; no fresh receiver confirmation is implied by UI and no current interaction. |
| G12 — Stream key handled privately | PASS (source audit) | Keystore-encrypted explicit save, in-memory endpoint, redacted `toString`, no key in state; QA fixture now generates an ephemeral runtime key, withholds destination values from output, and does not save screenshots. Harness edits not built. |
| G13 — No unbounded buffer growth | PARTIAL | Bounded transport cache and PCM queue in source; no current slow-network/memory run. |
| G14 — Original data/projects/models preserved | PASS | No app data clear, uninstall, install, capture or media mutation; no original media/project/model/grant removal. |
| G15 — No severe shared capture regression | PARTIAL | No product capture code changed, but no current regression smoke. |

## Focused test/tool results

- Flutter widget/unit tests: NOT RUN; Flutter CLI hung on `flutter --version` and cache/lock inspection was denied. No Dart source changed.
- Flutter analyzer: NOT RUN for the same tool limitation.
- Kotlin/JVM tests: NOT RUN; Gradle failed before build configuration with `The settings are not yet available for build ':'`.
- Android instrumentation assembly: NOT RUN; same Gradle failure.
- `git diff --check`: run at finalization; see final handoff.
- Receiver decode: historical evidence retained; no fresh receiver run.
- Test harness privacy edits (runtime-generated destination, output redaction, no screenshots, quiet FFmpeg): not built or executed due the above limitations.

## Preservation

The installed app remained in place. No uninstall, data clear, AVD wipe, model deletion, source-media deletion, project deletion, SAF-grant reset, or preference edit was performed. No livestream source media was captured or sent. Preflight reported an existing `speech_models` directory and no saved livestream credential file in the inspected no-backup area. The repository's source media, projects/drafts, models, and QA receiver artifacts were retained.

## PROMPT 10A - ENVIRONMENT RECOVERY AND CURRENT-SOURCE RECEIVER QA

Device identity is now verified as Pixel_7 from the ADB boot AVD property, `emulator -list-avds`, API/model/fingerprint, and installed package state. This permits safe targeting but does not substitute for a current build.

| Focused case | Prompt10A result | Evidence |
|---|---|---|
| L01 Fresh MediaProjection consent | BLOCKED | No current-source APK was built or installed; no permission flow was started. |
| L02 Private receiver decodes current-source video | BLOCKED | Gradle failed before APK production; no receiver session. Historical H.264 decode remains prior-candidate evidence only. |
| L03 Private receiver decodes selected-source audio | BLOCKED | No current APK/session; no current AAC decode or source-correlation evidence. |
| L04 Stop releases current session and transport | NOT RUN | No session was started. |
| L05 Invalid/unreachable endpoint fails safely | NOT RUN | No current app run; no current-source focused Kotlin test build. |
| L06 Receiver interruption and bounded reconnect | BLOCKED | No current APK/session; historical transport-only reconnect is not capture reconnect proof. |
| L07 Permission denial/system stop cleanup | NOT RUN | No current runtime permission or projection-stop flow. |
| L08 UI status/navigation truthfulness | NOT RUN | No current app interaction. |
| L09 Portrait dimensions/orientation | NOT RUN | No current receiver video. |
| L10 Source/project/model preservation | PASS | No install, app-data operation, capture, or media mutation; app package update time remained `2026-11-16 18:36:24`. Main and pre-existing instrumentation packages were left installed. |

Environment recovery: Flutter 3.47.8/Dart 3.13.7 ran through the existing tools snapshot plus a temporary overlay. `flutter analyze --no-pub` passed with no issues and `flutter test --no-pub test/livestream_test.dart` passed 10/10. Gradle 9.7.1 remained BLOCKED: the settings script evaluated, then the build failed in `ConfigurationCachePromoHandler.runWithoutBuildDefinition` / `ResolvedBuildLayout.isBuildDefinitionMissing` with `The settings are not yet available for build ':'`. No version changes were made. The detailed log and task output are local ignored build artifacts, not receiver evidence.

**Receiver-side evidence:** none for current source. No private listener was started, no stream key/URL was used, and no audio/video packets were sent. Prompt10A did not alter the historical TASK10 receiver artifacts.