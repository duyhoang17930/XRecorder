# Task 00 — P1 Ownership & Capture → Media Contract

Ngày kiểm tra: 2026-11-07. Baseline: `4ce6a53`.
Trạng thái: **PARTIAL** — audit và sửa logic P1 hoàn tất; chưa kiểm chứng native trên thiết bị.

## Git và ownership

- Branch `feature/capture-live`; `git status --short` ban đầu rỗng. Không checkout/reset, stage, commit hoặc push.
- Không tìm thấy AGENTS.md, CODEOWNERS hoặc workplan phân công trong repo; không thấy AGENTS.md ở các thư mục cha. Ranh giới dưới đây theo Task 00 của người dùng; không tự sửa shared ownership files.
- Tài liệu cũ ghi branch main, baseline 5cdda32 và cho phép commit thuộc phiên trước; không áp dụng cho phiên này.

| Phạm vi | Owner / quy tắc |
| --- | --- |
| `lib/features/recording/` | P1: controller/service, callback, state binding; giữ nguyên render/style |
| `lib/features/settings/recording_settings_form.dart`, `audio_video_settings_screen.dart` | P1; chỉ sửa logic khi cần, lần này không đổi |
| Native `recording/` | P1: bridge, service, encoder/audio/muxer, state/journal, MediaOutput, facecam |
| Capture tests và `docs/p1/` | P1 theo phạm vi unit tests/tài liệu kỹ thuật của Task 00 |
| `lib/app/`, `lib/core/domain/`, `lib/core/widgets/`, SettingsController | Shared/P2; P1 chỉ đọc |
| MainActivity, Manifest, pubspec/lock, Gradle | P2; P1 chỉ đọc, không đổi registration/dependencies |
| Media Library và native media catalog | P2 theo ranh giới Capture → Media; P1 chỉ đọc |
| Editor, export, photo tools | Ngoài P1; ranh giới P2/P3 cần owner xác nhận, lần này không sửa |

Rủi ro conflict: controller dùng model/API shared; settings UI dùng SettingsController; native phụ thuộc registration/permissions/provider. Không di chuyển file hoặc refactor để chuẩn hóa ownership.

## Capture → Media API đã kiểm tra

```text
CaptureService → encoder / PNG compress → MediaOutput.commit()
  → CaptureState(outputUri, completed) → EventChannel hoặc current snapshot
  → AndroidRecordingService.decode → CaptureController._receive
  → onSaved() → media.refresh() → catalog đọc media đã publish
```

- Contract giữ nguyên MethodChannel `com.xrecorder/capture`, EventChannel `com.xrecorder/capture/events`, các signature RecordingService và callback `VoidCallback onSaved`.
- `lib/app/app.dart` vẫn có `CaptureController(... onSaved: media.refresh)`. Không cần thêm payload, route hoặc sửa Media Library.
- Video: MediaCodec/MediaMuxer thật; finalizer kiểm tra duration > 0 và HAS_AUDIO nếu có audio trước commit.
- Screenshot: ImageReader → bitmap crop → compress PNG thành công → flush/close → commit. Không có fake URI/mock success trong đường production đã đọc.
- MediaOutput API 29+: output pending, size > 0, đóng descriptor, update IS_PENDING=0 phải trả 1. API 24–28: đổi tên file private rồi lấy FileProvider URI. Sau commit mới output/completed.
- Failure: abort dữ liệu tạm và failed; controller chỉ gọi Saved khi completed + outputUri khác null. Permission denied/cancel trước capture trả idle, không Saved.
- Catalog lọc owner_package_name và is_pending=0; legacy đọc thư mục private. `media.refresh` debounce 250 ms, hoãn khi background. Model hiện tại đủ cho refresh/index.
- MainActivity đã đăng ký bridge/events, chuyển activity/permission result và tháo handlers khi cleanup. Manifest đã có service/permissions/provider; không cần thay dependency cho Task 00.

## Lỗi đã sửa trong P1

**Cancel đang bị xử lý như stop:** CaptureBridge trước đây gom cả hai vào stopCapture, khiến cancel ở recording/paused vẫn finalize/commit rồi Saved.

- Bridge giữ session ID guard; cancel lúc awaitingPermission bỏ pending request và về idle.
- Cancel ở countdown/starting/recording/paused gọi `cancelCapture`: chặn callback tiếp, release resources, abort output/cache, xóa output trong state rồi về idle. Không gọi commit/completed.
- Stop giữ nguyên đường finalize/save.
- Finalizer bắt đầu khi `ending=true` trên main looper, trước khi worker chạy. Cancel lúc này trả PlatformException `too_late` (Dart ánh xạ thành DomainFailure.io như các lỗi native hiện có); không báo hủy thành công. Worker đã được chấp nhận trước đó vẫn có thể hoàn thành Saved.
- Cancel khi idle/completed/failed là no-op; không xóa file đã publish. Session ID cũ vẫn bị từ chối. Không có thay đổi public signature hoặc shared state enum.
- `cleanupPartial` hiện có thử abort và ghi lỗi cleanup nội bộ; chưa fault-injection để khẳng định xóa partial thành công trên mọi lỗi I/O.

Đề bài phiên này đã xác định Cancel không Saved và cho phép sửa lỗi P1; không chờ P2 duyệt lại semantics đó. P2 chỉ cần đồng bộ tài liệu shared API nếu cần, xem IR-00-02.

## Phần đã đủ và giới hạn

- `_savedId` chặn completion lặp liên tiếp cùng ID trong một controller; native `ending` chặn finalizer lặp. Không đổi sang cơ chế exactly-once toàn tiến trình: controller mới có thể refresh lại completed snapshot, A/B/A không được bảo vệ bởi một ID. Refresh catalog hiện tại chịu được lặp.
- Khi Activity mở lại, singleton/service và current/onListen cấp snapshot; completed ban đầu refresh catalog, không hiện lại feedback mới. Test host kiểm tra replay cùng ID.
- Journal khôi phục process loss lúc busy thành failed và dọn partial; không giả tiếp tục MediaProjection consent. Activity recreation thật, pending consent qua recreation và process kill chưa được thử trong phiên này.
- Non-null URI không chứng minh file còn đọc được sau replay; file đã xóa có thể gây refresh lại catalog. Không cần đổi API vì catalog tự truy vấn dữ liệu thực.
- Không mở rộng livestream, floating controls, drawing hay metadata schema trong Task 00.

## Kiểm thử và bảo vệ UI

- **PASS:** `flutter test --no-pub test/recording_controller_test.dart` — 6 tests; bổ sung failure/cancel có URI vẫn không Saved và completed snapshot replay chỉ refresh một lần, không feedback mới. Fixture URI chỉ nằm trong host tests.
- **PASS:** `flutter analyze --no-pub` — No issues found.
- **PASS:** `./gradlew --offline :app:compileDebugKotlin` — BUILD SUCCESSFUL; có warnings deprecation/non-null assertion ở code sẵn có ngoài P1, không sửa. Chỉ compile debug, không build release.
- **NOT RUN:** `integration_test/recording_cancel_test.dart`, recording_controls/screenshot native suites; `adb devices` không có thiết bị. Test mới kiểm tra cancel countdown/recording/paused/awaitingPermission, stale ID, duplicate cancel, không completed/Saved và catalog không tăng. Cần host cấp projection cho ba lượt đầu; lượt cuối giữ consent pending. Catalog không tăng chưa chứng minh mọi pending row/cache đã xóa: cần kiểm tra native storage khi chạy thiết bị.
- **NOT RUN:** MediaStore/encoder fault injection, Activity recreation/process death, full suite và release build.
- Không sửa bất kỳ file Dart production/UI nào; không đổi widget tree, render/style, theme, icon, animation hoặc navigation. Chỉ hai file Kotlin production thuộc recording, capture tests và hai tài liệu P1 được thay đổi.
- **PASS:** kiểm tra diff từng file và `git diff --check`; kiểm tra whitespace riêng cho integration test mới (untracked). Không sửa file P2/P3.

## Còn lại

- Chạy regression native, stop-save MP4/PNG và fault/lifecycle checks trên Android trước khi tuyên bố contract đã được kiểm chứng runtime.
- P2 xác nhận phần ownership shared/P3 chưa có workplan; đồng bộ comment stop/cancel trong repositories.dart (không đổi signature), theo [integration requests](TASK_00_P2_INTEGRATION_REQUESTS.md).
- Không có blocker quyền sửa logic P1. Hạn chế kiểm chứng hiện tại là thiếu thiết bị Android, không phải chờ phê duyệt thay đổi UI/API.
