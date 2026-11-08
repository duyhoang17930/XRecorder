# P2/P3 executed checks and evidence

Updated07/11/2026. Current quality baseline b9aea926c1ab024dd32a139e5ab43b0e0e584908.
All paths below are relative to `build/verification/final_p2_p3/` unless explicitly
marked historical. No commit/push; no uninstall/clear-data/wipe. Sources and QA
outputs/models retained. Flutter CLI sequential, drive always keeps app running.

## Current host checkpoint

- `flutter analyze --no-pub`: final clean,3.7s (`delivery_source_analyze.log`).
- `flutter test --no-pub --reporter expanded`:143 PASS,26s (`delivery_tests.log`).
- Android `gradlew :app:testDebugUnitTest`:3 JUnit PASS,23s (`native_unit.log`;
  build/app/test-results/testDebugUnitTest/*.xml). Includes legacy GIF/JPEG policy.
- Scoped Dart/ktfmt formatting; Python tools parsed/exercised. P1 SHA256 baseline
  contains16 files; final integrity report is recorded at delivery.

Earlier host checkpoints138/142 are historical counts, not extra current tests.
An analyzer brace warning and missing rendering import were corrected; failed
attempt logs remain. No silent skip counted as PASS.

## Native command pattern

```powershell
$env:UI_ARTIFACT_DIRECTORY='build/verification/final_p2_p3/<area>/native'
flutter drive --no-dds --keep-app-running --driver=test_driver/design_system_driver.dart --target=integration_test/<target>.dart -d emulator-5560
```

Only QA AVD ThreeHRecorder_Task021/API36 uses5560. API34 testing uses the new
ThreeHRecorder_Final_API34/5562. User emulator5554 is never operated. Final
main.dart APK is installed with `adb install -r` after integration targets.

## Library and UX

- `p2_p3_library_profile_test.dart`, profile mode, three before/after trials.
 1009 identical images,30 timed drags400ms each. Raw frames/cache/VM traces in
 `performance/before_1..3`, `after_1..3`; `comparison.json`. Median per-trial
 raster p95 43.711 to40.515ms; ranges overlap. Not60fps/physical proof.
- `p2_p3_catalog_stress_test.dart`, current1012-image catalog,30 instant drags
 and4 theme/text-scale screenshots at each width. `ux/320`, `ux/411`; real PNG
 dimensions840x2400 and1080x2400, DPR2.625. No new fixtures seeded. This is a
 different workload from the profile experiment; do not compare timings causally.
- Widget regressions cover320/411dp text200 editor dialogs, command guards,
 stale poll and metadata, crop/rotation aspect, ASR installed/default/restore.
- Preview images `matrix/portrait_before_clean.png`, `portrait_hybrid.png`,
 `portrait_after.png`: player position500ms; SurfaceView embedding fix makes
 the independently decoded white frame visible. `portrait_before.png` contains
 System UI ANR and is not accepted as clean visual proof.

## Real media/audio/layers/subtitles

- `p2_p3_audio_layers_test.dart`:12 new H264/AAC outputs, real preview processing,
 effect reload/playhead preservation PASS. `audio/native`, `audio.log`.
- `python tool/validate_editor_audio.py --directory build/verification/final_p2_p3/audio --check-preview-parity`
 requires host Pillow (`PYTHONPATH=build/qa_python`). All12 full decode, duration,
 PTS/signals/fades/headroom/gain saturation/trim/pitch/RNNoise and timed pixels
 PASS; `audio/signal_validation.json`, `audio_signals_parity.log`.
- Native preview screenshots at800/1800/2500/3500ms compare with actual exported
 frames: symmetric2px layer-mask coverage >=94.4%, inactive frame empty. QA debug
 banner excluded; not bit-identical or human listening proof.
- Same target `P2_P3_MATRIX=true`:six input cases; `matrix/before`, `outputs_before`.
 `validate_p2_p3_outputs.py ... --check-input-matrix`: full decode, strict PTS,
 0/10ms flash/tone offsets at0.5/3/5.5s, distinct stereo tones, silent source,
 200ms duration,60-to24 cap and rotation metadata PASS.
- `MATRIX_CODECS=true`:H264 source and Media3 upstream1s HEVC/B-frame fixture
 export PASS; `matrix/codecs`, `codec_outputs/validation.json`. Upstream URL and
 SHA retained in `matrix/hevc_source.json`; not bundled in APK.
- `p2_p3_photo_subtitle_test.dart`:EXIF1-8 actual pixels + catalog dimensions,
 DisplayP3/sRGB, alpha/2048 decode, JPEG480x240, mixed media, long styles,
 edited audio to ASR/SRT/burn-in PASS (`photo/native`, `photo.log`).
 `validate_p2_p3_outputs.py ... --check-subtitle-speed`:4 full-decode outputs;
 speed2 cue pixels0/16170/16171/0/0 at0.1/0.4/0.65/1/1.5s.
- `p2_p3_native_test.dart --dart-define=P2_P3_ADVANCED=true`:catalog/rename/draft,
 real MP4/GIF, queue cancel/retry PASS (`outputs/native`, `native.log`). Pulled
 files full-decode/PTS PASS (`outputs/validation.json`); GIF90x160,10 frames,
 200ms/frame, loop2 verified with Pillow.

## Offline ASR

- Corpus mode `p2_p3_whisper_test.dart --dart-define=ASR_CORPUS=true`:38 jobs,
35 actual JNI inferences,12 stimuli. `asr/corpus_native.log`, `corpus_native`,
`corpus/manifest.json`, `evaluation.json`;222 sampled memory rows in `asr/memory.json`.
- `analyze_whisper_benchmark.py --prepare-corpus OUT` retains licensed originals,
reference/hash; `--evaluate-corpus OUT --native-report REPORT --output JSON`
computes disclosed CER/WER/RTF and deduplicates repeated samples.
- `--dart-define=ASR_MODELS=tiny --dart-define=MODEL_FAULTS=true`: invalid import,
actual import byte-progress cancellation, old verified model retention, silence,
vi/en/auto, active-model removal rejection and native abort PASS (`asr/faults`).
Measured drain+next decode9616ms exposed slow cancellation despite2ms UI response.
- Local whisper scheduler abort-propagation patch, then
`--dart-define=ASR_MODELS=tiny,base,small-q5_1 --dart-define=MODEL_FAULTS=true`:
9 uncancelled multilingual jobs + cancellation/fault controls PASS;
request8ms, drain+next decode518ms (`asr/faults_after`). Same inference math/params.
- Rejected file URI originally left a queued job: real before failure
`asr/invalid_request_before.log`, corrected corpus regression PASS. Default Base,
installed-model fallback and restored language/model have widget regression.
- Small music-control caption `(Bell)` retained as a quality limitation. Regions,
all speakers/long-form accuracy and human listening are not certified.

## SAF, data safety and lifecycle

- Actual DocumentsUI `p2_p3_platform_test.dart` + `drive_p2_p3_picker.py --folder
P2P3_QA_QUALITY_20261107 --log build/verification/final_p2_p3/platform.log` PASS.
Verified copy/move, source bytes intact, real audio picker4000ms, SRT65 exact
UTF8 bytes pulled independently, tiny HTTPS download48 progress samples/checksum,
pinned ID and disconnected destination rejection. `platform/native`,
`platform/srt_validation.json`, `platform_picker.log`. Existing pinned ID may
already be present; prior-task fresh launcher consent proof is historical.
- `p2_p3_recovery_test.dart` + `p2_p3_recovery_fixture.py --log .../recovery.log`:
new QA-only backup/corrupt fixture, >1MiB UTF8 rejection, exact source/trash/restore,
missing-source Failed PASS. `recovery/native`, `recovery_injection.log`.
- `p2_p3_process_recovery_test.dart --dart-define=PUBLICATION_REPLAY=true`, then
`kill_p2_p3_qa_process.py --publication-replay`, resume with
`--dart-define=PUBLICATION_RESUME=true`: real published URI, simulated finalizing
checkpoint, actual process stop/restart, no duplicate and exact source/draft PASS.
`publication/before`, `after`, `injection.json`. Not an instruction-level commit kill.
- Soak modes of `p2_p3_native_test.dart`:initial active-view assertions missed
release timeouts found in log. Release-before-detach attempt FAIL (`soak_release_order`).
Pause+stop before detach/release:30 previews/20 actual Transformer cancels PASS,
releaseFailures0, max741ms (`soak/stopped`, `soak_stopped.log`). Explicit retained
heap/class/source-string observations are in `soak_stopped_retained.json` and
`soak_retained_strings.json`; no universal leak-free claim.

## Historical proof retained separately

Under `build/verification/p2_p3/`:actual encoding force-stop/re-export, EACCES on
journal parent with restoration watchdog,7200s sparse-input storage preflight,
AtomicFile/SAF/model tests, earlier APK checks and TalkBack16 service smoke.
These are previous-task executions, not fresh runtime PASS on every current build.
No current ExportQueue/recording changes invalidate those contracts; current
publication/recovery/positive export regressions are listed above. Actual disk
filling, power loss, SD/OEM, human focus/gestures/listening remain NOT RUN.

## Delivery

Device-specific results and external gates: [DEVICE_MATRIX](P2_P3_DEVICE_MATRIX.md).
APK hashes/entrypoint/packaging and P1 integrity: final quality report and
`apk/verification.json`, `source_integrity.json`. Debug192045080bytes; unsigned
release64954063bytes. ThreeABIs, native notices, no speech weights, ELF/ZIP16KiB
and SDK zipalign PASS. Release has no integration-test plugin; debug main.dart
kernel has no QA harness markers. No user release signing material used.
Failed release `--no-pub` attempt retained: stale generated integration-test
registrant. Regenerate through the normal Flutter build, never hand-edit it.

Final `main_smoke.json`: actual main APK Video/Photo/Editing Studio/Settings
routes verified with unique screen content; capture not invoked. First editor
matcher used a grouped tile label and was corrected to the unique screen title.
`publication/readback_replay.json`: stronger checkpoint read-back plus main APK
real Export queue initialization recovers the same URI; all other jobs, row
count, source and draft unchanged. Initial host expectation of eager startup
recovery was corrected: ExportQueue is deliberately lazy on first queue access.
The fault helper now uses file-sync and exact checkpoint read-back.

API34 current additions: native catalog/rename/drafts/MP4/GIF/retry PASS, H264/HEVC
outputs full decode PASS,6 real Tiny/Base vi/en/auto jobs + silence/cancel PASS
(request3ms, drain+next decode515ms). `api34_*` logs and `api34/` reports. External
fixture EACCES and binary-stdin truncation were harness failures; corrected with
adb file-sync plus app-UID private copy and SHA256 before running. No chmod/root.
Warm portrait screenshot after native/Flutter settle is clean; earlier stale-overlay
capture retained, not accepted as visual PASS. Main APK installed with-r afterward.
