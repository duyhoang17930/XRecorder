# TASK08 — Executed checks / evidence index

Evidence root: `build/verification/task08/`. Historical failures are retained.
09/11 source HEAD `bad1dc30` plus current targeted changes; full HEAD/protected
hashes are in `m6_source_integrity_v2.json`. This task did not commit that HEAD.
Runtime acceptance uses **v5 main**;v1–v4 are intermediate/non-delivery artifacts.

## Environment / input identity

- Flutter3.47.8/Dart3.13.7,JBR21,AGP9.1.0,Kotlin2.4.0,Gradle9.7.1,
  Media3 1.11.1,whisper.cpp1.9.5;min24/target36. No dependency upgrade.
- API36/34/37.1 x86_64 dedicated QA;SwiftShader,4vCPU,3GiB unless explicitly2GiB.
  Windows shared host; no physical FPS/thermal or human-listening claim.
- Library1013 app-owned rows,17 distinct payloads,15 decoded in workload.
  Ordered metadata hash `3ef335eb6b6ca72a98fca670d4bc1394f70fbe27096d21f434a45e7ba9fae04f`.
  `m0_owned_corpus_evidence.json` records native read-back/source SHA.
- Audio/photo/models59 inputs: `fixture_manifest_v2.json`; final source/model
  proof `m2_source_model_integrity_after_v1.json`. Long waveform
  `m2_long_input_device_v1.json`,SHA256
  `bdbb40920c2bbb74e82e29e0e2fd956f183c8de8301d0819abcb573d3d0087e6`.
  Repeated licensed real FLEURS, not natural10min conversation or fake text.
- Current8 APK bytes/SHA/ABI: `m5_final_apk_manifest_v5.json`. Main universal
  SHA256 `54501d9c54cdea939eb2a60ee2d1d2ad0ad015e1a4b0247c425b805f33748845`.

## Executed results

| Scope / IDs | Result | Exact evidence / limit |
|---|---|---|
|PERF03/04 controlled30swipes,320/411dp|PASS scoped raster/cache improvement|`performance/comparison_320_v1.json`, `comparison_411_v1.json`;3warmup+5trials/raw frames; nearest-rank;build effect INCONCLUSIVE|
|Host drift control|Executed|`performance/drift_control_411_v1.json`;baseline raster40.104ms,not equal to build drift|
|PERF01 Android main launch|Measured,not A/B|`m4_main_launch_api36_v1/metrics_v1.json`;3warmup+5cold/hot trials;Android TotalTime,not first thumbnail|
|MEM01 Arabic/Light/font200|PASS bounded images,corrected harness|`memory/library_ar_light_200_v2/`;measuredTextScale2.0,10cycles,GC1/5/10;16decoded/1557056B constant;raw SHA copies in `m6_allocation_raw_20261109T061022400657Z/`;v1 profiler-retention confound retained separately|
|MEM02/03 preview30,export cancel20|PASS scoped|`memory/editor_soak_v3_offline_checkpoint_v1/`;0active/0release failures,20cancel/source exact|
|Current8-track preview/reload30|PASS v5|`m2_preview_reload_16kb_v4_report.json`;actualSurface frames,30reload/seek,0active/0release failures|
|Dispose during pending load / overlapping requests|PASS v5|`m6_preview_dispose_race_v1_report.json`, `m6_api36_final_v1/preview_report.json`, `m6_api34_final_v1/preview_report.json`;no resurrection/lost callback|
|MEM04 Tiny/Base/Small EN/VI/Auto|PASS9real inferences|`memory/combined_media_memory_v3/emulator_verification.json`;actual native modelLoad/inference timing|
|Repetitive Tiny|PASS10cycles|`m2_tiny_ten_cycles_report_v1.json`;nativeHeap/PSS boundary samples;not whole-app allocation certification|
|MEM06 actual600s boundary|PASS|same combined report,longSpeech:57cues,end600000ms,inference166443ms;600001ms rejected|
|MEM05 actual2GiB/16KB foreground|Controlled inference PASS|`m4_16kb_foreground_2g_v2_report.json`;inference3354ms,model load339ms,5legacy jobs exact;earlier cold-boot LMK retained|
|MEM07/PERF09 actual13audio outputs|PASS finalv5|`m6_audio_final_v5/signal_validation.json`, `validation.json`;gain/fade/voice/RNNoise/8tracks/layer pixels/full decode/strictPTS|
|A/V sync|PASS fixture oracle|same signal report:flash/tone1.000s,0ms difference at10ms-window/30fps resolution;not human lip-sync|
|Photo/subtitle/mixed export|PASS scoped|`m2_outputs_v1/photo/validation.json`;EXIF1–8+P3 MAE0;JPEG480x240;4actualMP4/speed-subtitle pixels;photo code unchanged afterward|
|Edited composition→ASR after fixes|PASS v5|`m6_api36_final_v1/edited_speech_report.json`;country recognized from composed audio,draft exact|
|DATA01–05/10 history0/20/21/77/100/1001|PASS fixture retention/paging/faults|`m3_pagination_green_v1.log`, `m3_history_matrix_metrics_v1.json`;metadata-only fixtures,not fabricated ASR|
|Real process reopen|PASS|`m3_history_process_reopen_v1.log`,API34/16KB `history_reopen.log`;same6 fixture roots/IDs/schema/timings|
|Duplicate ID safety|PASS|`m3_duplicate_regression_v2.log`;readonly/write rejection/original exact|
|Foreign trash inputs|PASS|`m3_trash_regression_v2.log`,secondary `trash.log`;onlymanagedUUID paths may expire|
|Genuine history integrity|PASS scoped|`m6_api36_final_v1/existing_history_integrity.json`19;API34 validation11;`m4_16kb_2g_legacy_integrity_v1.json`5;no replacement transcripts|
|Framework accessibility|PASS5English nav targets|`m6_api36_final_v1/navigation.log`;actual focus,not human spokenTalkBack;Arabic main screenshots separate|
|Final Flutter analysis|PASS|`m6_final_analyze_v2.log`,exit0,no issues42.4s|
|Allocation harness final analysis|PASS|`m6_allocation_final_analyze_v3.log`,exit0,no issues5.5s;production source unchanged after final suites|
|Final Flutter tests|231PASS|`m6_final_flutter_v2.log`,exit0,52s;12locale/layout/settings/persistence/preview/export consumers|
|Android JUnit|12PASS|`m6_final_junit_v5/summary.json`,6suites,0failures;`m6_preview_dispose_race_build_v1.log`|
|Installer/evidence safety unit|9PASS|`m6_final_safety_v3.log`;no uninstall/retry,low-space/personal target reject,tar truncation/one-use checkpoint/report collision|
|Current8 packages|PASS static|`m5_final_apk_manifest_v5.json`;allABI/64bit16KB/licenses;4QA signatures verified,release unsigned|
|Main restore after final soak|PASS scoped|`m6_api36_main_restore_v1/main_integrity_v2.json`;safe install-r,main launch/screenshot,19-job journal/62source-model hashes exact;native locale cache ar→en sync expected,app Settings document absent before/after|
|P1 / source / evidence preservation|PASS snapshot comparison|`m6_source_integrity_v2.json`:18exact/589initial files present,Settingsdiff empty,stageddiff empty,incident image-pathfile exact|

Per-device runtime details are in [DEVICE_MATRIX](TASK_08_DEVICE_MATRIX.md).
Overall DATA remains FAIL/PARTIAL because the earlier SDK uninstall incident
cannot be erased by successful later fixture tests. Full future/corrupt journals
are kept readonly; this is not an automatic schema repair/migration claim.

## Commands used

Checks (PowerShell environment TEMP/TMP set to `build/verification/task08/temp`):

```text
D:/Android/flutter/bin/flutter.bat analyze --no-pub
D:/Android/flutter/bin/flutter.bat test --no-pub --reporter expanded
android/gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebugAndroidTest --offline
python -m unittest discover -s tool/tests -p test_run_qa_existing_app.py -v
python tool/verify_release.py <archived-v5.apk>
apksigner.bat verify --print-certs <QA-v5.apk>
```

Safe runtime workflow: build first,archive with exclusive create,then
`python tool/run_qa_existing_app.py --serial <QAserial> --avd <exactName>
--apk <archivedAPK> --output <newDirectory> --install-only --adb <SDKadb>`.
Drive tests omit install-only and attach the host Dart driver; no Flutter install
fallback. Native CLI requires explicit `TASK08_*_PASS` marker: `am instrument`
can exit0 while reporting a crashed process.

Native dispatch on `.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation`:
`-e task08 history-matrix`, `-e historyReopen <existingIndex>`, `-e task08 trash`,
`-e task08 speech -e speechUri <QAcontentUri> -e speechForeground true`,
`-e task08 preview -e mediaInput <newManifest>`, `-e task08 navigation`.
Inputs/commands/paths retained in the fixture/log directories; do not rerun a
writer into the same evidence directory.

Independent final output commands:

```text
python tool/validate_editor_audio.py --offline --directory build/verification/task08/m6_audio_final_v5
python tool/validate_p2_p3_outputs.py build/verification/task08/m6_audio_final_v5 --ffmpeg-directory build/task03/ffmpeg
python tool/validate_p2_p3_outputs.py build/verification/task08/m2_outputs_v1/photo --ffmpeg-directory build/task03/ffmpeg --check-subtitle-speed
```

These were executed once per fresh directory; existing validation.json or
signal_validation.json now rejects rerun without overwriting it.

## Failures kept / classification

- `m0_profile_320_bounded.log`: actual SDK uninstall on low storage,QA5560 UID
  changed. Recovery partial; [DATA_SAFETY](TASK_08_DATA_SAFETY_REPORT.md).
- Large ADB tar streams were truncated/disconnected,sometimes exit0. Size/SHA/
  tarEOF guards stopped installs. Whole offline checkpoints were copied only
  after verifiedQEMU exit; source/copy SHA exact. No restore or approval bypass.
- First checkpoint reboot lost delayed stopped-state,guard rejected update;
  waited Android persistence and made a **new** checkpoint. New snapshots can
  be consumed once; do not force-stop and reuse a stale backup after new jobs.
- `m3_history_matrix_v1.log`:write-obstruction inserted before AtomicFile read
  recovery; fixture fixed after restore,green and process-reopen retained.
- `m2_audio_signals_v1.log`:8-track A/V80.708ms exceeded80ms. PCM endpoint guard
  fixed it;no tolerance increase. Empty-buffer alias found in native retest,
  fixed with native/JUnit regression (`m2_audio_limit_native_failure_v1.log`).
- `m2_preview_reload_16kb_v2_report.json`:endpoint duration metadata made
  Media3's arbitrary1000s probe infer an unsupported speed effect. Identity time
  mapping for retained samples fixed preview;SDK detector regression added.
- `m2_preview_reload_16kb_v3_report.json`:old synchronous reload release failed
  after4reloads,2release failures. Shared async drain/release fixed30reloads.
  First preview attempt overlapped a device verification; causal conclusion uses
  subsequent isolated reproductions,not that attempt.
- Foreground readiness first used a text-search shortcut instead of traversing
  Flutter virtual nodes;fixed oracle,3GiB real foreground then verified.
- `m4_16kb_foreground_2g_v1.log`:cold-boot cached instrumentation process killed
  before speech fixture/model start;exit-info reasonLOW_MEMORY,importance400.
  Foreground-first + settled boot actual inference passed;failure not erased.
- Release `--no-pub` generated-registrant failure corrected through normal SDK
  regeneration,not file replacement. Initial archive-print cp1252 and relative
  Gradle-wrapper shell errors were harness-only;build/logs kept,not app PASS.
- Main-restore preference oracle v1 assumed all XML bytes stay identical.
  `preferences_probe_v1_failure.json`:native locale cache legitimately syncs
  testArabic to actual main/systemEnglish through existing NativeLocaleSync.
  Corrected scoped integrity report preserves both hashes;no preference patched.

NOT RUN: physical/OEM/SD/TalkBack listening/P1 end-to-end,full-disk filler and
true chmod-based EACCES (forbidden). EISDIR exercises real write-error rollback;
it does not certify every storage failure or power-loss scenario.
