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

