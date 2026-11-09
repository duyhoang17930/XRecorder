# Task 00–06 — Local Fix Report

Ngày: 2026-11-08. Branch `feature/capture-live`, HEAD `4ce6a53` và working tree chưa commit có sẵn. **PARTIAL — local verification; không đánh dấu Task 00–06 DONE.**

## 1. Summary

Trong phạm vi LOCAL mới, có chạy trên điện thoại không: **NO**. Không chạy ADB, Flutter run/drive, emulator, instrumentation hoặc cài app sau yêu cầu chuyển phạm vi. Chỉ dùng test Ubuntu, Android SDK compile và evidence đã lưu. Không cập nhật kết quả trong [báo cáo thiết bị cũ](TASK_00_06_REAL_DEVICE_TEST_REPORT.md).

- P1-01: sửa phục hồi kích thước PNG; mapping/replay và dimensions helper được kiểm chứng local. Android process restart/URI access còn cần thiết bị.
- QA-02: sửa finder của integration test, giữ kiểm tra URI/MP4 và UI visibility; lazy-list regression PASS local.
- Unsupported selection: sửa capability/validation/callback P1; shared defaults/restore còn cần P2.
- QA-01: cleanup được bảo vệ khi có exception; bốn Cancel states PASS local không leak semantics. **Chưa xác định dứt điểm handle gây FAIL trên Android; chưa tuyên bố fix full suite.**
- OBS-01/02: phân tích timestamp và frame an toàn cũ; không thay encoder, FPS, bitrate, aspect mapping hay overlay.

Continuity: trước khi yêu cầu LOCAL đến, một lượt Cancel debug đã được build/cài/chạy theo chỉ dẫn trước đó. Preflight không kết nối được platform semantics và suite FAIL tại setUpAll; cách đó đã được bỏ khỏi source. Artifact được tách ở [pre_local_scope_device_attempt](test_evidence/task_00_06_fix_retest/pre_local_scope_device_attempt/). Không tính đây là retest của bản sửa cuối. APK Cancel test là bản cuối đã cài theo phạm vi trước; không khôi phục/cài tiếp trên điện thoại vì yêu cầu mới cấm ADB. APK main mới chỉ được build local.

## 2. Fix Details

| Issue | Root cause / Before | After | Assessment |
|---|---|---|---|
| P1-01 | `snapshot()` persist root width/height, nhưng `CaptureJournal.initialize()` không restore trước khi save lại. Screenshot config là video preset; Dart null fallback không xử lý đúng metadata thiếu/0. | Restore cặp dimensions dương. Nếu journal cũ thiếu/0 và là completed screenshot, đọc bounds PNG từ chính output URI bằng bounds-only decode; không sửa file. URI không đọc được/ảnh invalid → unknown 0×0, không lấy physical display/video preset. Dart dùng root PNG dimensions, video dùng nested config hợp lệ rồi root fallback. | **FIXED — DEVICE VERIFICATION PENDING**; helper/mapping/replay PASS local. |
| QA-01 | Test P1 không gọi `ensureSemantics()` và không giữ handle riêng để dispose. Flutter testWidgets giữ handle của test; SemanticsBinding còn giữ handle riêng khi platform yêu cầu accessibility. Evidence cũ không đủ chỉ ra chính xác owner của handle dư. | Nested finally bảo đảm dispose controller/subscription/catalog kể cả khi current/cancel lỗi; thêm log platform/handle ở đầu/cuối. Không dispose handle thuộc framework/platform, không disable validation/skip/bỏ assertion. Local diagnostic xác nhận platform client có thể tăng counter riêng và detach giải phóng đúng API test. | **PARTIAL / INVESTIGATION REQUIRED** cho Android. Cleanup hardening và local Cancel semantics PASS; không suy full integration PASS. |
| QA-02 | Chờ `find.text` thuần túy không build được video row trong lazy SliverList dưới header/filters. MP4 published và hàng tồn tại sau scroll theo evidence cũ; chưa chứng minh refresh production lỗi. | Đối chiếu displayName duy nhất với URI thật, cuộn đúng CustomScrollView với giới hạn 40 lượt × 300dp, 200ms mỗi lượt, rồi assert hitTestable. Không thay MediaStore-only cho UI assertion; không thêm fixed sleep dài. | **FIXED — DEVICE VERIFICATION PENDING**; same finder helper PASS với lazy mock, missing target vẫn fail có giới hạn. |
| Unsupported selected | Defaults/requested settings chưa được capability validate. HEVC từng dùng boolean tổng quát thay exact tuple; resolution bị disable theo FPS cũ có thể khiến người dùng không chọn được tuple hỗ trợ. Native preflight vốn đã reject hoặc áp Performance policy. | Filter exact codec/resolution/FPS; resolution được chọn nếu có FPS hỗ trợ. Chỉ khi người dùng chọn resolution mới, cập nhật FPS hỗ trợ trong chips hiện có. Start kiểm tra capability/audio và Performance ceiling trước native call, dùng error flow hiện có, không tự thay preference khi load. | **FIXED & LOCALLY VERIFIED** cho guard/callback P1; shared stale preview/defaults **PARTIAL**, IR-00-06-01. |
| OBS-01 | 4230/300.312 ≈14.085 là average sample rate, không chứng minh encoder lỗi hoặc CFR. | Phân tích thêm stts/ctts của hai MP4 own-app cũ; timestamp biến thiên, không có delta không dương trong mẫu. Không đổi pipeline. | **INVESTIGATION REQUIRED** — cần motion/input cadence/thermal benchmark, không chạy Android trong phase này. |
| OBS-02 / overlay | Portrait source trong landscape canvas; video overlay chưa có pixel evidence được phép kiểm tra. | Đo frame cũ khớp pillarbox do fit aspect. Không crop/stretch/FLAG_SECURE hoặc thay UI overlay. | Aspect của các mẫu cũ: **ANALYZED**. Overlay MP4: **NOT VERIFIED**. |

### Source/test files

Production P1:

- [CaptureJournal.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureJournal.kt) — restore dimensions và bounds fallback cho journal cũ.
- [recording_service.dart](../../lib/features/recording/recording_service.dart) — dimensions mapping; không thay session lifecycle/onSaved.
- [recording_setup_sheet.dart](../../lib/features/recording/recording_setup_sheet.dart) — validator và Start callback.
- [recording_settings_form.dart](../../lib/features/settings/recording_settings_form.dart) — capability predicate và resolution callback.

Tests/helpers: [CaptureJournalTest.kt](../../android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureJournalTest.kt), [recording_service_contract_test.dart](../../test/recording_service_contract_test.dart), [recording_replay_test.dart](../../test/recording_replay_test.dart), [recording_cancel_semantics_test.dart](../../test/recording_cancel_semantics_test.dart), [capture_library_finder_test.dart](../../test/capture_library_finder_test.dart), [recording_setup_sheet_test.dart](../../test/recording_setup_sheet_test.dart), [recording_cancel_test.dart](../../integration_test/recording_cancel_test.dart), [screenshot_native_test.dart](../../integration_test/screenshot_native_test.dart), [capture_library_finder.dart](../../integration_test/capture_library_finder.dart).

Replay không gọi prepare/start, không tạo ID/URI mới hoặc thêm transition/emit. Contract controller hiện tại vẫn refresh catalog một lần khi nhận bootstrap completed snapshot, không tạo Saved feedback mới; các replay tiếp theo không lặp callback/feedback. Local test kiểm tra chính xác semantics này, không tuyên bố persistent exactly-once Saved event qua mọi process. Native SharedPreferences + ContentResolver/PNG decode qua restart chưa chạy local.

## 3. Local Test Results

Evidence ở [task_00_06_fix_retest](test_evidence/task_00_06_fix_retest/).

| Command / scope | Result | Evidence / limit |
|---|---|---|
| `flutter test --no-pub test/recording_service_contract_test.dart test/recording_replay_test.dart test/recording_cancel_semantics_test.dart test/capture_library_finder_test.dart test/recording_controller_test.dart test/recording_setup_sheet_test.dart` | **PASS, 31 tests** | [local_tests_verified.log](test_evidence/task_00_06_fix_retest/local_tests_verified.log). Mapping, replay, Cancel states, lazy finder, no duplicate feedback, settings validation, layout assertions 320/360/411dp. |
| `flutter test --no-pub test/recording_cancel_semantics_test.dart` sau bổ sung platform diagnostic | **PASS, 5 tests** | [local_cancel_semantics_final.log](test_evidence/task_00_06_fix_retest/local_cancel_semantics_final.log). Bốn case đã chạy lại và một diagnostic mới: **32 Dart tests khác nhau**, không cộng thành 36. Mock platform flag chỉ dùng trong diagnostic và được clear ở finally; không áp lên integration test. |
| `./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'` từ android/ | **PASS, 24 tests / 7 suites** | [native_regression_final.log](test_evidence/task_00_06_fix_retest/native_regression_final.log), [summary](test_evidence/task_00_06_fix_retest/native_test_summary.json), JUnit XML. Gồm 3 CaptureJournal dimensions helper tests, screenshot packing, timing, geometry, request identity, audio/video math, bitrate. Không phải instrumentation. |
| Native journal serialization/SharedPreferences/URI replay trên Android | **NOT RUN / DEVICE REQUIRED** | Không có local Android framework runtime/Robolectric được thêm. Helper tests không thay thế Android process restart. T06-19 lịch sử không chuyển thành PASS. |
| Full native Cancel / Screenshot integration suites của bản sửa cuối | **NOT RUN / DEVICE REQUIRED** | Analyzer/build không được tính là suite PASS. Các Cancel scenarios, Saved/catalog assertions và PNG/MP4/UI assertions vẫn được giữ. Khi retest screenshot trên thiết bị sau này phải dùng `PRESERVE_TEST_OUTPUTS=true` để không chạy cleanup xóa output test. |

Các log iteration thất bại được giữ: fixture capabilities ban đầu thiếu tham số, fixture valid dùng nhầm default 60FPS/16Mbps, rồi assertions mới của finder về hàng lân cận/async guard. Đã sửa fixtures/negative test đúng mục đích; không bỏ assertion chức năng cũ hoặc đổi test fail thành skip. Kết quả cuối được lấy từ các log PASS nêu trên.

## 4. Static / Build Validation

- `flutter analyze --no-pub`: **PASS**, [local_analyze_verified.log](test_evidence/task_00_06_fix_retest/local_analyze_verified.log).
- `flutter build apk --debug --no-pub --target lib/main.dart --target-platform android-arm64`: **PASS**, [local_main_build.log](test_evidence/task_00_06_fix_retest/local_main_build.log), [APK hash](test_evidence/task_00_06_fix_retest/local_main_apk.json). Build local; không cài và không chạy APK này.
- Native Kotlin compile/JVM regression: PASS như bảng trên. Các warning Gradle/Kotlin plugin có sẵn không được sửa ngoài phạm vi.
- `git diff --check`: PASS; inventory/hash/check ở [source_change_inventory.json](test_evidence/task_00_06_fix_retest/source_change_inventory.json) và [final_validation.json](test_evidence/task_00_06_fix_retest/final_validation.json). Không reset/restore/commit/push.

### FPS / aspect evidence cũ

[Timestamp analysis](test_evidence/task_00_06_fix_retest/fps_existing_evidence_analysis.json): clip 30s có 487 frames, median interval33.333ms, p99≈688.289ms, max≈722.133ms; clip60s có877 frames, median33.333ms, p99≈692.078ms, max≈712.311ms. Không có ctts trong hai mẫu; interval biến thiên cả khi bỏ final EOS tail, nên không gọi là CFR30. Đây là **output trước fix**, không phải benchmark mới. Không có input Surface cadence/motion/thermal data để phân biệt static-frame production, driver behavior hoặc load.

Source hiện đặt KEY_FRAME_RATE/KEY_MAX_FPS_TO_ENCODER và repeat interval theo target; dùng encoder PTS trừ pause duration, bảo đảm bước dương, giữ EOS tail. Không thấy bằng chứng đủ mạnh để sửa công thức từ các sample này. Không tạo frame giả hoặc đổi FPS/bitrate/codec.

[Aspect analysis](test_evidence/task_00_06_fix_retest/aspect_existing_frames_analysis.json): ba frame cũ 0/100/200 có canvas1280×720, content x=[478,802), rộng324px. Fit720×1600 theo scale0.45 cho đúng content324×720 và478px mỗi bên. Khớp pillarbox, không phải crop. VirtualDisplay và encoder dùng cùng config size. Không suy từ mẫu không overlay sang clip có overlay; clip2318 vẫn chưa được kiểm pixel và không được đọc lại.

## 5. Remaining Device Verification

- Screenshot completed → process restart → cùng ID/URI/dimensions; PNG decode, screenshot mới sau restart; old journal thiếu dimensions đọc đúng output thật hoặc giữ unknown an toàn.
- Full Cancel với consent thật, ghi platform semantics flag/counter tại START/END để isolate handle dư; không dispose handle của platform hoặc tắt leak validation.
- Screenshot suite: deny/back, countdown, hai PNG/View/feedback, video pause/resume/audio/MediaStore và row visibility sau scroll.
- Recording engine/audio/permission/background/timer/AVC/720p/orientation regressions: chỉ logic local được retest; native behavior **NEEDS DEVICE VERIFICATION**.
- Actual FPS với motion benchmark; audio source/gain/A-V sync; Android14+ app-window capture; stereo và concurrent screenshot vẫn giữ giới hạn từ báo cáo cũ. Không nâng NOT RUN/UNSUPPORTED thành PASS.
- Overlay rectangle/loại overlay khỏi output: **NOT VERIFIED**, không thêm FLAG_SECURE hoặc coi input flags là cơ chế ẩn video.

## 6. UI / Icon Freeze

Không thêm/xóa widget, chip, dialog, navigation, icon hoặc thay style/layout/animation production. Hai file presentation được chạm là RecordingSetupSheet và RecordingSettingsForm, chỉ validation/disabled predicate/callback; business state có thể đổi khi người dùng chọn resolution hoặc nhận error flow hiện có.

Bốn production files được đối chiếu lại với baseline SHA-256 trước task bằng cách dựng lại bản trước từ đúng các hunk sửa; cả bốn khớp baseline. Xem [production_incremental_diff.patch](test_evidence/task_00_06_fix_retest/production_incremental_diff.patch) và [baseline verification](test_evidence/task_00_06_fix_retest/production_diff_baseline_verification.json). Không có diff format toàn file ngoài các hunk logic này. P2/P3/shared UI/controller/Manifest/MainActivity/pubspec/Gradle không sửa. Các thay đổi có sẵn được giữ nguyên; báo cáo thiết bị cũ không đổi.

## 7. P2 Integration Requests

[IR-00-06-01](TASK_00_06_P2_FIX_REQUESTS.md): shared default/restore và global preview còn có thể selected unsupported trước khi vào P1 form. Không tự sửa shared settings_controller hoặc Media Library. Không có bằng chứng mới yêu cầu P2 sửa Library refresh.

## 8. Final Assessment

**PARTIAL.** P1-01 mapping/dimensions, QA-02 finder và P1 selection guard được sửa, có regression local. QA-01 cleanup đã được harden nhưng root cause handle Android và full suites còn pending; FPS cần investigation; overlay pixels chưa verified. Debug build thành công không thay thế native acceptance.

Ưu tiên tiếp theo: (1) Android replay T06-19 và isolate QA-01 theo counters; (2) full screenshot/Library suite; (3) P2 shared preference validation; (4) motion/FPS/audio benchmark; (5) overlay output và lifecycle/orientation cases còn thiếu. Chỉ thực hiện device phase khi có chỉ dẫn mới cho phép.
