# Current P2/P3 implementation and verification

Updated 07/11/2026. This describes actual code, replacing the original M0 gap list.
Missing engine/model is no longer an F41 blocker. Exact evidence and unexecuted
gates are in [TEST_EVIDENCE](P2_P3_TEST_EVIDENCE.md).

| Area | Real implementation | Verification / limit |
|---|---|---|
| Library/media | Lazy library, search, 5 sorts, source/query/scroll retention, observer, bounded thumbnail cache |1006-image continuous-scroll profile; p95 improved about8%, still37.864ms on SwiftShader. |
| External files | SAF destination, streamed copy, source/read-back SHA256, pending-name publication; move requires actual write grant | Real DocumentsUI copy/move, audio picker4000ms, SRT65bytes and disconnected destination rejection pass. OEM/SD hardware untested. |
| Trash/Restore | Verified backups, AtomicFile recovery, isolated unreadable entries; committed restore retained if backup cleanup fails | Synthetic PNG Trash→Restore exact bytes pass. TTL cleanup not invoked against existing data. |
| Shortcuts | Static Edit video/Photo deep links and requestPinShortcut controls | Static cold/warm pass; actual launcher confirmation and pinned ID pass. |
| F27–30 | Trim/split/reorder/duplicate/merge still+video, crop/rotate/flip/relink, speed0.5–2 | Actual native mixed exports and frame/timing checks pass. |
| F31–32 | Timed text/vector sticker/drawing, position/scale/rotation/duration/color/order | Same CanvasOverlay for preview/export; visible and inactive-frame pixel assertions pass. |
| F19/F33 |8 audio tracks, source trim, output alignment, fades, volume/headroom, deep/bright/robot |12 real outputs: gain saturation, legacy+track headroom, trim frequency changes, silence, fade/spectral tests pass. P1 live voice untouched. |
| F34 | Coalesced AtomicFile autosave, immutable graph snapshots, Undo/Redo50, duplicate/name/relink | Backup-only/corrupt/UTF-8-cap tests; real process-kill preserves draft and permits re-export. |
| F35–38 | MP4/GIF/bitrate/size/repeat, durable queue, cancel/retry, pending publication, corrupt-history notice | MP4/GIF full decode and cancel/retry pass. Preflight and real journal EACCES tested. Exact commit-window kill not injected. |
| Photo | Crop/rotate/flip/marks/text/arrow/history, EXIF, sRGB, PNG/JPEG/resize | All8 EXIF transforms and ICC conversion match reference; white alpha/JPEG pass. Decode bounded2048px; no HDR output claim. |
| F40 | Actual RNNoise0.1, 48kHz/480-frame multichannel native processing | Vietnamese speech/noise SI-SDR +8.04dB; quiet noise RMS ratio0.0415; duration retained. +10ms measured denoiser lookahead on sample. No broad human listening signoff. |
| F41 | whisper.cpp1.9.5 CPU/JNI, decoder/resampler, model download/import/remove, real progress/cancel and persisted jobs | Real tiny/base/small vi/en benchmarks, edited-audio ASR and on-device HTTPS download. Up to10 minutes/job, RAM preflight, explicit review. |
| F42 | Generated/manual cues, split/merge/styles/long text, speed retiming, SRT file/clipboard and MP4 burn-in | Edited audio→ASR→SRT/burn-in and speed2 pixel timing pass. |
| Accessibility | Text200, labeled controls, reachable actions, keyboard numeric fields, accessible drawing preset | Widget checks and actual TalkBack16 service/touch-exploration coexistence smoke pass. Focus/gesture signoff PARTIAL: injected ADB actions do not establish proof; sendevent/root unavailable. Settings restored. No real-user testing claim. |

No feature is marked working from its UI alone. Physical performance, speech
accuracy across speakers, human ergonomics, OEM/SD and final P1 integration are
acceptance limitations, distinct from the implemented independent backends.
