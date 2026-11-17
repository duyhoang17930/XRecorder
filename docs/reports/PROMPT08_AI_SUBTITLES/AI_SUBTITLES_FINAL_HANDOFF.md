# Prompt08 AI Subtitles Final Handoff

## Environment

- ADB device: emulator-5554, Pixel_7 AVD
- Android version: 17 / API 37, x86_64
- Source commit/worktree: 9f5dcc9f38c3a2050b263e4cd41adeb745d28ae6 plus the listed Prompt08 changes
- Final APK SHA-256: B822F2234D2C5D0FC3EF87B922CDC0EAE9A8D5895DAE2EA6C60F2E59354B7A6C
- Install result: adb install -r succeeded in place; version 0.1.0; no uninstall or app-data clear
- Free storage: /data 649,856 KiB before and 428,136 KiB after; removable SDCARD 442,998 KiB after

## ASR engine

| Field | Result |
|---|---|
| whisper.cpp version | v1.9.5, commit d1be6fde11ac6e0407606b4e42fe72d34add8037 |
| JNI load | PASS on x86_64 AVD |
| Supported packaged ABIs | arm64-v8a, armeabi-v7a, x86_64; only x86_64 was runtime-tested |
| Model detection | 1 task-imported local Tiny model verified after import; no app model was installed at preflight |
| Model import | PASS for checksum-matching Tiny via Android document picker |
| Model download | NOT RUN |
| Model removal | Runtime NOT RUN; explicit-confirmation path covered by Flutter widget test |
| Model selection | PASS; Tiny selected for inference and persistence tested |
| Vietnamese ASR | NOT RUN |
| English ASR | PARTIAL; Auto detected English and produced the known English transcript; forced-English mode not run |
| Auto language | PASS for English detection on the real fixture |
| Audio preprocessing | PASS for AAC-in-MP4 speech fixture; mono 16 kHz output path inferred from successful binding execution. Other channel/codec cases not run |
| Timestamp accuracy | PARTIAL; one valid 0–11 s segment, no word-level alignment claim |
| Cancel/retry | Android runtime NOT RUN |
| Persistent jobs | Completed result persisted and was reviewable. Process interruption/recovery NOT RUN |

## Subtitles and export

| Field | Result |
|---|---|
| Cue editing | PASS: edited text and end, split cue, manual Vietnamese phrase |
| Project persistence | PASS: reopened the saved Editing Studio draft and recovered both cues |
| Timeline integration | PASS for a single untrimmed source clip starting at project time zero |
| Timing through edits | PARTIAL: trim, split clips, reorder and speed mapping not tested |
| Unicode | PASS for manually entered Vietnamese in editor, SRT and burned preview |
| Styling | PASS for the existing default white text/dark background; full style matrix not run |
| SRT export/parse | PASS: 2-cue UTF-8 SRT, sequential numbering and valid comma-millisecond times |
| MP4 burn-in | PASS: actual exported MP4 showed cue 1 at start, cue 2 at about 6 seconds, and no caption after the cue interval |
| MP4 video decode | PASS through Android AVC playback to 00:11 |
| MP4 audio decode | PASS through Android AAC playback to end; 176,576 frames delivered |
| FFprobe / independent FFmpeg decode | NOT RUN; host tools unavailable |
| Original source preserved | PASS: task source SHA-256 unchanged; output is a new MediaStore item |

## Real evidence

- Local model verified: 1. Tiny, 77,691,713 bytes; SHA-256 be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21.
- Real ASR jobs completed: 1. Job speech_1794804798563641; model Tiny; Auto detected English; 11.171 seconds total. Transcript words matched the available reference.
- Real SRT files verified: 1. Prompt08Cue20261116.srt, 195 bytes, SHA-256 E0A13EA645E92ACFACBAF74A9291017104369FD14EA20A4934DD8BD76B2BC233.
- Real MP4 burn-in outputs verified: 1. MediaStore ID 636, 597,551 bytes, 11,036 ms, SHA-256 69A7ECCCAE6622CA0B80AD720CFE12AEA7DC2F002774B071C0676410BFBED933.
- Android cases: 9 PASS / 10; A10 NOT RUN.
- Focused Flutter tests: 32/32 PASS.
- Focused native JVM tests: 7/7 PASS.
- Flutter analyze: PASS, no issues. Dart formatting: PASS. Localization generation/key coverage: PASS across 14 locales. git diff --check: PASS.
- Original project preservation: 10/10 baseline project hashes match. Two task-owned project drafts remain.

## Files changed

- lib/features/settings/settings_controller.dart — validated, persisted preferred speech model.
- lib/features/editor/transcription_dialog.dart — restore/save selected model and confirm model deletion.
- lib/l10n/app_*.arb — confirmation localization in 14 locales.
- test/settings_persistence_test.dart and test/transcription_model_safety_test.dart — persistence and removal safety regressions.
- docs/reports/PROMPT08_AI_SUBTITLES/ — audit, test matrix, bugs/fixes and this handoff.
- docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md — hardware-specific ASR follow-up cases.

## Known limitations and remaining work

- Run real Vietnamese and forced-English recognition against suitable short local speech fixtures.
- Exercise runtime cancellation, retry, invalid/no-audio inputs, interrupted-job recovery, download/import failure and model removal.
- Verify cue mapping through trim, split, reorder and speed edits.
- Run the hardware-specific tests on a physical ARM64 device later; emulator results are not device performance claims.
- FFprobe/FFmpeg were unavailable, so those independent checks remain unverified even though Android playback decoded AVC/AAC to the end and pixel evidence confirms the burn-in.
- No user media, original project, installed preexisting model, SAF grant or preferences were deleted. The original Prompt05__SS folder selection, Auto language, Base model selection and English-only keyboard layout were restored. Imported task Tiny and unique task outputs/drafts remain for review.

## Physical device QA

NOT RUN. Hardware-specific cases are listed in docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md.

## Final verdict

PROMPT08: PARTIAL. The core offline ASR → editable cues → persisted project → valid SRT and real MP4 pixel burn-in flow passed on the AVD. Remaining language, lifecycle, timeline-mapping and physical-device checks are explicit above.
