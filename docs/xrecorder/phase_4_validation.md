# Phase 4 — Configuration and audio

Implemented native encoder capability checks, immutable session configuration, orientation, normal/performance presets, independent countdown and duration limit, and mute/microphone/internal/mixed capture. Audio is mono 48 kHz AAC with independent gains and optional device noise suppression. Protected or opted-out playback may remain silent. Frame rate is a target, not a constant-frame-rate guarantee.

Settings schema 2 migrates existing documents. Shared recording/settings controls disable unsupported options; native validation remains authoritative. Audio permission denial fails explicitly and suggests mute.

Validation on 2026-11-04:

- `flutter analyze`: clean; `flutter test`: 13 passed; Android debug build succeeded.
- `recording_configuration_test.dart` passed on Android 16/API 36 emulator for all four sources, portrait 720×1280, target 30 fps, 8 Mbps, one-second countdown and four-second automatic stop. Saved MediaStore IDs 33–36; audio metadata matched each source.
- Mixed output independently inspected with ffprobe: H.264 720×1280, 4.217522 s video; AAC starts at 0.015104 s, duration 4.053333 s. Full ffmpeg decode completed without errors. Local evidence: ignored `build/verification/phase4-mixed.mp4`.
- An earlier attempt timed out at the OS permission prompt; rerun with notification/audio/projection consent passed.

Outstanding device coverage: audible reference-tone mixing, long-running A/V drift, competing microphones, protected playback, physical-device noise suppression, HEVC and higher presets. Emulator track-presence checks do not establish audible fidelity. Pause/resume is Phase 5.
