# Prompt08 AI Subtitles Audit

## Scope and baseline

This audit follows the existing Task10 implementation. It does not introduce another ASR engine or replace the editor/export pipeline.

- Repository baseline: commit 9f5dcc9f38c3a2050b263e4cd41adeb745d28ae6; source worktree was clean before this task.
- Installed app: com.xrecorder.xrecorder 0.1.0, emulator-5554, Android 17/API 37, x86_64.
- Preflight /data free space: 649,856 KiB. Final free space: 428,136 KiB. Removable SDCARD free space at close: 442,998 KiB.
- The initial emulator had no app-managed speech model. One existing, checksum-matching Tiny fixture was imported from a task-owned file. No model was downloaded or removed.
- The prior Prompt06+07A APK hash was checked before building. The task APK was installed in place, without uninstalling or clearing data.
- Original project hashes: all 10 pre-task project files match their post-run baseline hashes. Two new task-owned drafts were created during the subtitle workflow and reopen check.

Historical Task10 results are context only. Current results below come from this Prompt08 build and runtime.

## Existing implementation map

| Area | Existing implementation | Audit result |
|---|---|---|
| Whisper version and native build | android/app/src/main/cpp/third_party/whisper.cpp and UPSTREAM.md | Vendored whisper.cpp v1.9.5, commit d1be6fde11ac6e0407606b4e42fe72d34add8037. The app builds the CPU JNI library for arm64-v8a, armeabi-v7a and x86_64. |
| JNI and inference | whisper_jni.cpp and editor/WhisperNative.kt | Kotlin loads the native library, creates/frees an inference context per run, passes the selected language or auto, returns segments, and forwards progress/abort. The patched Whisper abort callback reaches CPU graph work. The emulator loaded the x86_64 library and completed inference. ARM device loading was not exercised. |
| Model management | editor/WhisperNative.kt and editor/TranscriptionBridge.kt | App-private no-backup storage; Tiny, Base and Small-q5_1 have pinned expected sizes and SHA-256 values. Import/download staging uses a .part file and verifies before publishing. Runtime import and Tiny verification passed. Download, corrupt import and runtime removal were not exercised. |
| Job lifecycle | editor/TranscriptionBridge.kt and lib/features/editor/transcription_service.dart | A single speech worker, persisted job records, memory preflight, cancellation state and native cleanup are present. The current app documents a 10-minute input limit. One completed job was persisted and reopened. Runtime cancellation and process-death recovery were not exercised. |
| Audio preparation | editor/SpeechAudioDecoder.kt | MediaExtractor/MediaCodec select the audio track; decoded channels are averaged to mono and linearly resampled to 16 kHz, with a ten-minute sample bound and cleanup in finally. A short AAC audio track inside MP4 passed through this path. Stereo-specific, silent, missing-track, corrupt and revoked-permission inputs were not run. |
| Subtitle model and editing | lib/features/editor/subtitles.dart and subtitle_editor.dart | SubtitleTrack validates Unicode text, cue range, duration, ordering and overlap. Existing editor supports text/time edits, add, delete, split, merge, SRT save and copy. Manual edits survived draft save, leaving the editor, and reopening the saved draft. |
| Timeline and preview | lib/features/editor/editor_screen.dart, editor_preview.dart, editor/project_effects.dart and android/app/src/main/kotlin/com/xrecorder/xrecorder/editor/EditorLayers.kt | Project-level subtitle cues are rendered over the editor preview with timeline offsets. A one-clip project displayed the cue at 0 and the second cue around 6 seconds. Trim, split-clip, reorder and speed-adjusted subtitle mapping remain unverified. |
| Export | existing EditorComposition / Media3 Transformer path and SubtitleOverlay | Export created a new MediaStore MP4 with caption pixels, AVC video and AAC audio. Android playback and cue-time screenshots passed. The host did not have FFmpeg or FFprobe, so no independent FFmpeg decode or ffprobe report was produced. |

## Prompt08 changes

Two reproduced model-management defects were fixed:

1. A selected speech model reset to Base when the transcription dialog/controller was recreated. The selected valid model is now stored in settings, restored on launch and defaults to Base if absent or invalid.
2. Remove downloaded model immediately called the native delete method. The dialog now requires explicit confirmation and rechecks that the dialog is mounted and no job has become active.

The removal confirmation string was added to all 14 supported ARB locales. No ASR, audio decoding, subtitle timeline or export implementation was replaced.

## Runtime findings

- Tiny import hash: be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21; 77,691,713 bytes. The app-private installed file matches this hash.
- A real 11-second MP4 containing English speech completed with Tiny and Auto Detect. Auto detected English. One segment covered 0–11,000 ms and matched the available reference words. Model load was 205 ms, inference 9,780 ms and total job time 11,171 ms on the constrained x86_64 emulator.
- That single segment is clip-wide, not word-aligned. A user-edited split at 5.4 seconds and cue end at 10.8 seconds were tested in the editor, but those manual times do not establish model timestamp accuracy.
- Vietnamese ASR and forced-English ASR were not run. Vietnamese text was typed manually to verify Unicode through editing, SRT, preview and burn-in.
- SRT export wrote a real UTF-8 file with two sequential cues and comma-millisecond timestamps. An independent host-side parser checked numbering, timestamps, cue text and Vietnamese diacritics.
- The exported MP4 was 597,551 bytes, MediaStore ID 636, duration 11,036 ms, and SHA-256 69a7ecccae6622ca0b80ad720cfe12aea7dc2f002774b071c0676410bfbbed933. Playback showed the first caption at the beginning, the second at about 6 seconds, and no caption at the end. Android decoder logs show AVC video and AAC audio decoders reaching end of stream; audio delivered 176,576 frames.

## Remaining audit limits

The tested project has one untrimmed clip beginning at project time zero. Source-media/project-time/export-time mapping after trim, split clips, reordering or speed changes is not established by this run. Only one real ASR language result and one imported model were exercised. Runtime cancel/retry, background lifecycle, low-storage failure, model download/removal and malformed input cases remain outstanding. No physical Android device was used.
