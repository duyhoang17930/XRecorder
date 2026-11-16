# Prompt08 AI Subtitles Test Matrix

## Environment

- Device: emulator-5554, Pixel_7 AVD, Android 17/API 37, x86_64.
- Source baseline: 9f5dcc9f38c3a2050b263e4cd41adeb745d28ae6 plus the Prompt08 worktree changes.
- APK: com.xrecorder.xrecorder 0.1.0; SHA-256 B822F2234D2C5D0FC3EF87B922CDC0EAE9A8D5895DAE2EA6C60F2E59354B7A6C. Installed in place with adb install -r.
- Free storage: /data 649,856 KiB before; 428,136 KiB after. Removable SDCARD 442,998 KiB after.
- Host validation tools: FFmpeg and FFprobe were not installed.

## Android A01–A10

| ID | Status | Direct evidence |
|---|---|---|
| A01 Open AI Subtitles from Video Editor | PASS | Opened Subtitles from the Video Editor for the task source project. |
| A02 Detect an installed model | PASS | Imported Tiny through the Android document picker; native model manager reported it installed and verified. App-private file hash matches the pinned Tiny hash. |
| A03 Select model and language | PASS | Selected Tiny and Auto Detect for the real job. The job recorded model=tiny and language=auto. Selection persistence was tested, then the original/default Base preference and Auto language were restored. |
| A04 Real local ASR | PASS | Job speech_1794804798563641 completed on the 11-second AAC-in-MP4 source with local Tiny. The returned English words match the available reference transcript. |
| A05 Review and correct cues | PASS | Reviewed the result, edited text and end time, split into two cues, and previewed the first and second cues. |
| A06 Edit and persist | PASS | Applied edits, left the editor, reopened the task draft from Editing Studio, and reopened Subtitles. Both edited cue texts and 0–5.4s / 5.4–10.8s boundaries were present. |
| A07 Export and parse SRT | PASS | Wrote Prompt08Cue20261116.srt to the task SAF folder. Independent host checks verified UTF-8, cue count, numbering, timestamp format/range, blank separator and Vietnamese text. |
| A08 Add cues to Video Editor timeline | PASS | The saved project contains both cues. Editor preview showed the first cue at 0 and second cue around 6 seconds. This is a one-clip, zero-offset case only. |
| A09 Export and decode MP4 burn-in | PASS | New app-owned MediaStore MP4 ID 636 was opened and played to 00:11. Actual decoded output showed cue 1 at the start, cue 2 at about 6 seconds including Vietnamese diacritics, and no caption at the end. Android logs show AVC and AAC decoders; no FFmpeg/FFprobe validation was available. |
| A10 Controlled cancel/error and retry | NOT RUN | No Android cancellation or invalid-source recovery was induced. Flutter model-removal confirmation tests passed but do not substitute for an ASR cancellation run. |

## Real ASR record

- Source: task-owned Prompt08SpeechQA/Prompt08_ASR_JFK_20261116.mp4, content URI under the removable SDCARD SAF tree; 11,000 ms; source SHA-256 99226db5e4dab095797869a36faab9626e92fd111fa086363729af266b4c6a0d.
- Model: Tiny, 77,691,713 bytes, SHA-256 be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21.
- Language: Auto Detect; detected/result language: en.
- Result: one segment at 0–11,000 ms. It matched the available reference words; punctuation was subsequently edited by the user.
- Timing: model output is clip-wide. Word-level timestamp accuracy was not established.
- Time: model load 205 ms; inference 9,780 ms; total 11,171 ms. Emulator CPU performance is not a physical-device benchmark.

## Output verification

### SRT

- URI: content://com.android.externalstorage.documents/tree/0000-0000%3AMovies%2FPrompt08SpeechQA/document/0000-0000%3AMovies%2FPrompt08SpeechQA%2FPrompt08Cue20261116.srt
- Size: 195 bytes.
- SHA-256: E0A13EA645E92ACFACBAF74A9291017104369FD14EA20A4934DD8BD76B2BC233.
- Parsed cues: 2; sequence 1–2; valid start/end ranges; UTF-8; “Xin chào Việt Nam!” survives serialization.

### MP4

- MediaStore ID: 636; app-owned; pending flag 0; Movies/XRecorder/Edited_85c99b60-7511-470d-9104-a7cd65d18bda.mp4.
- Size: 597,551 bytes; duration 11,036 ms; SHA-256 69A7ECCCAE6622CA0B80AD720CFE12AEA7DC2F002774B071C0676410BFBED933.
- Pixel evidence: build/verification/prompt08_preflight/media_details_current.png (first cue thumbnail), player_time6.png (second cue during playback) and player_11sec.png (no caption after the cues).
- Android playback reached 00:11. Decoder log evidence identifies video/avc and audio/mp4a-latm, an AVC decoder and AAC decoder, AAC end-of-stream, and 176,576 audio frames delivered.
- FFprobe metadata and an independent full FFmpeg decode were NOT RUN because neither tool was available on the host.

## Host checks

| Check | Result |
|---|---|
| Focused Flutter tests for settings persistence, model safety, subtitle data/language, timeline recovery and editor interactions | PASS, 32/32 |
| Flutter analyze | PASS, no issues |
| Dart formatting check | PASS, no files needed formatting |
| Native JVM SubtitleTextTest, SpeechActivityTest and SpeechMemoryTest | PASS, 7/7 |
| Localization generation and key coverage | PASS, all 14 ARB locales |
| git diff --check | PASS |
| Historical full Flutter 567 and native 162 suites | NOT RUN again |

## Acceptance gates

| Gate | Status | Note |
|---|---|---|
| G01 Native Whisper loads | PASS | x86_64 emulator JNI load and inference passed. |
| G02 Compatible local model detected | PASS | Imported Tiny was verified against its pinned hash. |
| G03 Model selection is safe and persistent | PASS | Persistence tests and Android selection passed; default restored. |
| G04 Audio extraction/conversion | PASS | Short AAC-in-MP4 source completed through mono 16 kHz preparation. Other codecs/channels remain untested. |
| G05 Real offline recognition | PASS | One real local Tiny inference completed. |
| G06 Vietnamese/English/Auto modes | PARTIAL | Auto detected English. Vietnamese ASR and forced-English ASR were not run. |
| G07 Recognition timestamp accuracy | PARTIAL | Valid clip bounds, but only one clip-wide model segment; no word-level accuracy claim. |
| G08 User can review/edit cues | PASS | Text, timing and split were exercised. |
| G09 Edited cues persist | PASS | Saved draft reopened with both edited cues. |
| G10 Valid SRT export | PASS | Actual file independently parsed. |
| G11 Editor preview/timeline | PASS | Verified on a single untrimmed clip; edit-operation time mapping remains open. |
| G12 MP4 burn-in pixels | PASS | Real MP4 playback showed the expected captions at cue times and no caption after them. |
| G13 Original media/project preserved | PASS | Source hash unchanged; all 10 original project hashes match. New outputs/drafts are task-owned. |
| G14 Cancel/error safety | PARTIAL | Model-removal confirmation is fixed and widget-tested; Android ASR cancel/error was not run. |
| G15 No severe new regression | PASS | No crash during focused Android flow; emulator-only responsiveness evidence. |

## Evidence directory

Runtime screenshots, UI dumps, SRT, MP4 copy, job journal, APK identity and decoder logs are retained under build/verification/prompt08_preflight/. The task-only SAF folder and imported Tiny model were retained. No existing model, original photo/video, historical QA item, SAF grant, preference set or original draft was deleted.
