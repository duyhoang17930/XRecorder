# 3HRecorder — physical-device QA handoff

**Status:** All cases NOT RUN. The owner has no physical Android device available for this development phase. Run after the prompts are complete; record device model, Android/API, APK SHA and direct evidence. Emulator results do not count as hardware PASS.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-07 | Real front/back cameras: focus, exposure, optical orientation and mirroring | Preview and MP4 are upright and correctly mirrored; usable focus/exposure; camera frames stay fresh. | NOT RUN |
| PDH-08 | Camera privacy toggle, permission revoke/regrant and another app competing for camera | Facecam availability is truthful; resources release/retry safely; screen recording continues when possible. | NOT RUN |
| PDH-05 | Device cutouts, rounded corners, edge touch and rotating while Facecam/Drawing are active | Controls remain reachable; camera placement and drawing coordinates stay correct; no trapped underlying touches. | NOT RUN |
| PDH-04 | OEM overlay/background restrictions over Home and another app | Floating controls remain usable when permitted; background and Stop behavior follow OEM policy without stale sessions. | NOT RUN |
| PDH-13 | Sustained Facecam + Drawing + screen recording, hardware audio/video, thermal and resource use | No reproducible crash/ANR or uncontrolled heat/resource growth; output finalizes with usable synchronized audio/video. | NOT RUN |
| PDH-16 | Floating Ball visible and interactive while absent from saved MP4 | Ball/menu are absent from decoded pixels, with the changing content behind them preserved and no black hole. This remains a release-blocking requirement. | NOT RUN |
| PDH-18 | Recording footer and key screens at enlarged text, accessibility settings and localized UI | Footer/panels do not cover or clip controls; TalkBack labels and touch targets permit the core flow. | NOT RUN |
| PDH-19 | Screenshot flow on an OEM build and device display | One consented PNG per action with correct source pixels/orientation; no duplicate or overlay-dependent corruption. | NOT RUN |

## AI Subtitles hardware follow-up

Run these cases on a physical ARM64 device after the emulator phase. Record device model, Android/API, APK SHA, model/hash, source duration, timings, memory/thermal observations and direct output evidence. Emulator results do not count as hardware PASS.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-ASR-01 | Load the packaged ARM64 Whisper JNI library and a verified local Tiny model | Native load and inference succeed without crash; model identity/hash is truthful. | NOT RUN |
| PDH-ASR-02 | Short Vietnamese and English speech with Tiny and Auto/forced language choices | Language choice and detection match the selected mode; Unicode and punctuation survive review/export; compare against reference speech. | NOT RUN |
| PDH-ASR-03 | Inference responsiveness and CPU time on a mid-range device | UI remains usable, progress is truthful, elapsed time and resource use are recorded; no emulator performance claim is reused. | NOT RUN |
| PDH-ASR-04 | Model load and inference under low-memory conditions, including Base and Small-q5_1 where storage permits | Memory preflight rejects unsafe work clearly or inference completes and releases resources; no OOM/crash. | NOT RUN |
| PDH-ASR-05 | Sustained ASR and MP4 subtitle burn-in under thermal load | Record temperature/throttling and export time; device remains responsive and output decodes with correct subtitle pixels and audio. | NOT RUN |
| PDH-ASR-06 | Background/foreground and process lifecycle under the device OEM's restrictions | The app reports foreground-only behavior honestly; interrupted work is not misreported as active and can be retried safely. | NOT RUN |
| PDH-ASR-07 | Large-model load and repeated ASR/export jobs | Model/native resources are released between jobs; no crash, locked model or steadily increasing memory use. | NOT RUN |

## Import and project persistence hardware follow-up

Run on at least one OEM device with removable/external storage where available. Record device/OEM, Android/API, provider name, selected URI type, grant behavior and direct evidence. Emulator results do not count as hardware PASS.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-IMP-01 | Import video, photo and audio from OEM Files, cloud-backed document providers and USB storage | Supported media metadata is correct; sources open from content URIs; unavailable providers return a clear recoverable error. | NOT RUN |
| PDH-IMP-02 | SAF read grant across process death, reboot and in-place app update; revoke it in a controlled task project | Grants persist when offered; revoked access preserves the draft and offers relink without clearing edits. | NOT RUN |
| PDH-IMP-03 | Remove and reinsert an SD card while a task-owned project references its media | Missing media is reported without losing project state; the same card/source can reopen or be relinked after reinsertion. | NOT RUN |
| PDH-IMP-04 | Import photos/videos from multiple real camera models with EXIF orientation, rotation, HDR and unusual timestamps | Preview and dimensions/orientation match the source; no unnecessary full-resolution decode or source mutation. | NOT RUN |
| PDH-IMP-05 | Open a large task-owned project, then trigger low-memory process recreation with referenced media on internal/external storage | Loading remains responsive; saved project/cues/tracks survive; inaccessible sources remain recoverable after restart. | NOT RUN |

## Export hardware follow-up

Run these export-specific cases on an ARM64 physical device after emulator QA. Record device/OEM, Android/API, APK SHA, source/output hashes, elapsed time, output metadata, codec and storage before/after. Emulator results do not count as hardware PASS. Keep each source short unless storage and runtime are safely bounded.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-EXP-01 | H.264/AAC export across hardware encoder implementations and supported source codecs | Export reports actual codec and dimensions; completed output decodes fully; unsupported codecs fail clearly and can be retried without a partial published item. | NOT RUN |
| PDH-EXP-02 | Sustained multi-clip export under thermal load | App remains responsive, progress stays truthful, thermal throttling is recorded, and output order/duration/audio remain correct. | NOT RUN |
| PDH-EXP-03 | Bounded long export and memory pressure | Record elapsed time, output size, memory/resource observations and decoder completion; no OOM, stale running job or lost temp file. | NOT RUN |
| PDH-EXP-04 | Low-storage OEM preflight and allocation error | Preflight/error UI is accurate; simulated or naturally occurring write failure leaves no corrupt completed MediaStore row and retry is safe. Do not deliberately fill device storage. | NOT RUN |
| PDH-EXP-05 | Background/foreground and OEM process restrictions during export | UI explains keep-open/foreground-only semantics; interruption is not shown as success and persisted jobs can be retried safely. | NOT RUN |
| PDH-EXP-06 | Audio/subtitle composition on ARM64 | Added audio offset/mix and saved subtitle pixels/timing are checked against reference timestamps, including trim/split/reorder/speed cases; output audio/video fully decodes without material drift. | NOT RUN |

## Livestream hardware follow-up

Run after current-source private receiver QA passes on an emulator. Record device model/OEM, Android/API, app/APK SHA, receiver/player and network type. Keep endpoints private and redact credentials. Emulator results do not count as hardware PASS.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-LIVE-01 | ARM64 hardware H.264/AAC encoder selection and sustained 30/60 fps where supported | Receiver decodes the actual measured cadence and audio; record encoder identity, output FPS/bitrate and drops rather than assuming requested settings were achieved. | NOT RUN |
| PDH-LIVE-02 | Wi-Fi to cellular handoff and recovery on a private receiver | Transport failure/retry remains bounded, UI follows actual connection state, and Stop cancels retry without stale capture or duplicate sessions. | NOT RUN |
| PDH-LIVE-03 | Sustained livestream thermal, CPU/memory and battery behavior | Record throttling, temperature trend, battery use, queue growth and frame/audio continuity over an agreed bounded session; no uncontrolled resource growth. | NOT RUN |
| PDH-LIVE-04 | OEM background restrictions, screen lock and audio routing | OEM policy and projection termination are reported truthfully; selected microphone/playback route remains understandable and is released after Stop/system termination. | NOT RUN |
| PDH-LIVE-05 | Optional Facecam/Drawing overlay under live encode pressure | Shared overlays remain responsive and output remains decodable at measured cadence; failure to sustain the optional overlay does not leave a zombie stream. | NOT RUN |
| PDH-LIVE-06 | Real end-to-end streaming latency across network conditions | Use a controlled visible/timed stimulus and receiver-side timestamps; report observed latency/jitter and network conditions without treating connection time as media latency. | NOT RUN |

