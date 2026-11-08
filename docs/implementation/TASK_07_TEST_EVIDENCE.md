# TASK 07 — Test evidence,08/11/2026

Evidence root: `build/verification/task07/`. Current source is an uncommitted
working tree on `b9aea926c1ab024dd32a139e5ab43b0e0e584908`; prior P2/P3 results
remain historical. No commit, push, release signing or user-data cleanup performed.

| Gate / check | Current result | Evidence |
|---|---|---|
| G0 baseline analyze / tests | PASS, 143 tests | `baseline_analyze.log`, `baseline_tests.log` |
| G0 native scroll profile | PASS on retained QA corpus | `performance_before.log`, `performance/before/emulator_verification.json` |
| G1 ARB structure | PASS, 12 target locales; human review pending | `python tool/check_l10n.py`; current ARBs |
| Settings safety / P1 source | PASS, 17 protected file hashes unchanged; no original file missing | `p1_settings_safety_check.json` |
| G1 current analyze | PASS, no issues | `g1_safety_analyze.log` |
| G1 unit/widget regression | PASS, 160 tests in 22s, including settings persistence and 12 locale loading/direction checks | `g1_safety_tests.log` |
| Photo modal lifecycle regression | PASS, 4 narrow/light/dark/text200 cases | `g1_photo_modal_tests.log` |
| G1 Android locale switching | PASS on API36 x86_64, 12 locale switches, same router/library State, 1013 image IDs retained, no extra query on locale changes | `g1_native.log`, `g1_native/emulator_verification.json`, 12 screenshots |
| G2 Dart catalog / UI / preferences | PASS, full164 tests +30 targeted after retry UI; analyzer clean | `g2_gate_tests.log`, `g2_final_targeted_tests.log`, `g2_final_analyze.log` |
| G2 JVM checks | PASS,5 tests (storage2/cursor1/activity2) | `g2_gate_native_unit.log`, JUnit XML |
| G2 real native benchmark | PASS functional gates,41 before+41 after; detailed quality limitations retained | `g2_native_asr*.log`, `g2_asr_metrics*.json`, `g2_*memory.jsonl` |
| G3 Unicode split/control baseline |5 failures reproduced before patch;17 subtitle/timeline checks PASS after Dart fix | `g3_unicode_before.log`, `g3_unicode_after.log` |
| G3 native Unicode/cache | PASS after real before/fix/after: height cache equivalence false→true, grapheme bridge round-trip false→true, missing glyphs 0/13 | `g3_native_before/`, `g3_native_after/`, original PNGs |
| G3 targeted regression | PASS45 tests, including stale legacy ASR jobs and independent Settings persistence | `g3_targeted.log` |
| G3 real preview/SRT/MP4 | PASS12 MP4s,24 actual Android previews, timed gaps, byte-exact UTF8 SAF SRT including Unicode filename | `g3_outputs_after.log`, `g3_outputs/emulator_verification.json`, `g3_outputs/pixel_metrics.json`, PNG/MP4/SRT artifacts |
| G4 layout baseline | PASS24 combinations:12 locales ×320 dark/411 light,200% text, Settings/navigation/Help and6 dialogs | `g4_layout_before_ready.log` |
| G4 extended layout after fixes | PASS49 checks:48 locale/width/orientation combinations +RTL regression | `g4_layout_final.log` |
| G4 full regression | PASS223 Flutter tests; analyzer clean | `g4_final_all_tests.log`, `g4_final_analyze_after.log` |
| G4 native matrix | PASS API36,108 distinct actual Android screenshots,89 retained/reopened drafts,20 existing job transcripts unchanged | `g4_native_final.log`, `g4_native_final/` |
| G4 TalkBack checkpoint | Service/flags verified; original app-focus attempt interrupted. G6 native framework test below verifies4 real Arabic navigation focus targets with TalkBack active | `g4_native_final/` failures; `g6_native_accessibility/` current native PASS |
| G5 packaging / size | PASS universal +3 complete splits,16KB static checks, actual size analysis; partial ABI negative control rejected | [size report](TASK_07_SIZE_REPORT.md), `g5_*` |
| G6 | Native recovery/ASR/Unicode/main APK verified; performance non-regression OPEN, human/physical/P1 gates separate | Final sections below; [delivery report](TASK_07_FINAL_REPORT_VI.md) |

## Settings safety resolution

Automatic review denied a proposed script that would splice a section from HEAD
into `settings_controller.dart`, because it could overwrite uncommitted work.
**That command was not executed and was not retried.** No destructive Git command
or old-version file reconstruction was used. Read-only status, unstaged diff,
cached diff and the entire current settings file were reviewed again after the
user's explicit safety instruction. Cached settings diff was empty.

The resulting diff contains only additive locale state/accessors, the v2
`appLocale` value, restore/reset/dispose handling and its import. Targeted patches
retain capture fields, accepted stored values, defaults, migration versions,
corrupt/newer-document write protection and `recordingSnapshot` mapping.
Regression tests check round trips, legacy v0/v1 migrations, readonly corrupt/future
documents, all capture snapshot fields through locale changes, and durable system
selection. The initial worktree patch remains retained for comparison.

## Failures found and resolved so far

- Thumbnail benchmark preflight encountered unreadable pre-existing media. The
  harness now records thumbnail failures separately and still measures the same
  retained catalog; no fixture/media was removed to make the test pass.
- Initial router compile failed after extracting copy because its localization
  import was missing; import added and full compilation/tests rerun.
- Localization exposed ancestor lookups during slider/dialog teardown. Slider
  semantics now capture translations/formatters during build; photo discard copy
  uses the dialog's own context. The four actual modal regressions now pass.
- Two English expectations changed deliberately: binary size uses `KiB` and the
  localized layer kind is `Text`. Tests were updated for these display changes;
  serialized effect/layer tokens stay unchanged.

Automated screenshots, unit tests and AVD runs do not certify human translation
quality, real TalkBack usability, physical-device performance or OEM behavior.

G1 screenshots precede a resource-only curation of 24 core labels by the coding
assistant. These changes retain **human review pending** and will be rerun in G4/G6.
G2 settings additions are targeted patches for a separate `speechLanguage`
preference, retaining app locale, capture semantics and version 2. Tests verify
Japanese speech selection survives restore independently of Arabic app locale.

G3 found a real duplicate-composition load: platform-view creation starts a load,
then an explicit load of identical clips/effects replaces Media3's preparing
graph. The retained retry stack reports `CompositionPlayer.setComposition` →
`SequencePlayerHolder.release` → `ExoTimeoutException: Player release timed out`.
The incremental fix deduplicates identical documents, preserves explicit seeks
and error retries, and adds passive native load counts. The12-language native
output test verified12 loads, zero additional release failures and24 real Android
surface captures in2m55s. Independent glyph-mask comparison against original
PNGs and decoded output frames passes: minimum export/oracle coverage99.618%,
minimum actual preview/export coverage97.836% (2px codec/antialiasing tolerance).
Before-cue/gap/after-cue frames contain no rendered text. SRT read-back is3494
bytes and its Arabic/Hindi/Japanese/Chinese/emoji filename is exact. Original
FLEURS model transcripts and manually entered text are unchanged.

The AVD logged Impeller `EGL_BAD_ACCESS` during final surface teardown after
the assertions; do not treat this as physical-device GPU certification. Current
build lifecycle and main-entry APK remain part of G6 verification.

G4's expanded test first needed an idle CaptureScope fixture, complete export
fixture metadata and a real async image-codec settling interval. Those harness
failures are retained separately from product defects. Product failures then
reproduced a70px Trash overflow and23px library-header overflow in Spanish,
French and German at320dp/200% text. Trash header/entries now share a lazy sliver
scroll flow; SectionTitle keeps full heading and trailing content on separate
lines at large text sizes. The48-case retest passes across12 locales,320/360/
411dp and840×411 landscape,150%/200% text, libraries/photo tools/drafts/exports/
mocked trash/Settings/Help and6 editor dialogs. Native trash is not opened
because its existing auto-expiry can delete retained media; this test never
weakens that production behavior to manufacture a pass.

ASR jobs now carry an optional canonical audio/timeline `sourceSignature` in the
existing journal. Titles, locale and subtitle styles do not change that identity;
trim/speed/audio edits do. Older journals remain readable. A legacy completed
job whose cues no longer fit the edited timeline releases the dialog's busy
state without applying/deleting those cues or changing its retained journal.

G4 native used host Android screencaps. FlutterView image conversion before
embedding PlayerView stalled two interrupted harness runs; these are retained
as interrupted, not passes. The surface-capture run passed4m16s. Its first set
had a filename collision between editor and drafts screenshots; distinct names
and a uniqueness assertion fixed the harness. The final run passed4m18s with108
unique captures. It preserved1013 image IDs, the original router/library state
for locale-only changes,89 existing draft documents and all20 current job payloads.
Final display-unit curation after those captures removed additional `s s`/`% %`
duplication; generated resource/placeholder/unit checks and the full223-test
suite pass on those resources. Human translation signoff remains pending.

Pre-TASK07 live ASR jobs are unavailable on the primary API36 AVD: the existing native journal
writer retained only its last20 jobs, and the real G2 benchmark exceeds that
window. The zero count is **not** a legacy-preservation pass. Current journal
bytes were backed up to `transcription_journal_before_retention_fix.json`
(13186 bytes, SHA256 `de012b6cfb07c2b05c47c7f1120f9ac0e3d4e2a0fa564e1a56445af4cdbb9e34`).
G6 removed silent history truncation and verified >20 durable jobs through a
real app restart. A separate API34 clone subsequently retained11 genuine live
pre-TASK07 jobs (see the dated follow-up below). That does not restore primary
API36 jobs already pruned by the former writer.

## G6 checkpoint — 08/11/2026, still in progress

Implemented durable speech history without `takeLast(20)`, strict UTF-8/version
read protection, visible storage warnings and a real retry-save command. Native
completion is exposed only after an exact journal read-back or a storage warning.
Current snapshots are collected inside the write lock. Corrupt/newer data stays
read-only; transcript generation is rejected rather than overwriting it.

Executed on QA5560/API36, profile, `--keep-app-running`:

- `task07_speech_history_test.dart`:20 existing jobs +21 digital-silence jobs,
  all41 durable; force-stop/reopen restores all41 IDs and prior transcript content.
  `g6_history_create/`, `g6_history_reopen/`, corresponding logs.
- `p2_p3_whisper_test.dart`, `ASR_CORPUS/ASR_GLOBAL_CATALOG=true`, models Tiny/Base,
  `task07_g6_manifest.json`:12 jobs PASS3m07s;6 real inference runs EN/VI/fixed/Auto,
  all6 non-speech controls empty, explicit uncertain-speech retry reaches inference,
  cancel/drain/next decode1058ms. This run overlaps QA boot: no speed claim against
  G2. `g6_asr/`;56 retained jobs backed up after the run,32056 bytes,
  SHA256 `8cddc7067ef143e19682a5031472b028a9ec46808f8fc55316109db21fb4ab98`.
- Analyzer clean5.5s (`g6_latest_analyze_retry.log`). Full226 unit/widget tests
  PASS1m58s sequential (`g6_all_tests_retry.log`), including Settings persistence,
  locale/precision cache separation and retained slider semantics callbacks.

The initial full-suite attempt failed compiling a test with Windows `errno112`
in C:\\Users\\dangh\\AppData\\Local\\Temp; it was interrupted after the compiler
failure. No app assertion failure is inferred. QA commands now use process-local
TEMP/TMP under `build/verification/task07/temp` on D:, without cleaning C:.

Performance corpus matches exactly across G0/G6:1013 IDs/size/revisions, dark,
1080x2400/density420, unchanged269248-byte compressed cache and the same unreadable
thumbnail. Before / G6 / G6 formatter-cache build p95:4.612 /17.015 /17.265ms;
raster p95:41.129 /42.538 /47.739ms. The cache does not close the scrolling
regression. Actual formatting microbenchmark5x5000 median193134→154236us
(~20% lower, identical checksum714450). Keep both results; do not claim a library
speedup. Native pre-UI query193.951→1350.996→1539.591ms also worsens; host RAM/disk
pressure was subsequently measured. A controlled final rerun remains required.

API34 read-only boot and a standalone clone both lack the installed app; original
disk hashes match before/after cloning. No live legacy-job retention is claimed.
Archived real VI/EN/Auto payload replay may verify compatibility separately.
Fresh isolated QA16KB boots and reports PAGESIZE16384; JNI/codec runtime checks
are pending. No command has operated on user AVD5554.

G6 regression subsequently found two concrete defects, independently reproduced
before patching:

- Library `_day` used the newly localized date-and-time formatter, splitting one
  calendar day into minute groups. A three-item/two-day widget test failed with
  three headings; targeted `calendarDate` use restores two localized headings.
  `g6_date_heading_before.log` FAIL → `g6_date_heading_after.log`26 tests PASS.
  Additional12-locale checks keep date-only/date-time formats independent.
- Audio exports reached the preview phase, then seek1500→effect edit returned
  position2000. The old immediate poll replaced the requested position with a
  stale native snapshot. Deterministic regression FAIL (`g6_seek_before.log`),
  request preservation/in-flight snapshot revision patch,10 preview/performance
  tests PASS (`g6_seek_after.log`). Native retry/parity is pending; the initial
  native run remains FAIL, not an output-validation pass. Upstream research:
  [pinned CompositionPlayer1.11.1](https://github.com/androidx/media/blob/1.11.1/libraries/transformer/src/main/java/androidx/media3/transformer/CompositionPlayer.java).

After calendar fix, same1013-image profile PASS51s: build p50/p95/p99
3.818/18.700/27.634ms, raster16.718/49.672/80.717ms, query1036.183ms,
cache269248 bytes (`performance/after_calendar_fix/`). The functional grouping fix
does not close the measured frame-time regression. Native pre-UI query variance,
host pagefile/RAM pressure and a nearly full C: disk prevent a clean attribution;
physical-device/stable-host performance acceptance remains OPEN.

### G6 native editor corrections and regression

Actual native failures, fixes and retained artifacts:

1. `g6_audio.log`:12 exports reached the preview phase, then an immediate
   effect edit replaced seek1500 with an older2000ms snapshot. The Dart request
   preservation/revision fix passed the deterministic regression and native
   position assertion. Subsequent native runs exposed a separate player-release
   timeout. Pause/stop alone did not fix it (`g6_audio_stop_retry.log`).
2. Detaching the SurfaceView fixed that release timeout, but reusing its graph
   left video black (`g6_audio_surface_retry/`). Recreating the graph with the
   previous texture-mode fallback still had black output at3500ms
   (`g6_audio_graph_retry/preview_3500.png`). Final preview ownership uses one
   shared pause/stop/detach/release helper, a fresh graph for changed compositions,
   and explicit Android hybrid composition. Locale-only updates still reuse the
   existing preview/document. Native43s and46s state/seek tests passed.
3. Capturing800ms after a fixed1s wait was too early: native diagnostics showed
   BUFFERING and no first frame, whereas later seeks rendered. The harness now
   requires three stable READY/first-frame/position samples, bounded to10s.
   Its retained800ms PNG contains the expected Vietnamese text
   (`g6_audio_ready/preview_800.png`). Strict pixel validation still rejected the
   Android root keyboard-focus outline left by earlier TalkBack TAB QA
   (preview-to-export coverage31.336%, export-to-preview100%). The oracle has
   **not** been relaxed. A canceled DOWN/CANCEL gesture in the blank test scaffold
   is being checked to restore Android touch mode before capture.
4. `g6_photo.log` initially failed with `busy: Speech history is still loading`:
   installed-model availability could precede journal restoration on the first
   request. Native commands now queue behind that initial read without blocking
   main. `g6_photo_retry.log` PASS1m22s:EXIF1–8, color/ICC/JPEG resize, mixed media,
   speed-adjusted subtitle export and real edited-audio ASR burn-in. Independent
   `g6_photo_validation.log`/`g6_photo_outputs/` full decode and2x subtitle pixel
   timing PASS for all four MP4s. Source media and outputs remain retained.

`g6_audio_signals_retry.log` and `g6_audio_retry/signal_validation.json` independently
verify all12 actual MP4s:full decode, audible signal energy, A/V duration bounds,
gain/no PCM wrap, track trim/offset, fades, multitrack mixing, voice transforms,
noise reduction and text/sticker/drawing duration/position/rotation effects.
Real noisy speech SI-SDR improves from−5.003 to3.037dB (+8.040dB). This is not
human listening or lip-sync certification. Later parity attempts reuse these
exact published outputs through a QA-owned manifest rather than re-exporting.

Full source regression after the renderer/startup fixes:
`g6_global_full.log` PASS3m52s,108 unique real ADB captures;12 locales retain
the same EditorPreview state/native load count/playhead. All115 existing draft
documents reopened unchanged,11 timed cues and all57 current jobs preserved,
1015 image IDs unchanged within the run. Two new QA JPEGs were added after the
same1013-item performance measurements; no source was deleted to maintain a
benchmark count. Native Trash is intentionally not opened because it can purge
expired media. Accessibility flags were untouched in this run.

The first `g6_global_native.log` used an incorrect full-matrix define and passed
G1 only21s/12 captures. It is not counted as the108-screen result. The correct
define is `--dart-define=G4_GLOBAL=true`. The last attempted capture helper was
not executed when automatic approval review exhausted its usage quota; after
the stated reset time and the user's continue instruction, reviewed QA commands
resumed normally (`g6_audio_touch_final*`). No approval bypass was used.

G6 renderer final evidence: all four READY/first-frame snapshots passed native
56s (`g6_audio_touch_final.log`). The capture-only outline persisted after the
canceled touch gesture, so its keyboard origin is **unconfirmed**. Measured800ms
mask extras:580/596 are on the outermost pixel of the normalized320x180 capture.
The explicit `--exclude-capture-outline` validator option excludes only that1px,
rejects any fixture whose expected media touches it, and retains the original
>90%/2px coverage checks. Default validation is unchanged. Already-pulled native
outputs are processed with `--offline` after QA5560 was safely stopped.

`g6_audio_interior_validation.log` and
`g6_audio_touch_final/signal_validation.json` PASS:800ms preview/export coverage
94.444%/100%,2500ms99.880%/100%,3500ms100%/100%;1800ms has no layer in either image.
This proves the controlled inset layers, not the excluded1px boundary. The
negative control substitutes the real earlier black800ms capture while keeping
the real MP4s/metadata: expected exit1, zero interior preview pixels
(`g6_audio_negative_control.json`). It is rejected by the same validator/options.

Native JUnit after editor/history fixes PASS7 tests48s; the subsequent RAM guard
tests PASS10 tests46s (`g6_memory_native_unit.log`, JUnit XML files).
QA5560's private files/preferences were backed up read-only before switching
devices:732672 bytes, SHA256
`851ec74a50c4662717b9d998c752ac5c3747bfaf9010d4811508c770c900ea76`.
All57 speech/model jobs were terminal before stopping that dedicated QA AVD.

### Actual16KB/2GiB low-memory finding — fix and executed retests

The fresh QA16KB AVD retains its APK/private fixtures across a real emulator
restart; PAGESIZE16384. The first JNI speech/storage test lost its process during
real Tiny recognition. `dumpsys activity exit-info` records reason3 LOW_MEMORY,
foreground importance100, RSS316MB at08:31:04; crash buffer is empty. This is a
failed2GiB attempt, not a JNI/codec runtime pass. The original865-byte journal,
model and all fixtures survive. The owned `.new` blocking directory from the
interrupted test was verified by its exact marker and **renamed/retained**;
the journal was not overwritten or deleted.

The old192/320/640MiB check omitted Android's reserve. Preflight now budgets the
measured working set with headroom plus system threshold, safety reserve and
duration-based PCM buffers, using overflow-safe arithmetic. Optional persisted
`memoryPreflight` metadata records actual available/required/system/page values;
legacy journals without it remain compatible. Android documents the reserve and
warns that available RAM is not wholly disposable:
[MemoryInfo](https://developer.android.com/reference/android/app/ActivityManager.MemoryInfo).
Natural RAM variation exercised both real admission paths on the2GiB AVD:
813817856 available versus765390848 required admitted Tiny (6084ms inference);
749912064 available rejected before model load/inference (both0ms), with
`low_memory`. The original harness expectations failed for opposite capacity
assumptions; those logs remain failures. Independent assertions against the
actual native journal pass in `g6_16kb_admission_verified.json`. No guarantee
against every OS low-memory kill is claimed.

### 08/11 G6 — completed native recovery,16KB and legacy checks

- `g6_16kb_3g_storage.log` PASS15s after changing only the dedicated AVD's
  runtime RAM to3GiB, retaining data. Actual English FLEURS/Tiny inference6351ms;
  a QA-owned nonempty `.new` directory causes a visible write warning, preserves
  old bytes, and real retry-save durably stores identical cues without another
  inference. Twelve native locale/settings round trips preserve capture values.
  Blocking fixtures were renamed/retained; no user data was deleted.
- `g6_readonly_json`, `g6_readonly_utf8`, `g6_readonly_future`: all PASS, actual
  malformed JSON, invalid UTF8 and version99. Loading/start/retry reject safely;
  injected bytes stay exact. Original five-job journal restored exactly after
  each case from its own verified backup; fault fixtures remain retained.
- `g6_16kb_reopen` PASS after actual emulator restart: all5 jobs, metadata,
  transcripts and native settings document exact. PAGESIZE16384, not an inferred
  static alignment result.
- `g6_16kb_output_validation.json` PASS for actual Media3 H264/AAC output: full
  decode320×180, A/V duration delta20ms, flash1.000s/tone1.010s (10ms difference).
  `g6_16kb_caption_validation.json` checks all120 PTS frames and on/off subtitle
  pixels. `g6_16kb_glyphs` PASS13/13 supported glyph probes, cache equivalence
  and grapheme round-trip. This certifies the tested x86_64 emulator cases;
  physical ARM, human listening and language shaping review remain separate.
- `g6_actual_legacy` PASS API34 clone:11/11 original pre-TASK07 live jobs restored,
  including six real Tiny/Base EN/VI/Auto payloads exactly matching archived
  benchmark segments. No fixture replay or rewritten IDs/timestamps. Original
  journal3869 bytes/SHA256
  `fb4333238c0c8a48dc367cef774f797631a5a46834f9c55e77a5f87f0fabd779`
  remains byte-exact after reopening. All four original API34 AVD disk hashes
  remain unchanged; runtime uses an independent offline clone. Earlier package
  queries were premature; the post-boot install-r exposed the retained data.
- `g6_final_all_tests.log` PASS228 Flutter tests1m51s; analyzer clean8.2s.
  Subsequent harness-only refactor analyzer clean4.6s. Native RAM budgets add
  three meaningful unit cases; all10 JUnit tests PASS46s.
- Formatter microbenchmark now shares `p2_p3_library_profile_test.dart` with
  `PROFILE_FORMAT_ONLY=true`; `g6_format_merged` PASS, checksum714450 preserved.
  The duplicate TASK07-only standalone test file was removed after this pass.
  These timings do not establish full-library performance improvement.

### Final API36 regression and comparable-corpus performance

`g6_asr_final.log` PASS3m16s after the RAM changes:17 benchmark jobs (8 real
inferences,9 empty controls), plus actual uncertain-input override14679ms,
inference cancellation/drain543ms and maximum job-list response116ms. All three
installed models Tiny/Base/Small-q5_1 pass the EN/VI subset; Base also runs Auto.
`g6_final_asr_retention.json` verifies all57 prior job contents/metadata remain
and all77 current jobs are terminal. A strict raw-object comparison initially
failed: one technical phase becomes `restored`, and older missing optional
`memoryPreflight` keys serialize as null. No IDs, transcript, timing, model,
language or previous metadata value was changed; the normalization is recorded.

Three final native profile trials use exactly the original1013 URI/size/revision
rows, asserted against the retained G0 manifest. The real native query still sees
1015 images (two added QA JPEGs); the benchmark adapter filters only its test
presentation and never deletes/changes actual media. Same unreadable thumbnail
1210, dark theme and density2.625; compressed cache269248 bytes, decoded cache
20979520 bytes. `performance/final_summary.json` recalculates nearest-rank p95
for both phases, whereas earlier intermediate notes used different interpolation:

| Profile trial | Frames | Build p95 ms | Raster p95 ms | Query ms |
|---|---:|---:|---:|---:|
| G0 retained baseline (one trial) |655|4.636|41.426|193.951|
| Final1 |602|8.340|43.881|1337.275|
| Final2 |601|7.777|48.926|1120.761|
| Final3 |610|8.202|45.602|923.179|

**Performance non-regression gate remains OPEN.** Final trial-median p95 is
8.202/45.602ms, slower than baseline. Formatter/calendar fixes improve the earlier
intermediate measurements, but do not close this gate. The retained G0 trial,
shared host, software GPU and two additional native rows do not isolate cause.
No FPS, physical-device or universal speedup claim is made. A stuck TASK07-owned
formatter wrapper was positively identified with no child processes and stopped
before final trials; IDE/user emulator/other daemon processes were left alone.

Final SAF execution initially encountered an actual **System UI** ANR overlay,
not an app success. XML/screenshot retained (`g6_saf_system_anr.png`); UIAutomator
also returned137 once. Only the verified Wait button was selected. Native
copy/disconnect results are recorded separately after the picker completes.

## Final main-entry APK, accessibility and source checkpoint

- Final analyzer clean69.8s (`g6_delivery_analyze.log`); ARB validator PASS12.
  Full228 Flutter tests and10 native JUnit precede later test/docs-only changes;
  production source is unchanged by the new native accessibility test.
- Eight final main.dart artifacts pass complete ABI/license/16KB checks. SDK
  zipalign verifies QA/release universal; QA signature valid, release signature
  absence confirmed by expected verifier failure. SHA/size/ABI/versionCode in
  `g6_artifact_manifest.json`; QA/release splits' DEX/AOT/Whisper match their
  respective universal APKs (`g6_*binary_parity.json`).
- Main QA x64 split installs on API36 despite universal being rejected for low
  storage. `g6_main_api36_integrity.json`:77-job journal and116 original project
  files byte-exact; no old file missing/changed. No cleanup/uninstall used.
- Final universal installs and cold-opens on actual16KB API37.1: Arabic UI,
  five-job journal byte-exact, PAGESIZE16384 (`g6_main16_integrity.json`, PNG).
- `g6_saf_safety` PASS1m28s: real DocumentsUI grant,1474-byte verified copy,
  release only the new QA folder, rejected move leaves original bytes and
  transfer journal unchanged. Source and copy retained. The earlier System UI
  ANR/Wait remains separately recorded.

### Screen reader: failed harnesses and actual framework test

Early main-entry scripts encountered the Accessibility Suite notification
prompt, then5 distinct labeled keyboard targets passed when that prompt was
controlled (`g6_main_talkback_no_prompt/result.json`). Their overall runs still
FAIL: accessibility focus stayed on a stale/non-app window. Single-finger ADB
gesture attempts on16KB also FAIL; no physical TalkBack gesture claim is made.
All3 secure settings and the service's original notification permission/flags
were restored exactly, including failed attempts.

Android documents that default UiAutomation suppresses other accessibility
services; this makes concurrent `uiautomator dump` unsuitable for this check.
See [the public API contract](https://developer.android.com/reference/android/app/UiAutomation#FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES).
That explains a harness interference risk; it does not establish every failed
gesture's cause. Final verification uses a tiny9.9KB test-only APK, no dependency,
with `getUiAutomation(FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)` and real
`ACTION_ACCESSIBILITY_FOCUS`. No production/P1 code or manifest changes.

`g6_native_accessibility.log` **PASS**,1 native instrumentation case/4 samples:
actual Arabic Video/Photo/Create/Edit labels match the requested native focus,
with4 real screenshots showing green focus rectangles. TalkBack remains bound
and touch exploration enabled after the test. Main universal/five-job journal
unchanged; exact secure settings and notification permission/flags restored.
`g6_native_accessibility/{host_result.json,instrumentation.txt,focus_0.png…focus_3.png}`.
This is actual automated framework-focus verification, not human listening,
gesture usability, every screen or every locale certification.

Reproduce on an isolated QA AVD only:

```powershell
# From android/, public Android framework only; quoting is required in PowerShell.
.\gradlew.bat :app:assembleDebugAndroidTest '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64'
# From repo root; helper guards QA5564, backs up states and restores them.
python tool/verify_task07_accessibility.py
```

First Gradle invocation failed because unquoted properties were split into a
`.dart` task; quoted build PASS2m08s. Test manifest/runner live under
`android/app/src/androidTest/`; test APK is not a delivery APK and does not
replace main. Existing RNNoise debug-compiler/deprecation warnings are retained.

Cleanup is limited to13 TASK07 one-shot migration helpers, one duplicate
standalone formatter test and3 byte-identical incorrectly named APK aliases;
canonical artifacts and all media/models/drafts/reference assets remain.
`cleanup_manifest.json` and `duplicate_qa_artifacts_cleanup.json` record exact
paths/bytes/SHA. The old HTML/report-writer deletion predates TASK07.

API34 clone also restored to normal main universal: `g6_main34_integrity.json`,
11 genuine legacy jobs byte-exact/SHA256 `fb4333238c0c8a48dc367cef774f797631a5a46834f9c55e77a5f87f0fabd779`,
actual cold launch and screenshot. QA API36/16KB/API34 all retain main APKs;
dedicated AVDs stopped normally with data retained. No command manipulated5554.
`g6_delivery_integrity.json`:17 protected hashes unchanged, no initial file
missing, cached Settings diff empty/31 additive lines; HEAD stillb9aea926.
`g6_final_source_manifest.json`, status/stat/diff-check logs capture the final
working tree. Final host metadata inventory40.922GiB logical, zero stat failures;
`g6_final_workspace_size.json`. No cache/media cleanup used to reduce it.
