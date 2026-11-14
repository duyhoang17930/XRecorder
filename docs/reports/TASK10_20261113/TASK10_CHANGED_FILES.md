# TASK10 changed files ? live

## Latest102-path source checkpoint

Exact current paths/bytes/SHA256:source_back_window_ready_candidate.json. All work remains uncommitted, HEAD unchanged.

- VideoPreviewActivity.kt: preserve original VideoView engine/content URI/playbackState/saved position/48dp Back. Dismiss controls on pause/finish, guard prepared callback after closing, release actual decoder before clearing ownership on finish (onDestroy was delayed). API33 controller-window callback is isolated from API24-32, registered after attachment and cancelled/unregistered on detach. Ui05BPlayerInstrumentation.java retains4original assertions/timeout and adds exact task115/SHA allowance, diagnostics/exit metrics and optional normal edge gesture. No capture/EditProject schema migration. Native159PASS; runtime4PASS/1FAIL(edge gesture). Earlier intermittent system-key failure retained; no blanket navigation acceptance.
- app_ar.arb: correct four existing recording labels (automatic orientation, mixed audio, mute, off); canonical Mute persistence remains unchanged. Full Flutter553PASS, analyzer clean, checkerPASS; actual Arabic page/prefs verification in recording_ar_core_labels_verified.json. Human linguistic approval remains separate.
- Read-only native QA adds encoded video epoch for independent source-cue timing and consent-denial/retry coverage; validators retain original audio thresholds. Existing startup runner now verifies Awake/no keyguard before sampling; no security setting changed.
- Removed only our unsuccessful new seek/Media3 SurfaceView/TextureView changes and new p2_video_preview.xml; no teammate changes discarded. Existing VideoView retained. live_controlled_audio_gate.py now waits for real Flutter controls after normal launch before restoring gain; actual audio17 restoration resumed and byte-exact verified. ASR interruption/retry used existing main UI/engine, with no new inference implementation.

- CapturePcmReader192blocks/384KiB exceeds the existing3s AAC grace. New regression fails the earlier96-block limit and passes192. Existing reader/mixer/AAC engine and schemas remain.
- CaptureService.fail freezes active time before cleanup, persists the terminal duration and retains its matching checkpoint. Before-fix native failure9740 ->0ms retained. Active/paused native failures preserve duration and exact-session inputs/journal across restart; original8drafts/model exact.
- audio_video_settings_screen.dart reuses recordingSettings title; recording_settings_form.dart reuses percentValue/spokenValue for both gain labels/semantics. Existing route/persistence assertions retained; vi/ar teardown regression added. Six notice/validation messages added in all14ARBs; older values preserved. Existing localized no-limit/seconds reused. No settings migration. Alias tests retain valid four pt/pt_BR lexical differences with explicit checks; Arabic Cancel test targets the dialog TextButton.
- Existing native/ADB QA runners extended with static exact-PCM playback, actual packet-ready gate, asynchronous Main return, active/paused failure injection, retained-input hashes, selected transport cases, loopback TLS negative and receiver restart. The installer now reuses the safe main-profile helper. No Android trust/security bypass or new capture framework.
- Main profile ea89b96c7dfc0ecda0087fcaa8b46c1d43faf05588d17a619737a534d6b7db85 installed;55metadata/8original drafts/Tiny and the prior failed-session cache/checkpoint byte-exact.

Initial tree clean. P1 changes are required to fix reproduced setup failures and journal metadata corruption; owner grants full P1 scope in TASK10. Inspected source/contracts/current diffs and consumers before edits. No unrelated active edit or source conflict observed. API/schema/channel/MediaStore identity retained.

- lib/features/recording/recording_selection.dart (new): canonical shared tuple matching + existing setup validator.
- lib/features/recording/recording_setup_sheet.dart: imports/re-exports validator to preserve callers.
- lib/features/settings/recording_settings_form.dart: remove on-open persisted mutation; share canonical tuple matching; auto-stop spacing.
- test/recording_setup_sheet_test.dart: theme-aware drag handle locator and structural48dp target assertion; retain functional assertions. Formatting limited to edited file.
- test/task10_recording_settings_test.dart (new): portrait/landscape tuple consistency, invalid FPS/codec, persisted document unchanged when settings open/close.
- android/.../recording/CaptureConfig.kt: restore historical metadata without live validation (new captures still call existing validator).
- android/.../recording/CaptureJournal.kt: restore countdownRemaining; preserve terminal journal bytes on read.
- android/.../recording/CaptureConfigRestoreTest.kt (new): all-field round-trip and older snapshot defaults.
- lib/l10n/app_en.arb: add39 translator descriptions; translated strings/keys unchanged.
- tool/check_l10n.py: allow valid regional fallback wording, validate keys/placeholders/Unicode.
- docs/reports/TASK10_20261113/: new exclusive report/evidence directory. Historical evidence retained.

RootEncoder2.8.2 transport-only dependency was added after source/license review; scope and attribution are recorded below. No EditProject migration, user media/model/AVD deletion, commit or push.

Checkpoint2 additions:

- CaptureJournal.kt now retains exact-session interrupted inputs/checkpoint and no longer deletes pending/cache/legacy media on startup. Terminal journal runtime round-trip verified byte-exact.
- CaptureRecovery.kt (new): production worker checks app ownership, MP4 structure, native tracks/dimensions and decoded frame (PNG bounds/sample for screenshot); completes an existing valid URI and retains invalid inputs. No missing-moov reconstruction claim.
- MediaOutput.kt: keep pending reference until the completed session is durably saved, closing publication?completed crash window; abort still clears its own pending reference. Editor outputs with journal=false unchanged.
- CaptureRecoveryTest.kt (new):2 ownership/publication-state negative/positive guard tests. Native total141/24suites.
- tool/tests/test_check_l10n.py (new):3 regional-fallback key/placeholder/wording contract tests; Python total19PASS.
- Reports: bounded ADB helper adapted from prior QA for explicit Pixel_7 identity, fresh UI hierarchy checks and exclusive screenshot artifacts; source inventory reuses existing Dart AST tool (500entries,0diagnostics). All native artifacts/backup/media fixtures logged under TASK10 only; model weights absent on this AVD and never deleted.

- Mp4RecoveryEngine.kt: additive caller-owned FileInputStream inspection overload; existing File API retained. Avoid reopening scoped-storage paths. Mp4RecoveryEngineTest.kt adds stream lifetime/non-reopenable pathname regression. Native142PASS; publication-window emulator fixture PASS after initial failure/diagnostic logs retained.

## Exact source/test/tool paths at checkpoint2

- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureJournal.kt`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureRecovery.kt`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/MediaOutput.kt`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngine.kt`
- `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureConfigRestoreTest.kt`
- `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureRecoveryTest.kt`
- `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngineTest.kt`
- `lib/features/recording/recording_selection.dart`
- `lib/features/recording/recording_setup_sheet.dart`
- `lib/features/settings/recording_settings_form.dart`
- `lib/l10n/app_en.arb`
- `test/recording_setup_sheet_test.dart`
- `test/task10_recording_settings_test.dart`
- `tool/check_l10n.py`
- `tool/tests/test_check_l10n.py`

Source hashes and unchanged HEAD/branch: source_checkpoint2.json. All reporting paths are new under docs/reports/TASK10_20261113/. No staged/conflicted/deleted paths.

R5 continuation: FinalizedCapture.kt + FinalizedCaptureTest.kt; CaptureJournal.kt (session/offset ownership, retained latest checkpoint, no cross-session reference inheritance); CaptureRecovery.kt (validated A/V remux, retry, legacy path guards); CaptureService.kt (durable timing, preserve unexpected failures and conditional recovery); CaptureState.kt/CaptureBridge.kt (archive before new session, unchanged channel API); MediaOutput.kt (owned pending reopen, retained failures, legacy journal reference); test-only Task10RecordingInstrumentation.kt + existing Task07AccessibilityInstrumentation.java dispatcher. Source and fixtures preserved; no dependency added.
# Continuation implementation notes

- Native recovery: session-bound finalized timing, guarded pending output reuse/publication, validated A/V remux and preserved unexpected failures; existing channels and journal/session fields retained with additive metadata. See R5 evidence for nine native cases.
- RegionCaptureProcessor reuses existing pinned Media3 Crop and VideoEncoder; no new dependencies. Full-display source is cropped before encoder pixels; source-size change safely saves/stops. CaptureConfig source dimensions are additive metadata. Create and legacy tools now reach RegionCapturePage through optional RegionRecordingService; original RecordingService remains compatible.
- FloatingRecordingControls/DrawingOverlay/FacecamOverlay/CaptureService: expose existing engines, keep Exit above ink, preserve pass-through touch policy, validate camera effects and actual instance state. First toolbar measurement regression recorded and corrected; runtime rerun required.
- Screenshot delay: optional DelayedScreenshotService, separate SettingsController v2 additive field, all screenshot UI entry points and legacy no-argument native API reads the preference. Existing no-argument screenshot method remains available. No project schema migration.
- ARBs: additive region and screenshot copy in14existing files. Linguistic approval is pending. Native P1 copy still requires localization work.
- Existing media output validator retains strict input PTS checks while using original demuxer timing for VFR null-output decode validation.

Current continuation additions: FinalizedCapture short-audio-lead validation/regression; DrawingOverlay stroke-change callback; FacecamOverlay forced layout sizing; capability-consistent audio options;44localized P1 labels with canonical persisted values; generated CaptureText/native capture_strings resources via existing sync_p2_native_l10n.py. See source checkpoint manifest for exact hashes. No new dependency or project migration.

ASR/P3 continuation:transcription_dialog.dart preserves terminal snapshot across picker cancellation/request failure, validates new job acceptance, disables stale-job cancellation during submission;3 regressions added to existing editor_effects_ui_test.dart.14ARB speechLowMemory values corrected without changing key/native memory guard. Legacy studio_create_sheet.dart now links localized offline subtitles to existing editor route; design_system_test.dart verifies navigation/sheet dismissal. No project format migration.

Livestream transport implementation (native verification active):android/build.gradle.kts adds narrowly scoped JitPack group; app/build.gradle.kts pins transport-only RootEncoder RTMP2.8.2 and instruments only com.pedro RTMP/common Android Log calls to prevent stream-key exposure in all variants. Existing capture encoders not replaced. New live/RtmpEndpoint.kt validates/redacts endpoints; live/RtmpTransport.kt uses explicit TLS hostname verification,90-frame nonblocking queue, keyframe gating and2bounded retries.3 pure endpoint tests; native total149/26suites PASS. Existing test runner dispatches new Task10LiveInstrumentation.kt for task-owned-media -> local FFmpeg receiver/refusal/cancel. lib/main.dart plus ROOTENCODER_NOTICE.txt bundle Apache attribution/modification notice; Ktor/coroutines transitive dependencies. Full capture/UI/credential persistence integration remains unfinished and is not exposed as working.

## Destination storage continuation (2026-11-14)

- LiveDestinationStore.kt (new): AES256/GCM AndroidKeyStore with fresh IV, authenticated version header, bounded payload and existing AtomicFile pattern in no_backup. Failed reads, tampering, missing keys and interrupted first writes preserve encrypted data until explicit Forget. No plaintext preferences/journal/logs, no automatic start.
- CaptureBridge.kt: three additive async storage commands reuse the existing worker/disposal guard; old recording/consent interfaces retained. Current dirty capture integration and Dart consumers were inspected before editing. Required to make the product-spec saved destination real; no other active edit observed.
- repositories.dart/recording_service.dart: optional storage interface, existing recording adapters remain compatible. livestream_page.dart: explicit name/Save/Forget confirmation, initial-load and duplicate-operation locks, masked key; manual start remains possible after read failure.
- Task10LiveStoreInstrumentation.kt (new), Task10LiveInstrumentation.kt and livestream_test.dart: actual Keystore negative cases plus meaningful UI preservation/no-auto-start/duplicate guards. design_system_test.dart now checks localized current privacy disclosure with explicit ASR/live/share assertions.
- Reports: canonical stale R4/R5/live/AI rows refreshed; raw historical evidence retained.

References: [Android Keystore](https://developer.android.com/privacy-and-security/keystore), [AtomicFile](https://developer.android.com/reference/android/util/AtomicFile). No hardware-backed security claim is made for the emulator.

## Current exact source path list

SHA256, branch and HEAD: source_live_capture_checkpoint.json. These 93 dirty/untracked source paths include all TASK10 changes from the initially clean tree; no staged changes/conflicts. QA fixture scripts/evidence remain in this reporting directory.

- android/app/build.gradle.kts
- android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task07AccessibilityInstrumentation.java
- android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveInstrumentation.kt
- android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveStoreInstrumentation.kt
- android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10RecordingInstrumentation.kt
- android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10RegionInstrumentation.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/live/LiveCapture.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/live/LiveCaptureState.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/live/LiveDestinationStore.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/live/RtmpEndpoint.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/live/RtmpTransport.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/media/P2Locale.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureBridge.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureJournal.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureRecovery.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureState.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureText.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureTiming.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingOverlay.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/EncodedOutput.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FinalizedCapture.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingRecordingControls.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/MediaOutput.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngine.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/RegionCaptureProcessor.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/SessionAudio.kt
- android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/VideoEncoder.kt
- android/app/src/main/res/values-ar/capture_strings.xml
- android/app/src/main/res/values-b+zh+Hans/capture_strings.xml
- android/app/src/main/res/values-de/capture_strings.xml
- android/app/src/main/res/values-es/capture_strings.xml
- android/app/src/main/res/values-fr/capture_strings.xml
- android/app/src/main/res/values-hi/capture_strings.xml
- android/app/src/main/res/values-in/capture_strings.xml
- android/app/src/main/res/values-ja/capture_strings.xml
- android/app/src/main/res/values-ko/capture_strings.xml
- android/app/src/main/res/values-pt-rBR/capture_strings.xml
- android/app/src/main/res/values-vi/capture_strings.xml
- android/app/src/main/res/values/capture_strings.xml
- android/app/src/test/kotlin/com/xrecorder/xrecorder/live/LiveCaptureStateTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/live/RtmpEndpointTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureConfigRestoreTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureRecoveryTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureTimingTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/FinalizedCaptureTest.kt
- android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngineTest.kt
- android/build.gradle.kts
- assets/licenses/ROOTENCODER_NOTICE.txt
- lib/core/constants/app_icons.dart
- lib/core/domain/repositories.dart
- lib/core/ui/theme/app_theme.dart
- lib/core/widgets/studio_create_sheet.dart
- lib/core/widgets/studio_quick_create.dart
- lib/features/editor/transcription_dialog.dart
- lib/features/recording/livestream_page.dart
- lib/features/recording/recording_selection.dart
- lib/features/recording/recording_service.dart
- lib/features/recording/recording_setup_sheet.dart
- lib/features/recording/region_capture_page.dart
- lib/features/settings/recording_settings_form.dart
- lib/features/settings/settings_controller.dart
- lib/l10n/app_ar.arb
- lib/l10n/app_de.arb
- lib/l10n/app_en.arb
- lib/l10n/app_es.arb
- lib/l10n/app_fr.arb
- lib/l10n/app_hi.arb
- lib/l10n/app_id.arb
- lib/l10n/app_ja.arb
- lib/l10n/app_ko.arb
- lib/l10n/app_pt.arb
- lib/l10n/app_pt_BR.arb
- lib/l10n/app_vi.arb
- lib/l10n/app_zh.arb
- lib/l10n/app_zh_Hans.arb
- lib/l10n/message_catalog.dart
- lib/main.dart
- test/design_system_test.dart
- test/editor_effects_ui_test.dart
- test/livestream_test.dart
- test/localization_test.dart
- test/recording_setup_sheet_test.dart
- test/region_capture_test.dart
- test/screenshot_delay_test.dart
- test/task10_recording_settings_test.dart
- test/ui_ux_06_workflows_test.dart
- tool/check_l10n.py
- tool/sync_p2_native_l10n.py
- tool/tests/test_check_l10n.py
- tool/validate_p2_p3_outputs.py

Recent compatibility notes: original RecordingService/recording constructors/consent contracts retained; optional live/store interfaces and commands only. Settings v2 gains a separate screenshotDelay default; EditProject schema unchanged. Shared theme selects the Lucide back chevron by text direction; region capture reuses BackButtonIcon. Root hero localizes labels at display time, never canonical persisted selections. Arabic Trash wording corrections do not change retention/deletion behavior.

## Photo parity and current audio repair

- lib/features/media/photo_tools_screen.dart: source-image-relative text/stroke/arrow minimums in shared preview/export painter; Star/Heart reuse native geometry and existing snapshots. AppIcons adds existing Lucide sticker glyph;14ARBs add one helper message. test/photo_tools_test.dart adds independent scaled geometry, silhouette/reversed-drag/source-preservation checks. No project/schema/dependency change.
- SessionAudio.kt: inspected current observer-only dirty changes and sole CaptureService consumer; move AudioRecord startup after codec readiness and set existing worker THREAD_PRIORITY_AUDIO to address reproduced buffer overflow. Existing mix/AAC/muxer/observer API retained. Native/regenerated-APK validation pending, no audio acceptance claim yet.
- Task10LiveCaptureAudioInstrumentation.kt/live_capture_audio_gate.py: actual Flutter Start/End and Android consent, production native player for known task115; exact-session cleanup, artifact registration, redacted diagnostics and bounded timestamp samples. Test player entry is a native integration call. live_audio_output_validation.py independently decodes/identifies speech; its failed oracle is retained.
- AudioRecord timing reference consulted: https://developer.android.com/reference/android/media/AudioRecord#getTimestamp(android.media.AudioTimestamp,%20int) ; timing inference remains scoped to executed evidence.

- CapturePcmReader.kt (new) + CapturePcmReaderTest.kt (new): independent high-priority internal PCM reader with96block bounded queue and explicit overflow/source errors. SessionAudio joins it before releasing inputs and drains queued audio on normal stop. Native158tests/28suites PASS; capture verification pending. Existing AAC/mixer/muxer and recording contracts reused.
- Exact source96path hash snapshot before reader additions: source_photo_audio_checkpoint.json; the two new reader paths are additional. No staged/conflicted paths or HEAD changes.

Latest exact98source/test/tool paths and hashes: source_audio_arrival_checkpoint.json. CapturePcmReader buffers are bounded and retain producer arrival timestamps; Mixed mic wait uses that deadline, counts zero-filled missing microphone samples and errors if microphone stops for3s. Strengthened fifth native test now exercises newly discarded pause samples and real resumed blocks; no tests removed. device_qa.py extends the existing bounded installer checks into one reused function, including2MiB metadata cap and no model copies. No schema/API/consent bypass changes.

Current native continuation: SessionAudio starts inputs after AAC ready, uses audio-priority worker and independent bounded CapturePcmReader,64ms arrival-based Mixed mic deadline, explicit source/overflow errors and joined shutdown. Internal read is now blocking; it has not resolved all runtime failures. Added read-only sample counters/queue depth for targeted QA; Android test records real input format and worker stack. No PCM is logged; native158/28suites last completed gate. Existing project/settings schemas and observer constructor overloads retained.

Current main profile f952a5480044bf6feaafde9ad67302f2b8f6e33ea0dd8b244b1cb9b663456e74/60288247B installed: p1_guide_title_profile_install.json. Full552Flutter gate plus final28focused title tests, native159 and current analyzer clean. All100source/test/tool path hashes in source_p1_notices_verified_checkpoint.json. Existing startup runner gains unique attempt/skip-install with installed APK SHA verification; no duplicate reinstall or data/cache clear.
