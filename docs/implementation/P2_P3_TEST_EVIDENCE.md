# P2/P3 executed checks and evidence

Updated 07/11/2026. Current continuation supersedes historical PARTIAL/BLOCKED
engine/DSP/photo statements. Raw milestone logs and outputs remain under ignored
`build/`; this document indexes proof without duplicating the entire work log.

## Environment and safety

- Baseline `5cdda32084be772f61153bc453ef3675b932ab41`, main, no commit/push.
- Flutter3.47.8/Dart3.13.7; JVM21/JVM target17; Media3 1.11.1; min24/target36.
- Only dedicated `emulator-5560`, AVD `ThreeHRecorder_Task021`, API36 x86_64.
  Current performance comparison uses SwiftShader, 1080×2400/density420≈411dp.
- Flutter CLI sequential. All drive commands include `--no-dds --keep-app-running`.
  No uninstall/clear-data/wipe/reset; main.dart APK restored by install-r at delivery.
- Sources, models and generated media retained. Tests move/trash only explicitly
  created QA fixtures and verify original bytes; they do not run existing trash TTL cleanup.

## Current host and native unit checks

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
# Android Gradle environment uses the repository's configured JBR/SDK.
./gradlew :app:testDebugUnitTest
```

Final source-freeze checks: analyze clean and138 unit/widget PASS (27s); logs
`build/p2_p3_continuation_analyze.log`, `p2_p3_continuation_tests.log`.
Includes existing P1 regression tests; audio/layer validation; trim/Undo full-graph
restoration; long subtitles/styles/retime;320/411dp text200; durable drafts; command
guards; source preservation. Native storage reserve/boundary/overflow:2 PASS,
`build/p2_p3_native_unit.log`.

Baseline M0 was107 tests (`p2_p3_baseline_tests.log`). Subsequent checkpoints
115/120/123/129/131 are historical counts, not additional current tests.

## Native command pattern

```powershell
$env:UI_ARTIFACT_DIRECTORY='build/verification/p2_p3/<area>/native'
flutter drive --no-dds --keep-app-running `
  --driver=test_driver/design_system_driver.dart `
  --target=integration_test/<target>.dart -d emulator-5560
```

Fixtures are synthetic tones/images/video plus genuine JFK and FLEURS speech.
No recorded user media is used. Host FFmpeg/ffprobe are under
`build/task03/ffmpeg`; Pillow and ktfmt are host QA tools only.

## Audio, layers and preview/export

Target `p2_p3_audio_layers_test.dart`:12 actual H.264/AAC MP4 outputs, native
preview play/seek, RNNoise preview and playhead retention after effect edits PASS.
`audio/native/emulator_verification.json` lists exact output URIs.

```powershell
python tool/validate_editor_audio.py
```

`build/verification/p2_p3/audio/signal_validation.json`: all12 full decode,
strict video PTS, duration, gain saturation, legacy+new-track headroom, source
trim, offset/tail silence, linear fades, bright/deep pitch, robot sidebands and
timed layer pixels PASS. Files are pulled from verified QA MediaStore URIs.

- AAC/video duration difference ≤30.708ms; fixture duration≈4.031s.
- Fade RMS ratios at0.2/0.7/3.1/3.7s:0.229/0.758/0.859/0.260.
- Mix440/880Hz amplitudes0.2995/0.2996; robot405/475Hz0.2997/0.2999;
  deep330Hz0.5977. Gain2 saturates rather than wrapping PCM16 sign.
- Flash onset1.000s and tone onset1.000s: **0ms difference** on fixture.
- RNNoise genuine Vietnamese speech+seeded white noise SI-SDR:
  −5.0026→3.0373dB, **+8.0398dB**, alignment9.25→19.25ms.
  Quiet noise RMS ratio0.04151; output frame count/duration retained.
- Layer active-frame pixel differences474/853/938; inactive frames0.

These are actual audible PCM/signal checks, not human listening, broad speech
quality or long-duration lip-sync signoff. RNNoise adds about10ms measured
lookahead on this sample; unprocessed A/V flash test is distinct.

## Offline speech recognition

Target `p2_p3_whisper_test.dart`, genuine upstream multilingual weights:

```powershell
# Default benchmarks tiny/base; small tested separately with ASR_MODELS.
flutter drive <same flags> --target=integration_test/p2_p3_whisper_test.dart `
  --dart-define=ASR_MODELS=small-q5_1 -d emulator-5560
python tool/analyze_whisper_benchmark.py
```

Real native JNI inference, timed vi/en segments and cancellation PASS.
Original benchmark retained in `whisper/native`, `whisper/small` and merged
`whisper/benchmark.json`. Tiny EN/VI8.826/8.749s; base19.849/18.195s;
small49.743/43.625s. VI CER28.125%/9.375%/0%, measured on **one** FLEURS sample.
Small sampled peak PSS594017KiB. This is not broad accuracy or physical performance.

FLEURS vi_vn/test filename10057024225045006889.wav/id1886, CC-BY4.0.
Reference: “Văn hóa và bộ lạc cổ xưa đã bắt đầu giữ những con vật này để dễ lấy
sữa, tóc, thịt, và da.” Attribution/SHA256 in `models/fleurs_vi_fixture.json`.
JFK is genuine upstream public-domain speech. Engine outputs are never replaced
with the references. Silent WAV assertion requires empty segments.

Final regression in `whisper/regression` PASS: vi/en/auto, digital silence,
native cancel and rejection of removal of an active model. Tiny timings in this
run5.476/4.518/7.745s; original cold benchmark retained separately.
Recognition ≤10minutes/job; conservative RAM preflight; CPU only, no upload.

## Photo and subtitle output

Target `p2_p3_photo_subtitle_test.dart` PASS after audio-only ASR/model-store refactor.
`photo/native/emulator_verification.json` and actual MP4 outputs retained.

```powershell
python tool/validate_p2_p3_outputs.py build/verification/p2_p3/photo `
  --ffmpeg-directory build/task03/ffmpeg `
  --native-report build/verification/p2_p3/photo/native/emulator_verification.json `
  --check-subtitle-speed
```

- All8 EXIF orientations:0 mean absolute pixel error against independent reference.
- DisplayP3 ICC→sRGB:0 error on reference fixture.
-3000×1500 alpha decode bounded2048×1024; JPEG480×240 with white alpha backing.
- Real image/video mixed export; long wrapped subtitle/styles; output speed2:
  cues visible0.4/0.65s, absent0.1/1.0/1.5s.
- Edited image+JFK audio track→native audio-only composition→Whisper→reviewed
  cues/SRT→burn-in MP4. `asrComposition:true`, recognized SRT includes “country”.
- Host full decode/strict PTS checks PASS in `photo/validation.json`.

## SAF, MediaStore and shortcuts

Target `p2_p3_platform_test.dart` uses actual DocumentsUI and optional real device
HTTPS model download. Helper operates only the QA picker/launcher:

```powershell
python tool/drive_p2_p3_picker.py --folder P2P3_QA_20261107_final --seconds 240
```

Previous native PASS:1474-byte JPEG verified copy/move, source preserved; UTF-8
SRT65bytes pulled/read exactly; tiny download real byte progress+checksum.
Final expanded regression PASS: audio picker/read duration4000ms, actual launcher
pin confirmation and pinned ID, disconnect then rejected move without source mutation.
Final SRT pulled independently:65 UTF-8 bytes exactly match; `platform/srt_validation.json`.
Current proof lives at `platform/native/emulator_verification.json`.

Failures retained and fixed:

- Real picker exposed P2 request702 collision with P1 consent and704 with Support.
  P2 now uses1701–1705; P1/Support unchanged. `platform/requestcode_collision.log`.
- Expanded audio test found `audioInfo` unreachable inside export-only branch.
  Moved metadata operation to editor worker; actual picker regression rerun.
  `platform/audio_info_routing_failure.log`; corrected actual picker regression PASS.
- Launcher helper initially missed lowercase “home screen”; pin confirmation
  accepted manually on QA launcher, case-insensitive helper fixed and rerun.
  `platform/pin_automation_timeout.log`. Earlier folder automation timeout retained.
- QA System UI ANR dialog occurred during emulator/host load; selected Wait on
  verified dialog, DocumentsUI resumed. This is not labeled an app crash.

Static cold/warm editor/photo deep links passed earlier (`p2_p3_m6_*` evidence).
Physical SD/OEM providers and legacy permission matrix are not certified.

## Recovery and fault injection

`p2_p3_recovery_test.dart` + `tool/p2_p3_recovery_fixture.py` PASS:
actual backup-only AtomicFile recovery, unreadable empty fixture isolation,
>1MiB UTF-8 rejection preserving old draft, PNG Trash→Restore exact bytes,
missing source export Failed/no URI. Fixtures repaired/retained.
`recovery/final/emulator_verification.json` and `p2_p3_recovery_final_native.log`.

`p2_p3_process_recovery_test.dart` + `tool/kill_p2_p3_qa_process.py`:

- Storage preflight: actual sparse7200s video rejected before enqueue; draft intact.
- Force-stop only QA app while native encoder temporary file had402848bytes.
  Reopen with `--dart-define=RECOVERY_RESUME=true`: interrupted job Failed,
  exact draft/source retained, new export completed.
  `process/start`, `process/before_kill.json`, `process/resumed`.
- `--dart-define=IO_FAULT=true` and helper `--io-fault`: actual app files-directory
  EACCES during journal checkpoint. Job Failed/no publication, draft unchanged,
  Retry completed. Mode771 restored by device watchdog and host finally.
  `process/io/injection.json` records restored:true; emulator report passes.
- Final positive MP4/GIF/cancel/retry native regression PASS (17s) in
  `recovery/export-regression`; fresh outputs pulled into `outputs` and full
  decode/strict PTS PASS again (`build/p2_p3_export_decode_final.log`).

No destructive disk filling/ENOSPC test. Exact force-stop at MediaStore commit,
provider power-loss and long leak soak remain unexecuted; preflight/EACCES/process
kill are distinct tests and do not substitute for those windows.

## Comparable library profile

Target `p2_p3_library_profile_test.dart`, profile mode, same1006 images,
30 continuous400ms drags, SwiftShader. `performance/comparison.json`:

| Run | Frames | Build p95ms | Raster p50/p95ms | Raster >16.7ms |
|---|---:|---:|---:|---:|
| Before |641|5.617|22.327 /41.138|418|
| Width only |641|5.661|21.627 /42.333|410|
| Width +hardEdge |652|4.631|19.930 /37.864|400|

Compressed cache269248bytes throughout. Width alone did not improve p95;
hardEdge clipping improves about8%. Raster remains over budget on emulator.
Earlier62-frame midnight profile used a different workload/GPU and is historical,
not a valid before measurement for this comparison. No physical60fps claim.

## Final delivery checks

Final host/native regressions described above PASS. Production entrypoint
`flutter build apk --debug --target lib/main.dart` PASS; unsigned
`flutter build apk --release --target lib/main.dart` PASS (222.1s, three nativeABIs).
All XRECORDER signing environment variables removed in that child process only;
no keys read/requested/stored. Logs `p2_p3_continuation_debug_build.log` and
`p2_p3_continuation_release_build.log`. Missing unused Cupertino font warning
observed; actual app uses Lucide/Material fonts and build succeeds.

`python tool/verify_release.py <APK>` PASS for both APKs. SDK36 zipalign16KB PASS;
aapt min24/target36, threeABIs, release not debuggable. New JNI/libc++ present in
allABIs, packaged MIT/BSD3 notice equals source, no bundled speech models.
apksigner verify exits1/Missing META-INF/MANIFEST.MF as expected for **unsigned**
release. `build/p2_p3_*_packaging.log`, `p2_p3_unsigned_signature.log` and
`apk/verification.json` retain proof/hashes. Main QA installed with install-r on
verified AVD, editor route opened, sources/models/drafts remain.

Real TalkBack16.0.0.738667889 smoke: service bound, touchExplorationEnabled=true,
app active and routes respond. Screenshots/dumpsys in `accessibility/`.
**PARTIAL focus/gesture verification:** ADB tap/swipe and
[documented keyboard shortcuts](https://support.google.com/accessibility/android/answer/6110948?hl=en)
did not establish TalkBack focus proof. Native permission dialog showed real
TalkBack focus; this does not certify Flutter controls. Lower-level sendevent
failed Permission denied; adb root returned “adbd cannot run as root in production
builds”. No code workaround or fake PASS. All four altered secure settings restored
exactly; notification permission/flags unchanged. `accessibility/emulator_verification.json`
records service PASS and focus false. Need authorized physical input/device and
human screen-reader session for full acceptance; no claim of real-user testing.

Final `git diff --check` and protected P1-path diff against baseline PASS.
Generator `tool/write_p2_p3_report.py` gates the single HTML on current evidence,
unchanged P1 paths, restored accessibility settings, packaging and APK freshness.
Source vendor now145 whisper/ggml CPU inputs +18 RNNoise inputs; duplicate ASR
contract/Markdown report and1311 unused vendor files removed. Five working docs
plus one HTML remain; generated outputs/research stay ignored under build/.

External acceptance needs: user-authorized physical Android devices (including
OEM/SD and legacy API), representative speech/listening corpus and human usability
sessions; P1-ready capture build for final P1→P2→P3 run. Independent P2/P3 work does
not wait for that gate. No fabricated transcript/UI-only DONE or production signoff.
