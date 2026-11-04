# P3 — recording MVP

Native MediaProjection consent → foreground service → surface-input H.264 MediaCodec/MediaMuxer MP4 → metadata validation → MediaStore publish → catalog refresh. Android 7–9 use app-specific storage shared through a narrow FileProvider. Cancellation creates no output. Duplicate start is rejected, and repeated stop does not finalize twice. The projection token is never persisted. Required manifest permissions are foreground service, foreground media projection, and optional notification visibility.

The MVP uses mute, 30 FPS, and an encoder-supported size up to a 1280-pixel long edge. UI explicitly states that stored quality/audio preferences are not yet applied. Playback, capture configuration, pause/resume, recovery journal, and capture tools belong to the following phases. The sample-completion deep link redirects to the real library.

Engine evaluation: the initial MediaRecorder proof produced a valid but truncated-duration file on a static screen (113.9 seconds after a 125-second session). It was replaced with direct MediaCodec/MediaMuxer so the final frame duration is explicitly finalized through the public empty-EOS sample API; recording state begins after the first encoded frame. Encoding drain and finalization run off the UI thread. RootEncoder offers broader stream/audio/GL capabilities, but its network streaming scope is deferred and adding it before testing the basic output lifecycle would expand the initial dependency surface. It remains a candidate for advanced pipelines; no claim is made that its integration has been built or verified here.

References: R11, R63–R65, R88; routes `/videos`, center capture sheet, `/media/:id`.

Sources:
- https://developer.android.com/media/grow/media-projection
- https://github.com/pedroSG94/RootEncoder/wiki

Tests: controller tests cover consent denial, no false success, duplicate completion refresh, and failed stop state retention. Native test `integration_test/recording_mvp_test.dart` requires cancelling then accepting two OS consent prompts and records 125 seconds before validating saved metadata. Device result is recorded below after execution.

Host checks: analyzer clean, all 13 unit/widget tests passed, and the debug APK compiled. Pixel_8 (API 37) failed installation due to insufficient emulator storage; a fresh isolated AVD also could not allocate its required userdata disk on this host. Testing moved to the existing flutter_emulator on API 36 without wiping its data.

Timing regression: the first native recording test correctly failed duration validation. The source MP4 decoded with passthrough timebase, but its static tail was omitted by MediaRecorder. The test threshold was retained; the engine is being corrected instead of weakening the assertion.

Verified on flutter_emulator / Android API 36: denial created no additional file; accepted capture continued outside the app for 125 seconds; finalization indexed the output; repeated stop preserved the same URI. Native integration test passed. Independent ffprobe reported H.264, 720×1280, 125.916156 seconds, 1,472 frames, and 4,591,733 bytes. FFmpeg decoded the complete stream with passthrough timing without errors. A frame extracted at 20 seconds shows the Android Settings screen captured outside Flutter.

Frame rate is a target, not a constant-frame-rate guarantee; this software-emulated, mostly static capture averaged about 11.7 FPS. The actual duration is preserved even when no new screen frame arrives at the end. Frame-rate/quality and audio capability validation continue in P4.

Evidence artifacts (ignored build outputs): `build/verification/phase3-verified.mp4` and `phase3-frame.png`. Physical devices and notification-triggered stop remain additional matrix checks.
