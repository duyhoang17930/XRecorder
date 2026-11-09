# Task 00 — P2 Integration Requests

Ngày: 2026-11-07. Baseline `4ce6a53`, branch `feature/capture-live`, working tree ban đầu sạch. Chỉ ghi bàn giao, chưa gửi cho người khác. Không sửa file P2/P3.

## IR-00-01 — Xác nhận ranh giới ownership shared/P3

- **Trạng thái:** Pending xác nhận owner; không chặn logic P1 của Task 00.
- **File liên quan:** workplan chính thức hoặc CODEOWNERS do P2 quản lý; repo chưa có các file này. P1 không tự tạo/sửa AGENTS.md/CODEOWNERS.
- **Bằng chứng:** capture phụ thuộc `lib/app/`, domain model/repositories, SettingsController, MainActivity/Manifest/provider. Task 00 đã nêu vùng P1/P2 nhưng chưa phân công chi tiết ranh giới editor/export/photo tools giữa P2/P3 và owner shared persistence/native resources.
- **Thay đổi tối thiểu:** xác nhận owner/reviewer cho shared files, P2/P3 editor và capture tests/docs trong kênh phân công hiện có; không bắt buộc tạo hệ thống ownership mới hoặc refactor code.
- **Contract:** không đổi runtime API. Branch P1 đã đúng, bỏ yêu cầu cũ tạo/chuyển branch hoặc checkpoint commit.
- **Nghiệm thu:** có phân công được owner xác nhận cho các vùng dùng chung; P1 không sửa ngoài capture paths. Không dùng tên team/người giả trong CODEOWNERS.

## IR-00-02 — Đồng bộ mô tả stop/cancel trong API shared

- **Trạng thái:** Pending P2 cập nhật comment; lỗi engine đã sửa trong P1 theo yêu cầu trực tiếp Task 00. Không còn chờ P2 duyệt semantics Cancel không Saved.
- **File:** `lib/core/domain/repositories.dart`, interface RecordingService.
- **Bằng chứng:** `stop(String sessionId)` và `cancel(String sessionId)` chưa có comment phân biệt. Native trước đây gọi stopCapture cho cả hai, có thể publish khi hủy recording/paused. P1 đã tách bridge/service; không sửa interface shared.
- **Thay đổi tối thiểu:** bổ sung comment contract, giữ signature và enum hiện tại; không cần đổi app wiring, Media Library hay UI.
- **Contract:** stop finalize/save; cancel trước finalizer abort/idle, không Saved. Stale ID từ chối. Khi stopping/finalizing đã được chấp nhận, cancel trả lỗi native `too_late` (Dart hiện thành DomainFailure.io); không đua commit. Cancel sau completed/failed/idle là no-op, không xóa file đã publish. Một cancel bị từ chối quá muộn không phải hủy thành công; finalizer vẫn có thể phát Saved cho lệnh stop/shot trước đó.
- **Nghiệm thu:** shared comment khớp semantics trên; không đổi public signature. P1 chạy regression native để xác nhận cancel không thêm file/catalog, cleanup partial, stale/duplicate, stop vẫn lưu MP4/PNG và lỗi không Saved. Test catalog đơn thuần chưa chứng minh pending/cache đã được dọn, cần kiểm tra storage runtime.

## Đã đủ — không yêu cầu sửa

| Hạng mục | Bằng chứng / kết luận |
| --- | --- |
| Bridge/events/results | MainActivity đăng ký và tháo handlers; không yêu cầu sửa registration |
| Permissions/service/provider | Manifest và media_paths.xml có cấu hình capture hiện tại; runtime chưa kiểm chứng lại |
| Capture → Media | app.dart có onSaved: media.refresh, catalog lọc pending/owner, legacy private files |
| Models/metadata | RecordingSession.outputUri/configSnapshot/elapsedActive đủ cho refresh/index |
| Dependencies | Không thiếu dependency cho Task 00; không thêm SDK hoặc đổi Gradle/pubspec |

Giới hạn native/runtime, dedupe và journal replay nằm trong [báo cáo contract](TASK_00_OWNERSHIP_AND_CONTRACT.md); không chuyển lỗi capture sang Media Library/P2 xử lý.
