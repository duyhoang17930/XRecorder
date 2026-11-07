# P2/P3 implementation progress

Updated 07/11/2026. Continued from baseline
`5cdda32084be772f61153bc453ef3675b932ab41`; no commit/push.
Read the [Vietnamese report](P2_P3_IMPLEMENTATION_REPORT_VI.html) for delivery;
[TEST_EVIDENCE](P2_P3_TEST_EVIDENCE.md) owns commands, results and limitations.

| Milestone | Status | Implemented behavior |
|---|---|---|
| M0 | Complete | Repository/spec/ownership/reuse baseline and 107-test baseline. |
| M1 | Implemented; automated checks pass | Command guards, recovery states, themes, narrow layouts/text200, accessible controls. Human usability is a separate gate. |
| M2 | Implemented; native API36 checks pass | Library/search/5 sorts/cache/observer, verified SAF copy/move, SRT picker, disconnect, static/pinned shortcuts, Trash/Restore. |
| M3 | Implemented; native API36 checks pass | Durable drafts, still/video timeline, trim/split/relink/flip; photo history, EXIF1–8, sRGB, JPEG/PNG/resize. |
| M4 | Implemented; native signal/output checks pass | 8 audio tracks, trim/align/fade/gain/headroom, deep/bright/robot, real RNNoise; timed text/sticker/drawing transforms; shared preview/export; MP4/GIF/cancel/retry. |
| M5 | Implemented; real offline ASR checks pass | whisper.cpp C++/JNI, vi/en/auto, tiny/base/small-q5_1, verified model download/import/remove, progress/cancel, timed cues, review/styles/SRT/burn-in. Silence/auto/cancel/removal regression passes. |
| M6 | Automated/native delivery complete; external acceptance gates remain | Process-kill/journal-write recovery, comparable profile, final host/native regression, debug/unsigned-release APK and packaging checks pass. TalkBack service smoke passes; focus/gesture signoff remains PARTIAL. |

## Evidence checkpoint

- Final source-freeze analyze clean, 138 unit/widget tests pass (27s).
- Twelve real H.264/AAC outputs pass full decode/signal/PTS/pixel tests. Flash/tone
  difference 0 ms on the fixture. RNNoise speech SI-SDR improves 8.04 dB;
  this is signal evidence, not human listening certification.
- EXIF1–8 and DisplayP3→sRGB match independent pixel references; JPEG480×240,
  mixed media, edited audio→ASR→SRT/burn-in and speed2 subtitle timing pass.
- Genuine English/Vietnamese tiny/base/small inference measured. On one FLEURS
  sample, Vietnamese CER: 28.125%/9.375%/0%. Small sampled peak PSS594017KiB.
  Recognition is bounded to 10 minutes per job; no server fallback.
- Actual force-stop during encoding: draft preserved and re-export completed.
  Actual EACCES on journal write: job Failed without publication; Retry completed.
  Two-hour video fails storage preflight before enqueue. No physical disk filling.
- Same1006-image SwiftShader corpus: raster p95 41.138→37.864ms after clipping
  changes, about8% improvement; still above60fps budget on this emulator.
- Vendor reduced1456→145 whisper/ggml CPU inputs; RNNoise18 inputs. No user
  media/draft/model/reference deletion. Five working docs and one HTML report.
- Final main.dart debug APK192045080bytes; unsigned release64936959bytes.
  ThreeABIs, packaged MIT/BSD3 notices and ELF/ZIP16KB checks PASS. QA installed
  with install-r; APK SHA256 values in `build/verification/p2_p3/apk/verification.json`.
- TalkBack16 actually bound with touch exploration enabled. ADB navigation does
  not establish TalkBack focus/gesture proof; low-level input/root unavailable on
  this image. All altered settings restored exactly; physical screen-reader gate remains.

P1 recording/capture/settings/Create boundaries remain unchanged. All QA uses
`emulator-5560 / ThreeHRecorder_Task021`, retaining source and output fixtures.
Physical devices/OEM/SD/API24–35, thermal/battery/leak soak, human listening and
final P1→P2→P3 capture integration remain separate acceptance gates.
