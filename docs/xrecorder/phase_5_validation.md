# Phase 5 — Session controls and recovery

Native pause/resume/stop are available through Flutter and session-scoped immutable notification PendingIntents. The native state remains authoritative after UI reconnect. Paused PCM is discarded; surface encoding is suspended and video timestamps exclude paused time. Stop works while paused; duplicate stops cannot publish twice. Periodic free-space checks stop capture before storage is exhausted.

A bounded preferences journal records session state, configuration and pending output, never a projection token. After process loss, unfinished sessions become visibly interrupted; cleanup checks MediaStore ownership and pending status and exact private session filenames. Published items are preserved. Capture consent can reconnect after Activity recreation. Optional floating overlays and shake gestures remain unavailable pending their own device tests.

Validation (2026-11-04):

- Analyzer clean, 13 host tests passed, Android debug build succeeded.
- `recording_controls_test.dart` passed on API 36: three seconds active, four seconds paused, reconnect to native paused state, resume for three seconds, stop while paused, verify real output and repeated-stop idempotence.
- Independent output check: video 6.410956 seconds; AAC starts at 0.020292 seconds and lasts 6.400000 seconds. Full ffmpeg decode reports no errors. Artifact: ignored `build/verification/phase5-paused-fixed.mp4`, MediaStore ID 38.
- First decode revealed timestamp quantization collisions after resume. Encoder timestamp spacing was fixed; capture and independent decode were rerun successfully.

References: [Android MediaCodec suspend parameters](https://developer.android.com/reference/android/media/MediaCodec#PARAMETER_KEY_SUSPEND).

Remaining device matrix: physical audio synchronization across repeated pauses, Activity recreation during system consent, force-kill cleanup, notification action taps, lock/projection revocation and low-storage fault injection. These are not claimed tested by the method-channel integration test.
