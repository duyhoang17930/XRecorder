# TASK FINAL — P2/P3 Quality Audit, Performance Optimization & Real-Device Acceptance

\
Project: **3HRecorder** — [https://github.com/duyhoang17930/XRecorder](https://github.com/duyhoang17930/XRecorder)\
Scope: **Person 2 (App Core, UI/UX, Media, Platform) + Person 3 (Editor, Export, Offline AI)**.\
Đây là **IMPLEMENTATION + QA**, không phải chỉ viết audit/report. Tiếp tục từ source và tiến độ hiện tại, không làm lại từ đầu.\
Ngày yêu cầu: 07/11/2026.

## 0. Kết quả mong muốn

Hoàn thiện chất lượng P2/P3 để người dùng có thể sử dụng thực tế: UI dễ hiểu/thuận tay, thư viện mượt, Editor xuất media chính xác, dữ liệu an toàn, AI Subtitles offline hoạt động đáng tin cậy và có bằng chứng test. **Không tuyên bố toàn bộ ứng dụng hoàn thành** cho tới khi P1 tích hợp và các gate máy thật được kiểm chứng.

**Không thêm hàng loạt tính năng hoặc package mới nếu không giải quyết được vấn đề thực.** Ưu tiên sửa root cause, giữ API/behavior ổn định và kiểm thử output thật.

### Ngoài phạm vi

- **P1 read-only**: `lib/features/recording/**`, `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**`, `lib/features/settings/recording_settings_form.dart`, `audio_video_settings_screen.dart` và capture semantics trong `studio_create_sheet.dart`.
- Không sửa capture, floating ball, facecam, livestream, P1 controller/service hoặc định nghĩa event/quyền mà đồng đội sở hữu.
- Không làm Play Store publishing, signing credentials, billing, ads, chi phí, Pro, store assets hoặc quản trị backend.
- Không commit/push/PR, không uninstall/clear-data/wipe, không xóa media/draft/model người dùng, không reset/clean destructive.
- Không thay engine whisper.cpp bằng remote API: **offline-first whisper.cpp là quyết định sản phẩm**; tối ưu model/UX/performance trên kiến trúc đó.
- Nếu cần chạm `MainActivity.kt` hoặc shared channel để sửa lỗi P2/P3, P2 sở hữu thay đổi, giữ P1 channel nguyên vẹn. Mọi xung đột contract cần nêu trước.

## 1. Bắt đầu bằng source-of-truth và baseline an toàn

1. Đọc toàn bộ `AGENTS.md` và rules lồng nếu có. Sau đó đọc: `README.md`, product spec, master prompt, Task03/03.1, docs P2/P3 và các báo cáo mới nhất.
2. Đặc biệt đọc `P2_P3_MASTER_PROGRESS.md`, `P2_P3_CURRENT_AUDIT.md`, `P2_P3_CONTRACTS.md`, `P2_P3_TEST_EVIDENCE.md`, `REUSE_REGISTER.md`, `TRANSCRIPTION_CONTRACT.md` nếu tồn tại.
3. Lấy `git status --short`, branch/HEAD và baseline. Bảo vệ mọi dirty changes của người khác. Commit `5cdda32084be772f61153bc453ef3675b932ab41` là checkpoint cũ, không giả định HEAD hiện tại trùng.
4. Kiểm tra kết quả báo cáo bằng source/tests/log còn tồn tại. Không lấy đoạn text báo cáo làm bằng chứng rằng binary hiện tại có cùng tính năng.
5. Chạy verify read-only và targeted tests hợp lý trước khi sửa; so sánh **cùng fixture, cùng thiết bị, cùng profile mode**.
6. Ghi `docs/implementation/P2_P3_FINAL_QA_BASELINE.md`: source/hash, môi trường, feature status, danh sách gap theo rủi ro, baseline metrics, test matrix và các file P1 cấm sửa.

### Checkpoint tham chiếu từ báo cáo 07/11 — cần xác minh lại

- 138 Dart unit/widget tests PASS, native tests, 12 H.264/AAC outputs, JPEG/EXIF, SRT/MP4 burn-in và APK QA PASS theo báo cáo.
- P2: Library 1.006 ảnh, SAF copy/move read-back SHA256, Trash/Restore, theme/navigation/shortcuts; P3: eight audio tracks, RNNoise/voice, timeline/layers/MP4/GIF, Photo Editor; F41 whisper.cpp 1.9.5 tiny/base/small-q5_1 JNI offline.
- SwiftShader API36 1.006-image profile: **before raster p95 = 41.138ms, after_clip = 37.864ms**; 400/652 frames >16.7ms. Đây là tín hiệu cần điều tra, không mặc định là regression gây ra bởi patch.
- AI sample tiếng Việt nhỏ: CER tiny 28.125%, base 9.375%, small 0.0%; small RTF \~3.847 và sampled PSS \~594017KiB. **Một mẫu không chứng minh độ chính xác tổng quát.**
- TalkBack service/touch exploration đã chạy smoke theo báo cáo, nhưng gesture/focus và user ergonomics chưa được nghiệm thu thật.
- Báo cáo chưa chứng nhận physical device, Android API24–35/OEM/SD, thermal/battery, long-running soak và P1→P2→P3 full integration.

Không thay các giá trị này bằng số đo tốt nhất của một lượt mới rồi gọi PASS. Giữ raw traces, environment và sample counts.

## 2. GATE A — Flutter rendering, Library jank & memory (ưu tiên cao nhất)

### A1. Chẩn đoán nguyên nhân, không tối ưu mò

- Dùng Flutter DevTools Performance / frame timing profile build: phân tách **UI build** và **Raster**, trace frame jank, timeline + shader/GPU behavior.
- Đo cold vs warm gallery, first viewport, 30 continuous swipes, search, sort, folder switch, thumbnail arrival, opening preview, Edit transition, rotation và text scale2.
- Dùng corpus cố định >=1.000 media, logs của P2/P3; đo 320dp và 411dp, Light/Dark, density và emulator graphics mode.
- Kiểm tra Flutter `Opacity`/Clip/saveLayer/blur/shadows, giant image decode, ImageCache, thumbnail dimensions/disk cache, shader compilation, platform textures, overdraw, expensive custom painter, excessive rebuild, synchronous filesystem/metadata operations.
- Có thể sử dụng DevTools/Perfetto Android khi khả dụng; ghi nếu môi trường SwiftShader/host là giới hạn thay vì sửa giả.

### A2. Thực hiện tối ưu có bằng chứng

- Lazy list/grid, key/rebuild boundaries, batching state updates, isolate/compute ở CPU-heavy, lightweight placeholders, thumbnail downsampling chính xác theo cell và device pixel ratio.
- Profile image decode/resizing/cache eviction; dispose view/player, isolate repeated listeners, tránh double refresh và MediaStore scan thừa.
- Tránh thêm dependencies nặng, animation/shader blur đắt đỏ hoặc workaround che giật bằng loading giả.
- Test memory after 30× open/close previews, repeated navigation, 20× export/cancel, scrolling long catalogs; CPU/PSS/RSS/GC and Flutter heap time-series.
- Benchmark **before/after >=3 trials** nếu môi trường cho phép, môi trường host/AVD giống nhau. Ghi median/p95, frame count, >budget frames và variance. A/B phải cùng corpus/refresh rate.

### A3. Acceptance

- Không có UI lock/ANR, không unbounded memory growth và không mất event P1/P3.
- Mục tiêu mượt trên **thiết bị thật 60Hz** (budget \~16.67ms), nhưng không ghi “đạt 60fps” nếu trace không chứng minh. Với AVD software GPU, báo riêng giới hạn và physical-device gate.
- Không làm xấu readability/accessibility/safe area chỉ để tối ưu metric.

## 3. GATE B — UX/HCI toàn ứng dụng (P2 + Editor P3)

- Audit lại các tác vụ: launch→Record handoff P1; Screenshot→Photo; browse→preview→share; create draft→edit→export; Help→resolve issue.
- Home/Video Library: primary CTA reachable, status/copy dễ hiểu, không trưng thông tin kỹ thuật dày đặc, empty library có bước tiếp theo; search/filter chỉ nhấn mạnh khi có nội dung hữu ích.
- Bottom nav 4 tabs + Create action, reselect scroll-to-top, restore state, Back gestures; no overlay intercept/route stack loss.
- Video/Photo Editor: preview lớn đủ nhìn, action Save/Export dễ tiếp cận, timeline controls đủ lớn, text/sticker/audio layer selected state rõ, không kéo nhầm, không giấu Undo/Redo.
- Cỡ chạm tối thiểu 48dp (bao gồm semantic hit area), contrast/theme Dark/Light, font Manrope offline/Lucide nhất quán, screen readers label/value/action, keyboard and text scale200%.
- Standard dialogs/sheets/microcopy, error/retry, feedback/haptics có ý nghĩa. Giữ Reduce Motion; không thêm heavy stagger/blur.
- Kiểm tra Android accessibility/TalkBack focus order và custom drawing controls; **ADB injected taps không thay thế người dùng sử dụng TalkBack bằng cử chỉ**.
- Làm test script 8–10 tác vụ cho người thật, cả tay trái/phải và 2 cỡ máy; nếu không có người tham gia, ghi **NOT TESTED** chứ không tự suy ra điểm hài lòng.
- Sửa UI chỉ khi có vấn đề có thể tái hiện hoặc rõ ràng cải thiện journey; chụp before/after cùng viewport.

## 4. GATE C — Offline AI Subtitles correctness, usability & speed (P3)

### C1. Verify pipeline đã có

- `video → audio composition/edits → mono16k PCM → whisper.cpp JNI → timed cues → edit → SRT/burn-in MP4` thật.
- Verify model download/import/remove có user action, consent, SHA256/size check, atomic installation, interrupted download/cancel; model nằm app private/no-backup và không bị xóa bởi QA.
- Verify vi/en/auto language, silence handling (no hallucinated cues), 10-minute job bound, RAM preflight, cancellation and late-result guard, job restore after process restart.
- No upload/network transcription, no API key, no fake subtitles, no costs/backend work.

### C2. Benchmark thực tế có ý nghĩa

- Mở rộng corpus giọng Việt: nam/nữ, vùng Bắc/Trung/Nam khi dữ liệu được phép sử dụng, tốc độ nói khác nhau, dấu/tên riêng, im lặng, nhạc và nhiều mức noise. Thêm English controls.
- Chia subsets rõ, n và duration; CER/WER cách normalize minh bạch và xem thủ công sample errors. Không lấy một FLEURS clip làm độ chính xác chung.
- tiny/base/small-q5_1: RTF, median/p95 processing time, model load time, peak RAM/PSS, cancellation latency, thermals và battery nếu có physical device.
- Đề xuất **default model theo benchmark**; có lựa chọn Fast/Balanced/Accurate chỉ nếu thật sự tương ứng model khác nhau, giải thích RAM/storage và chất lượng dự kiến bằng copy dễ hiểu.
- Test edited audio (trim/speed/fade/noise/voice), timestamps sau speed2, segment overlap/silence, long text, Vietnamese diacritics, phone rotation, background/resume.

### C3. Subtitle export

- Preview and native burn-in same timing/style; verify time bounds, top/bottom safe area, long lines, Unicode, text scale, visual contrast trên video sáng/tối.
- Export SRT qua SAF Create Document, UTF-8 đúng, permission cancellation không tạo false success.
- MP4 exported sample frames during/after cues; audio track retained and A/V sync not altered beyond intended transforms.

### C4. Acceptance

- Không sửa P1 recording audio. Không chuyển sang paid API.
- Có kết luận có bằng chứng về default model, real-device performance hoặc limitation khi chưa có máy thật.
- F41/F42 chỉ DONE nếu native AI chạy thật với fixture đa dạng và xuất phụ đề đúng; clinical-like exact accuracy claims bị cấm.

## 5. GATE D — Video/audio editor real-world validation (P3)

- Real input matrix: video có/không audio, mono/stereo, sample rates khác nhau, 24/30/60fps, H.264/H.265 nếu hardware support, variable bitrate/FPS nếu fixture, rotation metadata, mixed image/video, very short/long durations.
- Timeline: trim/split/merge/reorder/duplicate/relink, seek with transform changes, pause/restore, Undo/Redo50, drafts migrations.
- Multitrack: up to 8 audio tracks; source in/out vs output offset; fade bounds, gain/headroom, clipping, legacy music mix, mute, missing track, late source, time stretching.
- Voice presets deep/bright/robot, RNNoise actual speech/noise, multichannel output. Compare A/B listening and objective signal; **RMS/SI-SDR alone not user listening signoff**.
- Layers max 40, text/sticker/drawing normalized coordinates, transform/rotation/opacity/timing/shape, portrait/landscape aspect, output pixel comparison at active/inactive frames.
- Export: queue job lifecycle preparing→running→finalizing→completed/failed/cancelled, progress, cancel/retry, immutable input, pending MediaStore publication, valid MP4/GIF with actual frames/audio, no double submit or orphan URI.
- Validate full decode, duration/PTS, codec, dimensions, actual audio listening on device, A/V sync at start/middle/end, preview/output parity; no claims from silence-only fixtures.
- Compression/GIF: size/quality, non-memory-bloating, repeat/range/FPS correct.
- Photo EXIF1–8, DisplayP3→sRGB, transparent PNG, JPEG quality, resize, high-res memory, Save Copy and untouched original hash; canvas semantics.
- Do not rewrite functioning Media3 composition/renderer without reproducing a bug. Reuse existing native modules and tests; source provenance remains documented.

## 6. GATE E — Data safety, SAF, lifecycle and fault injection (P2/P3)

- Test valid/revoked persistable URI grants, disconnected external destination, read-only source, SD card when present, duplicate names, media rename/trash/restore, SAF copy+move with read-back hashes; source delete only after verified destination and genuine permission.
- Protect app-owned vs external content; no accidental deletion of user data. Trash TTL cleanup only on controlled test fixtures, not user collection.
- AtomicFile recovery: valid, backup-only, corrupted, UTF-8 >1MiB, process killed during autosave; release resources and show recoverable errors.
- Export fault matrix: low storage/preflight, journal write EACCES, encoding cancel, process kill, MediaStore commit window, crash/restart, long video with temp reserve; preserve existing outputs and no orphan rows.
- No actual filling of a physical/user disk or permission bypass. On test AVD use bounded fault injection/simulated failures; mark *actual ENOSPC not tested* if unsafe.
- Native requestCode ownership: P2/P3 1701–1705. **Audit apparent overlap “P1 702–706 / SupportBridge 704”** to determine whether collision is real. P1 path read-only; if it is a genuine issue, document reproducible steps and create an integration request for the owner, don't edit P1 silently.
- Maintain source/hash tests of P1 untouched files with current baseline. Final P1→P2→P3 integration gate remains external until teammate's code merged.

## 7. GATE F — Android API/device matrix, performance soak and APK QA

- Run supported API target matrix on **verified disposable test devices** when available, not user's everyday device: API24/28/29/33/35/36, relevant Android/OEM differences, 32/64bit ABIs.
- Actual physical Android device(s) if connected and authorized: test hand reach, thermal/battery, 10-minute AI, long recording media import, export and A/V sync, memory/resource leaks, TalkBack gesture/focus, SD/SAF.
- When physical device unavailable, write exact `NOT RUN — requires device X` gate; **do not substitute AVD PASS**.
- Soak tests: repeated editing, open/close 30x, 20 export/cancel, 10 model load/infer/unload; capture logcat and memory without copying private media.
- Analyze/format/full tests, native integration, release QA unsigned APK packaging; validate ABI, ELF/ZIP16KB alignment, plugin registrant, actual `lib/main.dart` entrypoint. Do not sign or publish.
- If bug is in P1 capture, create an issue/contract request instead of touching their branch. Do not claim P1 regressions passed solely because source diff=0.

## 8. Implement & verify workflow (do not stop at reporting)

1. **Baseline**: gather genuine source evidence and deterministic fixtures; rank P0(data loss/crash), P1(main UX/performance), P2(polish/edge); show compact plan.
2. **Perf first**: profile Library raster and memory, implement one bounded fix at a time, remeasure; if software GPU bottleneck, move to other independently verifiable gates.
3. **ASR and media**: broaden corpus and actual audio/video tests; fix any user-impacting subtitle or playback defects and reverify.
4. **Data safety**: run safe fault matrix, protect originals, no transient “success” before MediaStore commit.
5. **UX**: refine high-impact journey issues, test Light/Dark/text200/one-hand/TalkBack; retain app visual identity and feature contracts.
6. **Final QA**: repeat complete regression across relevant devices, package QA APK and update docs.

Never use `git reset --hard`, destructive cleanup or undocumented overwrite. Preserve uncommitted changes belonging to others. No commits/push/PR without user approval.

### Required outputs

Create/update:

- `docs/implementation/P2_P3_FINAL_QUALITY_REPORT_VI.md` — verdict with DONE/PARTIAL/BLOCKED/NOT RUN.
- `docs/implementation/P2_P3_FINAL_QA_BASELINE.md` — source and baseline status.
- `docs/implementation/P2_P3_PERFORMANCE_BEFORE_AFTER.md` — raw metrics, traces, environment, n, before/after charts or tables; explain confounders.
- `docs/implementation/P2_P3_AI_SUBTITLE_EVALUATION.md` — model/corpus/CER/WER/RTF/RAM/accuracy caveats.
- `docs/implementation/P2_P3_DEVICE_MATRIX.md` — per-API/OEM/physical tests and unverified gates.
- Update `P2_P3_TEST_EVIDENCE.md` / `P2_P3_MASTER_PROGRESS.md` with source paths, test commands, actual outputs and reproducible evidence. No inflated completion percentages.

In every report separate:

1. **Implemented and verified now**.
2. **Implemented but not independently verified**.
3. **Not implemented**.
4. **Blocked by external access** (real phone, user tester, P1 merge, model corpus, etc.).

Include final list of actual modifications, tests/pass/fail, source-diff for P1, APK paths/hashes if built, risks, next steps. Avoid giant unstructured logs; link evidence files.

### Final acceptance rules

- Do not mark P2/P3 production-ready based on synthetic fixtures, emulator only, or aggregate test pass counts.
- Fix true reproducible severe issues before adding cosmetic animation.
- `flutter analyze` clean, all existing tests pass plus new regression tests. Any skip explicitly explained.
- Real media audio/video/still/GIF/SRT output correct and source preserved.
- Perf measured honestly, residual jank explained; no false 60fps claim.
- Whisper.cpp real on-device, model management and multilingual ASR verified; long-form device limitations disclosed.
- Physical/HCI/Full P1 integration gates **must remain OPEN** if not executed; do not self-certify them.
- App launch/navigation/P2/P3 editor still work on QA APK. P1 code untouched.

**BẮT ĐẦU NGAY. ĐỌC CÁC FILE HIỆN TẠI, CHẠY BASELINE AN TOÀN, CHẨN ĐOÁN VÀ SỬA CÁC VẤN ĐỀ THỰC TẾ, ĐO LẠI, ĐÓNG CÁC GATE CÓ THỂ ĐÓNG. KHÔNG DỪNG Ở MỘT BẢN AUDIT.**
