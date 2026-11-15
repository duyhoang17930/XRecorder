# Recording stabilization investigation — 2026-11-14

Task remains open. Host regressions do not close runtime audio/video gates.

## Confirmed defect repaired: accepted PCM lost at Stop

`CapturePcmReader` checked `stopping` immediately after a blocking read and discarded a positive result if Stop raced that read. It also abandoned its partial final block. `SessionAudio` assumed every block contained 1024 samples and could end while the producer was still returning its last read. Consequently accepted input could disappear at finalization even without overflow.

The deterministic regression holds the second read, requests Stop, then returns 137 samples after an already queued 1024-sample block. The repaired reader yields all 1161 samples, in order, with no padding. SessionAudio consumes the variable terminal block and waits for producer completion before deciding the queue is exhausted. Microphone samples already accepted by the consumer are also counted before checking termination. This repairs a separate bounded tail-loss defect; it does **not** explain the historical 3.979 ms seam or recurring AAC stalls.

## Historical audio failure: verified observations, unresolved mechanism

Retained `../live_audio_audio17_result.json` shows internal actual buffer 3072 frames (64 ms at mono 48 kHz), microphone buffer 96000 frames, internal queue 108 → 134 → 161 → 186 → 192 blocks, and final captured/encoded sample counters 623616/425984. Worker samples include native queueInputBuffer, releaseOutputBuffer and dequeueOutputBuffer. This locates slow consumption around codec work; stack samples do not measure individual blocking durations or establish why Android codec scheduling slowed. Requested 192000 bytes did not produce a two-second playback capture buffer. Queue capacity remains 192; it was not enlarged.

New bounded telemetry records maximum PCM read duration, observed queue high water, queueInputBuffer duration, dequeueOutputBuffer duration and muxer/live-sink write duration. These are monotonic elapsed durations, never converted into media PTS. Source timestamps retain TIMEBASE_MONOTONIC; AAC PTS still derives from accepted sample count at 48 kHz. Mixer origin compensation, pause-boundary clock alignment and microphone starvation remain unverified. No resampling, inserted silence or timestamp stretching was added by this continuation.

## Historical video failure: no accepted repair

`../video_preview_stale_cue_before.json` and audio17/18 show a source player clock advancing while its visible/encoded picture retains an earlier cue. This supports stale source presentation in those cases, rather than proving encoder or projection failure. Earlier seek avoidance, Media3 SurfaceView and TextureView experiments failed and were removed before this continuation. Original VideoView, crop registration, encoder surface and projection lifecycle remain unchanged. New runtime must compare visible source cues against independently decoded output. Repeated encoder packets alone cannot diagnose source freshness because static-frame repetition is configured deliberately.

## Environment qualification

Current Git HEAD at entry: `21d40df`; only `asr_avd_3gb_stdout.txt` was dirty. Historical handoff's uncommitted-source description is stale. No reset/restore/stash/commit was used.

Initially no ADB device was attached. Default snapshot startup failed; cold boot of the existing Pixel_7 succeeded, with no snapshot deletion or explicit save. Serial emulator-5554, API37, x86_64/16KB image. Headless auto graphics selected SwiftShader, so this session cannot establish parity with historical NVIDIA hardware-rendered performance.

The booted app has 8 byte-exact original drafts, but historical source URI115 and `no_backup/speech_models/ggml-tiny.bin` are absent. The 55-file historical metadata state is not reproduced. Archive compaction manifest explicitly reports workspace-only cleanup and unchanged protected paths; it does not prove the current AVD state. No causal claim about cleanup, snapshot loading or missing files is established. Current metadata was retained in `current_metadata.tar/json`; original draft hashes independently match the original private-state archive. No historical recovery input or model was deliberately removed.

The controlled source is still present on the host with SHA8925ac2f0764e8bcdbcf1b70f5f28b373b4653f7a7aa0c8b163ebfa00001c34f. New shell-owned URI45 is byte-exact but inaccessible to the application. An app-owned duplicate URI47 was imported through existing MediaOutput in a test-only fixture. No media permission was granted by ADB. Failed setup attempts are harness failures, not product capture failures. Settings written through current UI also add the existing default screenshotDelay field to the older document; this explains the initial fixture equality failure, not an audio defect.

## External research ledger

Consulted 2026-11-14. API pages are living contracts; issue dates/affected versions are unknown unless stated. No community patch was copied into production.

| Source | Date / versions | Finding, source comparison and experimental status |
| --- | --- | --- |
| [AudioRecord](https://developer.android.com/reference/android/media/AudioRecord) and [Builder](https://developer.android.com/reference/android/media/AudioRecord.Builder) | API contracts; buffer getter API23+, builder API23+ | Read promptly; requested and actual buffers differ. Actual 3072-frame historical reading confirms need for independent reader, not arbitrary queue growth. Stop-tail regression checks accepted reads separately. |
| [Playback capture configuration](https://developer.android.com/reference/android/media/AudioPlaybackCaptureConfiguration) and [capture policy](https://developer.android.com/media/platform/av-capture) | Android10+ | Capture depends on usage, profile and source policy. Existing matching usages media/game/unknown retained. Protected/silent source is not automatically a recorder bug. |
| [MediaCodec](https://developer.android.com/reference/android/media/MediaCodec) | Living API | Input/output ownership and drain lifecycle apply to existing synchronous encoder. Added call-duration diagnostics; replacing encoder or asynchronous redesign is not experimentally justified. |
| [MediaProjection](https://developer.android.com/media/grow/media-projection) | Android14+ single-app sharing and one-use consent | Current code registers onStop and onCapturedContentResize, resizes the existing VirtualDisplay, terminates region capture on incompatible source geometry. No consumed token reused. Rotation still needs current runtime verification. |
| [Android15 changes](https://developer.android.com/about/versions/15/behavior-changes-all) | Android15 | Lock/token termination must finalize or fail honestly; no consent bypass. Current onStop handling exists; lock runtime gate open. |
| [Android17 beta overview](https://developer.android.com/blog/posts/the-first-beta-of-android-17) | Android17, 2026 | Background audio restrictions are a diagnostic consideration; no evidence establishes them as cause here. API37 emulator alone does not establish physical-device behavior. |
| [AOSP AudioRecord.cpp](https://android.googlesource.com/platform/frameworks/av/+/e3c46b0a49d045fa38d35e5cf7ad4becaacbbed6/media/libaudioclient/AudioRecord.cpp) | Pinned revision; version applicability unqualified | Platform owns finite capture buffers and stop/unblock lifecycle. General evidence, not proof of this emulator's exact framework binary. Main-branch fetch was unavailable. |
| [Issue541325203](https://issuetracker.google.com/issues/541325203) | Unknown | Public page returned sign-in only. Contents/root cause not available; no finding attributed to it. |
| [RootEncoder2058](https://github.com/pedroSG94/RootEncoder/issues/2058) | March2026; library2.7.1, device unspecified | Codec/GL teardown can block; compare existing off-main finalizer. Does not demonstrate current source-freeze cause. |
| [RootEncoder2090](https://github.com/pedroSG94/RootEncoder/issues/2090) | May2026; Android version not established | Internal audio loss around dynamic dimensions suggests a lifecycle test. Current code does not change audio format during resize; no match established. |
| [RootEncoder1560](https://github.com/pedroSG94/RootEncoder/discussions/1560) | September2024; Pixel9 | Duration differences can occur independently of packet corruption. Current muxer/sample-counter investigation remains separate from RTMP packet parity. |
| [SO rotation report](https://stackoverflow.com/questions/37143968/how-to-handle-image-capture-with-mediaprojection-on-orientation-change) | 2016; older APIs | Orientation reproduction hint only. Old advice to recreate a projection/display must not override Android14 consent contracts. |
| [Reddit rotation report](https://www.reddit.com/r/androiddev/comments/1epfups) | August2024; version not established | Consent UI can alter source orientation. Useful test condition, no authority or confirmed root cause. |

Public Facebook and Threads searches produced no relevant accessible primary evidence. No private account/group access attempted. Stack Overflow/Reddit were searched for reproduction signals; implementation decisions rely on official platform contracts and the local deterministic regression.

## Follow-up: framework buffer allocation and renderer comparison (2026-11-15)

[AOSP AudioRecord.Builder](https://android.googlesource.com/platform/frameworks/base/+/master/media/java/android/media/AudioRecord.java) `buildAudioPlaybackCaptureRecord` calls AudioPolicy.createAudioRecordSink without passing mBufferSizeInBytes. [AOSP AudioPolicy](https://android.googlesource.com/platform/frameworks/base/+/master/media/java/android/media/audiopolicy/AudioPolicy.java) constructs its sink with getMinBufferSize. This explains why increasing the Java Builder request does not necessarily change playback-capture capacity. It matches actual3072frames vs requested96000, but the exact API37 system binary was not disassembled and this alone does not prove where each waveform discontinuity originates. No hidden AudioPolicy API or security bypass is introduced.

Same-source, same profile candidate short comparison: SwiftShader `stab4` waveform FAIL, host NVIDIA `stab_gpu1` waveform PASS under the unchanged original validator. First5s correlation .999965; subsequent windows .999977/.999949/.999922. Both outputs in both runs fully decode, received packets match contiguous local packets, and2later source-cue samples are correct. Observed FIFO peak44→11, max read1717→116ms, max write1454→79ms. This supports a renderer/host-pressure contribution. It does not establish hardware-renderer configuration as an application repair or close all prior platform/source-clock defects.

`stab_motion2` qualifies the changing-frame source:152checked frames,51distinct masked IDs, no ID outside the1s diagnostic window. Its cold source/view transition still fails fixed-offset audio windows, while interior2–5s windows correlate above .9997. This remains a real quality failure in that tested transition. No five-minute PASS can erase it.

Test-fixture failures are separate: `stab_motion1` synchronously relaunched an existing MainActivity and timed out; changed to asynchronous activity reorder, with a short successful qualification before the long baseline. Its118s local output URI50 is retained and registered, and is not a valid stress acceptance run because the controlled source had not started. The local RTMP receiver's105s configured cutoff then led to connection_failed and a retained completed local file. No transport fix claimed.

The original waveform validator assumes a non-loop source. On explicitly repeating audio it can choose a later identical occurrence and index past the recording tail. Its original failure is retained, not threshold-relaxed. New loop diagnostic confines alignment to the first occurrence, uses a voiced interior anchor, then tests the same fixed sample offset including the initial windows at the original .98 threshold. Early exploratory RMS-fit alignment was invalid for silent regions and was removed; failed diagnostic outputs remain. The final loop diagnostic uses the original Pearson formulation and reports cold-transition FAIL. This diagnostic is separate from the unchanged original validator, which passes `stab_gpu1`.

## Sustained reproduction and remaining boundary

One5minute baseline reproduces source-clock/waveform discontinuity without FIFO saturation: peak22blocks, not192. Near capture82.7s, internal timestamp origin shifts about128ms while max independent read and queueInput call durations rise to344/342ms. Fixed sample alignment shifts about-137.5ms around source79s. Accepted reader/sample counters do not develop an accumulating FIFO gap; source-minus-read remains about2–4blocks. This distinguishes a new sustained pre-read/source-clock/scheduling event from the historical backlog abort. It does not yet separate AudioFlinger loss, upstream source-clock behavior and emulator-wide scheduling stalls. Short AudioTrack diagnostics report0underruns and valid timestamps; this does not retroactively prove the source's behavior at the long-run event.

Final short counter diagnostic: native View generates48.91draw callbacks/s while9.44video packets/s are sent. This rules out equating configured30fps with observed cadence. onDraw is not a display-present fence, so projection/surface/encoder attribution remains open. The stress marker's4early ID mismatches are retained; producer-present readiness was not recorded in that run. Later IDs stay current within the diagnostic age bounds. No video engine replacement is justified by this evidence.

G1 remains FAIL, G2/G3/G5/G6 PARTIAL. Healthy physical-device comparison or additional platform/presentation-fence tracing is needed before selecting a further production repair. Increasing PCM capacity or fabricating samples cannot recover missing pre-read content. No unsupported/hidden AudioPolicy workaround was used.
