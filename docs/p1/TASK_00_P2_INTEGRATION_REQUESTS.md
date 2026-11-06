# Task 00 — P2 Integration Requests

Ngày: 2026-11-06; baseline `5cdda32`. Tài liệu để bàn giao, chưa gửi cho người khác. Không có thay đổi code P2/P3 trong Task 00.

## IR-00-01 — Xác nhận ownership và branch workflow

- **Ưu tiên:** High. **Trạng thái:** Required — Pending P2/P3.
- **File P2 cần quản lý:** `3HRecorder_FULL_XRecorder_3_PERSON_WORKPLAN.md` (chưa tìm thấy); `CODEOWNERS` hoặc `.github/CODEOWNERS` (chưa có). P2 chọn vị trí chính thức, P1 không tự tạo/sửa.
- **Vấn đề thực tế:** repo chỉ thấy main/origin/main; không thấy feature/capture-live trong refs hiện có; thiếu workplan/CODEOWNERS để xác nhận ranh giới tests/docs, Media Library, persistence/native resource và P2/P3 editor shared files. Ownership trong Task 00 chưa có cơ chế review tương ứng trong repo.
- **Thay đổi tối thiểu đề xuất:** xác nhận/bổ sung phân công và owners thật; ghi capture paths đúng như Task 00, cùng owner cho `lib/main.dart`, settings store, media_paths.xml, capture tests/fixtures/docs và ranh giới P2/P3. Xác nhận tạo branch P1 từ baseline nào sau khi checkpoint local đã sạch; không cần đổi app code.
- **API/signature:** không đổi runtime API.
- **Lý do:** tránh conflict tại app wiring, models/settings và registration khi P1 phát triển độc lập.
- **Acceptance Criteria:** có owner/reviewer cụ thể cho các phạm vi trên, P2/P3 xác nhận; P1 làm việc trên branch đã thống nhất với tree sạch. Các tên người/team CODEOWNERS phải được xác nhận, không dùng placeholder.

## IR-00-02 — Thống nhất cancel khác stop trong public contract

- **Ưu tiên:** High, blocker contract. **Trạng thái:** Required — Pending P2; implementation thuộc P1.
- **File cần P2 thống nhất/có thể cập nhật:** `lib/core/domain/repositories.dart` — tài liệu semantics của `RecordingService.cancel(String sessionId)` và `stop(String sessionId)`; không cần đổi signature. Không yêu cầu P2 sửa engine.
- **Vấn đề thực tế:** `CaptureBridge.onMethodCall` gom `stop`/`cancel` vào cùng nhánh; ngoài awaitingPermission đều gọi `CaptureService.stopCapture()`. Khi đã started, engine finalize/commit và phát completed; `CaptureController._receive` sẽ gọi onSaved. Vì vậy cancel active recording có thể vi phạm nguyên tắc Cancel không phát Saved dù UI screenshot hiện chỉ cancel countdown.
- **Thay đổi tối thiểu đề xuất:** P2 xác nhận `stop` là finalize/save, `cancel` là không publish/Saved. Thống nhất trường hợp đã finalizing/committed: từ chối quá muộn hay trả trạng thái đã hoàn tất, tránh ngầm hủy file đã publish. Sau thống nhất, P1 sửa riêng bridge/service và bổ sung regression coverage; P2 chỉ cần comment contract nếu cần, app wiring không cần đổi.
- **API/signature:** giữ `Future<void> stop(String sessionId)` và `Future<void> cancel(String sessionId)`; chưa đề xuất thêm shared state hoặc error code khi chưa thống nhất policy.
- **Lý do:** không âm thầm đổi hành vi Recording Engine trong Task 00; callers cần phân biệt kết thúc lưu và hủy bỏ, kể cả race với finalizer.
- **Acceptance Criteria:** cancel trước khi publish ở permission/countdown/recording/paused không onSaved, không output published, cleanup partial; stale ID không ảnh hưởng session khác; stop vẫn lưu MP4 hợp lệ; hành vi cancel quá muộn và screenshot finalizing được ghi rõ, kiểm thử; failure không Saved. Native test phải kiểm tra catalog/file, không chỉ callback fixture.

## Các điểm tích hợp đã đáp ứng — không yêu cầu sửa

| Hạng mục đã kiểm tra | File/bằng chứng | Kết luận |
| --- | --- | --- |
| Native bridge, events, results | `MainActivity.kt`: configureFlutterEngine/cleanUpFlutterEngine/onActivityResult/onRequestPermissionsResult | Already Satisfied qua code; không có request đăng ký lại |
| Permissions/service/provider | `AndroidManifest.xml`, `res/xml/media_paths.xml` | Already Satisfied qua code cho capture hiện tại; runtime matrix chưa verify trong phiên này |
| Flutter callback và routes | `lib/app/app.dart`: onSaved: media.refresh; app_router có settings route và completed redirect | Already Satisfied; không cần thêm route hoặc payload callback |
| Models/repositories và metadata | RecordingSession.outputUri/configSnapshot/elapsedActive; MediaCatalog.list đọc metadata file đã publish | Already Satisfied cho refresh/index; semantics cancel chờ IR-00-02 |
| Media Library index | MediaCatalog lọc pending/owner và có legacy private-files branch; media_repository.refresh debounce | Already Satisfied qua code; callback có thể replay khi tạo controller mới, refresh hiện tại chấp nhận lặp |
| Persistence | `lib/main.dart` inject/restore AndroidSettingsStore; SettingsController v2; native settings worker commit | Already Satisfied; không yêu cầu đổi store/schema |
| Dependencies | pubspec/lock, Android Gradle và native platform APIs hiện dùng | Không phát hiện thiếu dependency cho Task 00; không thêm SDK livestream |

Không tạo request đổi metadata model, router, manifest hoặc Media Library khi chưa có thiếu hụt thực tế. Runtime và các rủi ro P1 như journal replay/URI revalidation/dedupe được ghi trong [báo cáo contract](TASK_00_OWNERSHIP_AND_CONTRACT.md); không chuyển thành yêu cầu P2 sửa engine.
