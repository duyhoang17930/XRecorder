# Prompt 09B — Export integration final handoff

**Date:** 2026-11-16  
**Verdict:** **PARTIAL** — export queue reliability defect fixed, bounded real MP4/GIF outputs validated, and protected project/model/source data preserved. Video ordering/transforms, audio separation, subtitle pixels/SRT timing, process-death recovery and runtime Flutter UI remain partially or not verified.

## ENVIRONMENT

ADB DEVICE: `emulator-5554`, Pixel_7 AVD, x86_64  
ANDROID VERSION: Android 17 / API 37  
GIT STATE: No commit/push/reset/clean/stash. Production source and task instrumentation changed; three Prompt09B reports and the physical QA handoff changed.  
FINAL APK SHA-256: `A495BD41830A12F04290C4A05A29C7FEDD1AB9BCA245A1FA4D888E90540B25E6` (installed profile x86_64 base APK)  
APK INSTALL: `adb install -r` succeeded in place; package ID remained `com.xrecorder.xrecorder`, versionName `0.1.0`, ABI split versionCode `4001`. No uninstall/clear.  
FREE STORAGE BEFORE / AFTER: 384,778,240 bytes before first export / approximately 374,603,776 bytes after all Prompt09B exports (365,824 KiB free).  

## EXPORT QUEUE

QUEUE: PASS — one active Media3 Transformer, insertion-ordered waiting jobs, stable UUID identity, durable AtomicFile job snapshots and cap of ten active/queued/finalizing jobs.  
PROGRESS: PASS — observed queued/running/finalizing/completed transitions and progress samples; UI code caps early native 100% at 99 until completion.  
MULTIPLE JOBS: PASS — active plus queued job; queued cancellation; later jobs serialized.  
CANCEL QUEUED: PASS — terminal cancelled state, no URI/publication.  
CANCEL RUNNING: PARTIAL — cancel request left no completed URI and same-ID retry succeeded. Immediate MediaCodec teardown/resource-release timing was not measured.  
RETRY: PASS — both the running-cancel job and the original cache-purge failed job retried under their same IDs; each produced one independently decodable MediaStore output. Invalid source retry remained failed without a row.  
FAILURE RECOVERY: PARTIAL — the original cache-purge failed job recovered with a same-ID retry; invalid source and synthetic pending-row/journal-write fault scenarios were also covered. Actual process death/restart and revoked SAF access were not run. Queue startup marks interrupted jobs failed/retryable; it may restore a non-pending nonempty row without a full decode.  
APP RESTART BEHAVIOR: PARTIAL — code and synthetic history recovery inspected; process-death test prerequisite did not match current retained SAF tree, so no real kill/restart export claim. No foreground export service; UI tells users to keep the app open.  

## VIDEO

MULTI-CLIP MP4: PARTIAL — output row 709, 577,156 bytes, H.264 320×180, 11.000 s; 264 buffers / 22,809,600 decoded bytes to MediaCodec EOS. Requested second-half then first-half edit order was serialized, but frames were not matched to source timestamps.  
TRIM/SPLIT/REORDER: PARTIAL — split halves were encoded in requested reorder; independent scene/order check remains. Existing source trim support is implemented.  
CROP/ROTATE/FLIP: PARTIAL — output row 710 reflected 20% crop in 256×180 output; rotation/flip were requested but not pixel-inspected.  
SPEED: PARTIAL — 1.25× output duration was 8.800 s and fully decoded; cue retiming was manually applied in this test, so this does not validate untouched saved subtitle mapping at speed.  
AUDIO MIXING: PARTIAL — AAC decoded to EOS. Added WAV had strong normalized correlation (0.771 max, about 14 ms near requested 3,500 ms offset); source video audio was not isolated from the mix.  
A/V ALIGNMENT: PARTIAL — video/audio track durations differed by 36 ms for the multi-clip output and 44 ms for the retry output. No full-program drift analysis was performed.  
FULL VIDEO DECODE: PASS — six real MP4 outputs across task runs reached Android MediaCodec EOS. This is device decoder evidence, not an FFmpeg validation.  
AUDIO DECODE: PASS — tested AAC tracks reached EOS.  
SUBTITLE BURN-IN: PARTIAL — saved cues entered the composition and MP4 decoded; pixel appearance/timestamps and combined-edit time mapping were not independently checked.  

## OTHER FORMATS

GIF: PASS — two real GIF outputs were checked across task runs; current GIF row 711 is GIF89a, 160×90, 11,000 ms, 900,986 bytes, and Android animation decoding sampled multiple distinct frames.  
SRT: PARTIAL — no fresh Prompt09B SRT was emitted from the saved draft. Prompt08’s independently parsed UTF-8 SRT PASS is historical evidence only; no Whisper inference was repeated.  
PNG/JPEG REGRESSION: NOT RERUN — only the MP4/GIF temp file path changed; image export/publication source was not affected. Prompt07A historical PNG/JPEG PASS retained.  

## PERSISTENCE AND SAFETY

MEDIASTORE: PASS — six new MP4/two GIF rows across task runs were app-owned, had expected MIME/name and nonzero bytes, and `is_pending=0`; current totals are 31 video rows and 343 image rows, with no pending rows. Retry did not duplicate output.  
LIBRARY VISIBILITY: PARTIAL — output rows and URIs were queryable; Flutter Library UI visibility was not exercised.  
ORIGINAL SOURCES: PASS — selected video and added WAV SHA-256 values unchanged. No source URI was written or replaced.  
ORIGINAL PROJECTS: PASS — all 12 Prompt09A project hashes rechecked and matched. Target task project SHA remained `92a317b5ea6b8410dcba48e78f02bac7cd82baf3da256ffca907f8294d3d1c7e`; 14 project JSONs remain.  
WHISPER MODEL: PASS — original Tiny model SHA unchanged; no inference was run.  
PREFERENCES: PASS — seven preference hashes matched before/after.  
SAF GRANTS: PASS — persisted grant list matched before/after; no grant reset/revoke.  
TEMPORARY FILE HANDLING: PASS after fix — encoder temp now uses `files/export_work`, is removed on completion/failure/cancel/recovery, and an active-file assertion passed. This fixes the reproduced Android cache purge.  

## EVIDENCE

REAL MP4 OUTPUTS VERIFIED: 6 fully decoded to EOS  
REAL GIF OUTPUTS VERIFIED: 2 animation-decoded  
REAL SRT OUTPUTS VERIFIED: 0 in Prompt09B; Prompt08 historical pass retained  
ANDROID CASES PASS: 5/12; seven PARTIAL  
FOCUSED FLUTTER TESTS: NOT RUN — Flutter CLI/version invocation hung >2 minutes; no existing Dart processes were killed.  
FOCUSED NATIVE TESTS: 6/6 Kotlin/JVM tests; 11/11 export-history instrumentation assertions; 5/5 export integration cases plus original failed-job retry PASS.  
ANALYZER: NOT RUN — Flutter CLI hang.  
FILES CHANGED: `android/app/src/main/kotlin/com/xrecorder/xrecorder/editor/ExportQueue.kt`; `android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task07AccessibilityInstrumentation.java`; new `Task09BExportIntegrationInstrumentation.java`; the three reports in this directory; and `docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md`.  

KNOWN DEFECTS: Global-speed subtitle cue mapping remains unproven and may reject cues that extend beyond the shortened output timeline. Output-frame verification for clip order/rotate/flip/burn-in and independent audio source/drift measurement remain gaps.  
BLOCKED/NOT RUN: Real process-death/restart export (pre-existing test's SAF-tree precondition mismatched the retained grant); Flutter test/analyzer; fresh saved-project SRT; Library-screen visibility; physical-device export behavior.  
FOLLOW-UP FOR PROMPT14: Verify on ARM64/OEM hardware with different encoder implementations, sustained/thermal and bounded long exports, low-storage OEM behavior, background restrictions, and the export-specific cases appended to the physical-device handoff.  

## Acceptance gates

G01 PASS · G02 PASS · G03 PARTIAL · G04 PASS · G05 PARTIAL · G06 PARTIAL · G07 PARTIAL · G08 PARTIAL · G09 PARTIAL · G10 PASS · G11 PASS · G12 PASS · G13 PASS · G14 PARTIAL · G15 PASS.

The export reliability objective has concrete current output evidence and the reproduced cache-loss defect is fixed. The overall Prompt09B verdict remains **PARTIAL** until the explicitly listed mapping, lifecycle and UI evidence gaps are closed.
