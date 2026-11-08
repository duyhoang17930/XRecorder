# Current P2/P3 implementation and verification

TASK07 checkpoint08/11/2026: [final report](TASK_07_FINAL_REPORT_VI.md) và
[evidence](TASK_07_TEST_EVIDENCE.md).12 locales, multilingual contract,
durable ASR history/RAM/Unicode/preview fixes và main APK/native accessibility
đã kiểm. Performance gate OPEN; bảng07/11 bên dưới là checkpoint lịch sử.

Updated 07/11/2026, final quality continuation from b9aea92. This describes actual code, replacing the original M0 gap list.
Missing engine/model is no longer an F41 blocker. Exact evidence and unexecuted
gates are in [TEST_EVIDENCE](P2_P3_TEST_EVIDENCE.md).

| Area | Real implementation | Verification / limit |
|---|---|---|
| Library/media | Lazy library, search, 5 sorts, source/query/scroll retention, observer, bounded thumbnail cache |Current1009-image profile3 trials/side: median raster p95 43.711→40.515ms, about7.3%; still above60fps budget on SwiftShader. Native320/411dp Light/Dark/text200 PASS with1012 retained QA images. |
| Preview lifecycle | SurfaceView hybrid fallback, portrait display metadata, stale poll/metadata guards; lazy player allocation, pause+stop before detach |Black-frame before/after verified. Actual layer preview/output parity at4 times. Stronger soak30 preview/20 export-cancel PASS, releaseFailures0, max dispose741ms; earlier release-timeout failures retained. |
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
| F41 | whisper.cpp1.9.5 CPU/JNI with documented CPU abort propagation patch, decoder/resampler, verified model manager, timed progress and job restore |38 jobs/35 inferences over12 stimuli; Base default, corpus caveats in AI_EVALUATION. Queue-poison regression fixed. Cancel drain+next decode9616→518ms;9 post-patch multilingual jobs PASS. Real download/import/cancel faults rerun. |
| F42 | Generated/manual cues, split/merge/styles/long text, speed retiming, SRT file/clipboard and MP4 burn-in | Edited audio→ASR→SRT/burn-in and speed2 pixel timing pass. |
| Accessibility | Text200, labeled controls, reachable actions, keyboard numeric fields, accessible drawing preset | Widget checks and actual TalkBack16 service/touch-exploration coexistence smoke pass. Focus/gesture signoff PARTIAL: injected ADB actions do not establish proof; sendevent/root unavailable. Settings restored. No real-user testing claim. |

No feature is marked working from its UI alone. Physical performance, speech
accuracy across speakers, human ergonomics, OEM/SD and final P1 integration are
acceptance limitations, distinct from the implemented independent backends.
