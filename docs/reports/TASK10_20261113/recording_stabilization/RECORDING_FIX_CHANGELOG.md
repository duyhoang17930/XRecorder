# Recording changes

- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CapturePcmReader.kt`: retain successful final read and partial terminal block; expose producer completion and bounded read/high-water counters; propagate terminal saturation explicitly.
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/SessionAudio.kt`: drain producer before EOS; handle variable terminal sample count, count accepted microphone reads before Stop decision; monotonic codec/write-duration diagnostics. No codec/preset/gain, sample-rate, channel, transport or schema changes.
- `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CapturePcmReaderTest.kt`: deterministic stop/read race with exact 1161-sample oracle.
- `android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveCaptureAudioInstrumentation.kt`: collect new counters, allow reimported numeric MediaStore URI while retaining immutable source SHA gate.
- `android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task10LiveInstrumentation.kt`: test-only SHA-pinned source import through existing MediaOutput, creating an app-owned duplicate without granting media permissions.
- `../live_capture_audio_gate.py`, `../live_controlled_audio_gate.py`: optional source URI/current preference fixture directory; defaults and historical evidence unchanged.
- `../task_created_media.json`: append ownership records for new test sources/outputs only.
- This focused report directory: logs, current metadata snapshot and fixture-import helper. Failed shell transfer retained as `failed_cli_source_transfer.mp4`; this is deliberately incomplete setup evidence, not recorder output.

No production video/player experiment added. Queue capacity unchanged. Channels, JNI, application ID, preferences version and recovery contracts unchanged. The initial user-modified emulator log remains untouched by source edits.

The test-only fixture now supports a bounded15s–300s repeating AudioTrack source, a30Hz monotonic binary frame-ID/color marker, PSS/CPU samples, and an optional1s source warmup after activity focus. This does not change production capture scheduling. Original player and cold-transition failures remain evidence. Failed shell-import helper removed; app-owned MediaOutput importer retained. `validate_loop_motion.py` and `summarize_runtime.py` operate on host evidence only, without device mutations or threshold changes to the original validator.

Regression implications: audio termination now submits a short final PCM block. Native reader tests verify exact ordering/count; Android AAC acceptance and complete runtime quality remain separate gates. Mixed-source origin alignment is still unresolved. Observed queue high water is sampled after offer and may undercount a concurrent consumer's instantaneous peak.
