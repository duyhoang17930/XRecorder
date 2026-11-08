# TASK 08 — PERFORMANCE, MEMORY, DATA SAFETY & ANDROID DEVICE COMPATIBILITY

**Project:** 3HRecorder / XRecorder — Flutter + Android native  
**Ngày:** 08/11/2026 · **Model đề xuất:** GPT-6 Astra, Extra High / xhigh  
**Loại task:** Audit → profile → sửa root cause → regression → nghiệm thu có bằng chứng. **Phải code và test, không dừng ở kế hoạch.**

## 0. Goal và trạng thái bàn giao

Bạn tiếp quản **TASK 08** trên **working tree hiện tại** của 3HRecorder, tiếp nối TASK 07. Mục tiêu là tối ưu hiệu năng và độ bền vững trên thiết bị Android đa dạng, giữ nguyên những chức năng P2/P3 và global đã triển khai, **không đụng P1**.

Đọc source cùng các tài liệu trong repo trước khi làm:

- `P2_P3_CONTRACTS.md`, `P2_P3_CURRENT_AUDIT.md`, `P2_P3_MASTER_PROGRESS.md`
- `P2_P3_TEST_EVIDENCE.md`, `P2_P3_DEVICE_MATRIX.md`, `P2_P3_FINAL_QUALITY_REPORT_VI.md`
- `P2_P3_AI_SUBTITLE_EVALUATION.md`, `REUSE_REGISTER.md`
- `TASK_07_BASELINE_AUDIT.md`, `TASK_07_GLOBALIZATION_MATRIX.md`
- `TASK_07_ASR_CONTRACT_AND_BENCHMARK.md`, `TASK_07_SIZE_REPORT.md`
- `TASK_07_TEST_EVIDENCE.md`, `TASK_07_FINAL_REPORT_VI.md`, `TASK_07_P1_I18N_HANDOFF.md`
- Tài liệu checklist TASK08 đính kèm.

**Các con số sau được trích từ báo cáo TASK07, chưa phải phép đo độc lập tại TASK08:**

| Metric / issue | Trạng thái bàn giao |
|---|---|
| Library same-corpus nearest-rank p95 | Baseline build/raster **4.636 / 41.426 ms** → median3 final **8.202 / 45.602 ms** |
| Corpus | Baseline **1013** item, final query thực tế có **1015** hàng; host shared / SwiftShader, chưa cô lập được nguyên nhân |
| G6 performance gate | **OPEN**; không có bằng chứng 60fps, không được gọi là đã cải thiện |
| ASR history | Writer cũ cap20 đã làm mất một phần lịch sử job QA API36; code mới giữ **77 jobs** và nhiều bản ghi legacy, **không được bịa khôi phục các job mất** |
| Low-memory | Một thử nghiệm **2GiB/16KB** bị OS LOW_MEMORY kill; đã thêm admission preflight, không chứng minh mọi máy2GiB an toàn |
| Android devices | QA API36/API34 và 16KB x86_64; runtime ARM64/ARMv7, OEM/SD/thermal chưa kiểm |
| Build size | Unsigned universal release **66.456 MiB**; true arm64 release split **23.746 MiB**; không bundle Whisper weights |
| Workspace | ~**40.922 GiB**; build ~35.499GiB, `.dart_tool` ~4.799GiB; **không phải app install size** |
| Automated | Flutter **228 PASS**; Android JUnit **10 PASS** ở checkpoint TASK07 |

Đầu ra cần **root-cause evidence, code fix được chứng minh, before/after hợp lệ**, không chỉ report hoặc tăng cache một cách cảm tính.

## 1. Ownership, privacy, safety — bất biến

**P1 đang do người 1 phụ trách và có thể làm song song.** Read-only:

- `lib/features/recording/**`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**`
- `lib/features/settings/recording_settings_form.dart`
- `lib/features/settings/audio_video_settings_screen.dart`
- `lib/core/widgets/studio_create_sheet.dart` đối với capture semantics
- Recording pipeline, muxer, permissions/events/native capture channels, Facecam, recording settings.

`MainActivity` chỉ thêm/sửa thành phần P2/P3 khi có lý do được chứng minh; giữ nguyên P1 registration. Nếu phát hiện performance issue thuộc P1, lập `TASK_08_P1_PERFORMANCE_HANDOFF.md`, **không sửa P1**.

**Không chạy:** `git reset --hard`, `git checkout --`, `git restore` lên file dirty, reconstruct file từ HEAD, Python script ghi đè file nguyên khối, `git clean`, `flutter clean`, xóa build/QA outputs, xóa media/drafts/models, dọn 40GB để tăng metric, uninstall, clear-data, wipe. Lỗi từ chối approval của `settings_controller.dart` trong TASK07 đã được xử lý bằng **targeted patches**; không tái diễn.

**Không commit/push/PR/publish/sign**, không động billing/ads/Pro/Play Console, không tự sửa contract P1 khi chưa được phối hợp. Giữ toàn bộ existing uncommitted/untracked user changes.

Mọi test destructive (disk full, process kill, faulty storage) chỉ thực hiện trên fixture/AVD riêng có ownership/backup và cách restore rõ ràng; không giả định sự cho phép từ việc đã có `adb`.

## 2. M0 — Rebaseline và reproducible performance methodology

1. Ghi `git status --short`, HEAD, Flutter/Dart/AGP/Media3/whisper versions, target, device/ABI/graphics backend, profile/release mode, CPU/RAM/refresh rate; bảo lưu mọi dirty change.
2. Xác minh current QA APK/source đúng checkpoint. Không dùng số đo từ APK cũ để kết luận về code mới.
3. Kiểm tra fixture count, identity, sort, source, modified time, image dimensions, query state: **1013 và 1015 không được coi cùng dataset nếu chưa chứng minh**. Hash manifest/corpus; không seed/delete trên AVD người dùng.
4. Thiết kế workload cố định: cold/warm launch, 30 swipe giống nhau (start offset, gesture duration/distance, viewport 320/411dp, text scale, locale, theme), stop/idle/reentry, media change. Tách measurement của **build, raster, GPU/UI thread, decode time, thumbnail cache**, và overhead từ test harness.
5. Tối thiểu 3 lần warm-up + 5 measurement trials khi khả thi; phân phối và thứ tự trials có kiểm soát. Lưu raw frame timings; báo `p50, p90, p95, p99`, số frames >16.67ms và >33.33ms, CPU/PSS, nhiệt nếu có. Ghi chính xác phương pháp percentile (nearest-rank vs interpolation).
6. Benchmark **profile build**, không debug; sử dụng Flutter DevTools Performance view, CPU profiler, Memory view/snapshot Diff, Android Perfetto/FrameTimeline hoặc Android Studio profiler nếu có. Giữ trace liên kết với source hash.
7. Đối chiếu baseline chính xác như phương pháp. Nếu không thể chạy code cũ mà không hủy dirty work, **không checkout/reset**; dùng traces/corpus đã giữ, hoặc an toàn xây biến thể có thể so sánh trong workspace cô lập nếu được phép. Ghi `INCONCLUSIVE` khi A/B không ngang nhau.

Deliver `TASK_08_PERFORMANCE_BASELINE.md` gồm methodology, device noise, artifact manifests, current gate status.

## 3. M1 — Điều tra và xử lý UI jank đúng root cause

**Ưu tiên 1: Library** vì G6 p95 cao hơn baseline và user nhìn thấy lag khi cuộn. Xem xét có đo lường:

- MediaStore observer/refresh phát sự kiện lặp; sort/search/filter lại toàn bộ list, item identity/key changes, rebuild trên scroll.
- Thumbnail decode/resizing, cache key `(URI, revision, modifiedTime, size)`, eviction/memory pressure và image downscale.
- Decoding cả ảnh gốc/EXIF trong build frame, synchronous I/O trên main isolate, native↔Dart method channel quá dày.
- Repaint boundaries, overdraw, clipping, BackdropFilter, transparency, shadows, large raster layers, text layout khi đổi locale/RTL.
- Jank do `ScrollController`, nested scrollable, item measurement, garbage collection, shader warmup, SurfaceView/Media3 preview/lifecycle.
- Globalization đổi `Localizations`/locale làm rebuild không cần thiết, giant ARB resources, expensive formatting trong `build`, overflow relayout.

**Quy trình:** xác định hot path bằng trace → smallest safe patch → rerun same dataset → giữ nếu đạt observable improvement; nếu không, revert **chỉ thay đổi của task đó** bằng patch có chủ đích (không restore file user), báo failed experiment. Không thêm cache vô hạn hoặc predecode 1000 thumbnails để đổi jank lấy OOM.

**Ưu tiên 2: Editor/Preview/Export UI**:

- Mở project mixed still/video, scrub, trim, split, speed, zoom, seek, layer drag, subtitle edit, track audio, chuyển tabs, background/foreground.
- Không mất playhead, không stale async result, không black preview sau locale/theme change. Preview/export parity của composition giữ nguyên.
- Không rebuild toàn bộ timeline trong mỗi tick không cần thiết. Không giảm chất lượng preview/export hoặc silently skip effect để tăng FPS.
- Native Media3 release/Texture/SurfaceView lifecycle: soak lặp lại; kiểm đo retained objects/pending listeners, job cancel/cleanup.

**Gate:** Native frame evidence trước/sau cho từng sửa. 60Hz (16.67ms) là **budget tham khảo**, không tự hứa đạt trên SwiftShader. Trên thiết bị thật cần đo khả năng đáp ứng theo tần số màn hình thực tế; không đánh fake PASS nếu thiếu máy.

## 4. M2 — Memory, native resources & Whisper stability

Kiểm tra vòng đời theo workflow, **không chỉ peak một lần**:

1. Library 1000+ media: 10 lần vào/ra, scroll, thumbnail invalidation, process background/foreground; retained image bytes và native bitmap count.
2. Editor: 10 lần open/close dự án, 30 preview/reload, 20 export cancel/retry, undo history/draft autosave; leak/OS kill/JNI cleanup.
3. AI Whisper Tiny/Base/Small-q5_1: cold model load, warm inference, cancel mid-decode, repetitive inference, long input up to existing 10min bound, vi/en/auto + representative global locales. Đo model load latency, RTF, PSS/USS/native heap, CPU, thread counts, thermal nếu có.
4. Audio RNNoise: 8 tracks, fades/voice + denoise, native buffer/sample duration parity; tránh copy PCM thừa và temporary audio orphan.
5. **2 GiB low-memory**: giữ failed case của TASK07; mô hình RAM admission phải tính realistic available/process memory và native audio/PCM buffers, tránh OOM/lmk; chủ động reject với thông báo rõ **trước JNI** nếu không đủ. Không giả thử nghiệm 2GiB PASS từ 3GiB result.
6. 16KB x86_64 runtime kết quả lịch sử phải giữ; ARM64 16KB runtime `NOT RUN` nếu không có đúng device. Static 16KB packaging không thay runtime evidence.

Memory leak chỉ được kết luận dựa trên **retained allocation/delta snapshots và repeated flows**; peak PSS đơn lẻ không chứng minh leak. Xem Android OS LMK log nếu không cần quyền vượt scope.

## 5. M3 — Data durability và ASR history: P0 không tái mất dữ liệu

Lỗi lịch sử đã xảy ra: prior writer auto-pruned >20 jobs, một số job QA đã mất, **không thể tái tạo bằng transcript giả**. TASK08 phải coi đây là safety issue cần regression coverage, không chỉ tăng cap.

- Inspect job storage and journal write transactions for bounded memory/disk. Không silently truncate bản ghi thật. Nếu cần retention policy, phải có yêu cầu sản phẩm/consent và cơ chế backup/export, không tự xóa; nếu không, dùng lazy pagination/indexing, không mất entries.
- Test 0/20/21/77/100/1000+ jobs trên QA fixture: create, list, paginate, cancel, resume, reorder, restart, process kill, corrupt record, unexpected future schema, UTF-8/Unicode.
- Bảo đảm old `vi/en/auto` jobs và new language fields + `modelLoadMs/inferenceMs` additive mở lại đúng; không overwrite unknown future version; corrupted record isolated.
- Test AtomicFile/temporary write, journal EACCES, interrupted checkpoint, full queue, duplicate id, renamed project, deleted source/permission revoke, stalled export after background, MediaStore finalizing replay; không xóa original source.
- Phân biệt user media, exports, drafts, downloaded models, app cache, QA jobs; chỉ được quản lý/xóa đúng scope, recoverable where possible.
- Khi crash/LMK xảy ra: state phải rõ (Failed/Interrupted/Retry), không fake Saved, không duplicate URI. Native files checksum/read-back và trace publisher.
- Viết thông báo lỗi hỗ trợ 12 locale, không leak nội dung transcript/media trong logs.

Deliver `TASK_08_DATA_SAFETY_REPORT.md` có test cases và giải thích lịch sử đã mất không được tuyên bố phục hồi.

## 6. M4 — Device compatibility & Android matrix

**Kiểm thử trên những thiết bị/AVD đang có quyền**, không tự bypass access, root, chmod hay wipe.

| Nhóm | Mục tiêu | Nếu không có device |
|---|---|---|
| API36 x86_64 QA | Full regression, profile, SAF, editor, ASR, native output | Blocker trung thực |
| API34 x86_64 QA | Cold/warm app, library, mixed editor, cancel, model | Blocker trung thực |
| 16KB x86_64 QA | JNI load/inference, Media3 output, SAF/locale and process restart | Blocker trung thực |
| ARM64 thật (4/6/8GiB nếu được) | FPS, PSS, heating, 10min ASR, long MP4 export | `NOT RUN`, không mượn x86_64 làm bằng chứng |
| ARMv7/API24–33 | Native binary/decoder/permission/legacy MediaStore, low RAM | `NOT RUN`; có thể test AVD nếu image và quyền hợp lệ |
| OEM/SD/removable SAF | Copy/move/restore/revoked grant/disconnect | `NOT RUN` |

Không tự cài vào **emulator cá nhân `emulator-5554`**, không uninstall/clear app data hoặc dùng source người dùng làm fixture. Nếu chỉ có QA x86_64, chỉ kết luận x86_64. Giữ thiết bị QA và mọi file hiện có; biết chính xác target trước khi chạy test.

## 7. M5 — Disk size, cache & application package

- Re-audit workspace ~40.922GiB bằng read-only breakdown; phân loại `build/verification`, Flutter/Gradle cache, model, asset, user media; **không dọn file hoặc xóa bất cứ gì** trong TASK08.
- Đo APK universal vs split ABI thực tế, AOT/assets/font/native breakdown; không nhúng Whisper weights. Không dùng debug APK để báo release size.
- Đo installed data (có thể khác APK): private model store, thumbnail cache, drafts, temporary renders, MP4/GIF export, duplicated media, temporary partial publication.
- Khi cancel/fail/retry, file temp có bị orphan không; cleanup theo ownership an toàn, không đụng original/SAF external files không thuộc app.
- Trình bày đối chiếu size baseline (TASK07 universal66.456MiB/split arm64 23.746MiB) và size sau code change, phân tích nguyên nhân nếu tăng.

Deliver `TASK_08_STORAGE_SIZE_REPORT.md`. Một file 40GiB trong workspace không đồng nghĩa app sẽ 40GiB trên máy thật.

## 8. M6 — Test matrix, QA scripts và quality gates

Thực hiện `flutter analyze --no-pub`, `flutter test --no-pub --reporter expanded`, Android JUnit, UI/Integration test và native media signal/pixel/PTS. Thêm **regression tests mới** cho mọi lỗi sửa. Không coi tổng 228/10 test của TASK07 là PASS mới nếu không chạy trong source TASK08.

Yêu cầu tối thiểu:

1. Flutter frame metrics on QA AVD **before/after** bằng raw frames, same corpus, same host/runtime flags, random/order-controlled 5 trials khi khả thi. Include p50/p95/p99, jank count, timestamp and confidence/limitations.
2. Repeated lifecycle reliability: 30 preview open/close; 20 export cancel/retry; ASR cancel/drain; no unbounded jobs/listeners/cache growth.
3. Export source parity: ≥12 audio/layer MP4 fixture decoding/signal checks; EXIF/ICC/PNG/JPEG; subtitle CJK/RTL/vi/en, SRT byte exact, speed timing; no user media deletion.
4. Job history at 1000+, interrupted restart, future/corrupt journal read-only recovery, no pruning.
5. 2GiB low-memory negative case: expected rejection or actual controlled inference, log LMK truthfully; unknown results not PASS.
6. Locale 12 screen representative smoke, especially Arabic RTL, German/French long strings; performance changes không làm mất localization.
7. Safety: source/outputs exact bytes when appropriate, no double MediaStore publication, no late canceled callbacks; duplicated source preserved.
8. Static ABI/16KB, signed QA/profiling APK install on **authorized AVD**. Unsigned release only packaging/size, không tuyên bố đã nghiệm thu runtime release.
9. P1 read-only integrity check comparing **TASK08 start snapshot**, not only older commit, since concurrent owner may modify P1.
10. `git diff --check`, summarize changed files/ownership, note preexisting dirty user work and any blocked tests with precise reason.

**Gate rules:**

- `PERFORMANCE PASS`: repeated comparable measurements show no meaningful regression on the tested environment and no new severe interactive lag; report variance/confidence. 60fps claim requires target device evidence.
- `MEMORY PASS`: bounded resource use with repeated action sequences; no unexplained retained growth or user-data loss, and low-RAM safety behavior verified where possible.
- `DATA PASS`: no silent history truncation at 21/77/100/1000+, durable recovery, preserve original input, no duplicate completed output.
- `DEVICE PASS`: only for devices/APIs actually run; all others remain `NOT RUN`.
- `P1 INTEGRATION`: `OPEN` until person 1 provides ready build and user explicitly initiates integrated acceptance.

If a gate cannot close, **do not fake DONE** or spend unlimited time modifying unrelated code; report `PARTIAL/INCONCLUSIVE/NOT RUN`, focus measurable high-priority defects.

## 9. Deliverables bắt buộc

Create these **new files** under an appropriate docs/report directory in the repo, preserving older TASK07 evidence:

1. `TASK_08_CURRENT_AUDIT.md` — source ownership, exact issues, changed files, P1 snapshot.
2. `TASK_08_PERFORMANCE_BEFORE_AFTER.md` — baselines/method/trace raw paths/paired results/analysis/remaining jank.
3. `TASK_08_MEMORY_THERMAL_REPORT.md` — PSS/heap retained, native/Dart CPU, ASR models, resource lifecycle and limits.
4. `TASK_08_DATA_SAFETY_REPORT.md` — ASR history, AtomicFile/jobs/drafts, data-loss and recovery matrix.
5. `TASK_08_DEVICE_MATRIX.md` — API/ABI/renderer/physical device, PASS/NOT RUN and evidence.
6. `TASK_08_STORAGE_SIZE_REPORT.md` — desktop build vs APK split vs actual installed data, no destructive cleanup.
7. `TASK_08_TEST_EVIDENCE.md` — exact commands, source hashes, input/output fixtures, failed attempts, retry and raw logs.
8. `TASK_08_FINAL_REPORT_VI.md` — concise Vietnamese delivery: what changed, what genuinely improved, what remains open, P1 unchanged proof, QA APK paths/hashes and handoff to TASK09.

Do not overwrite TASK07 docs to erase prior failures or measured regressions. Keep evidence `build/verification/task08/` scoped and recoverable. For every `DONE`, cite exact test case/output file; do not count screenshots or UI-only mocks as processing backend PASS.

## 10. Execution policy

Implement in order **M0 baseline → M1 UI performance → M2 memory → M3 data safety → M4 devices → M5 size → M6 regression/delivery**. Priority exception: if silent data deletion or source-corruption issue is found, address P0 safety before cosmetic FPS gains. Provide checkpoints and continue until in-scope implementation/relevant tests complete, or a real permission/device blocker is reached.

**Don't request broad/destructive approval to bypass an access denial.** Use safe alternatives within scope; if real device/permission/P1 owner is required, record blocker and ask for user coordination instead of inventing access.

Expected final verdict structure in Vietnamese:

```
TASK08 VERDICT: IMPLEMENTED / PARTIAL / BLOCKED
Current source HEAD + dirty tree summary:
P1 unchanged evidence:
Main performance measurements (before vs after):
ASR RAM / 2GiB results:
History retention & data integrity:
Device matrix and physical gates:
APK / installed size:
Regressions (including old failures):
Next: TASK09 Full Functional + HCI QA; TASK10 P1 integration after P1 ready.
```

**BẮT ĐẦU AUDIT SOURCE THỰC VÀ IMPLEMENT. Không chỉ trả lời bằng plan.**

### Reference — official primary documentation (read when necessary)

- Flutter Performance Profiling: https://docs.flutter.dev/perf/ui-performance
- Flutter DevTools Performance: https://docs.flutter.dev/tools/devtools/performance
- Flutter Memory View: https://docs.flutter.dev/tools/devtools/memory
- Android PSS/Memory diagnosis: https://developer.android.com/tools/dumpsys
