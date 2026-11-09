# Task 00–06 — P2 Fix Requests

Ngày: 2026-11-08. Chỉ bàn giao yêu cầu; không sửa source P2.

## IR-00-06-01 — Shared defaults/preferences còn có thể selected nhưng unsupported

- Owner/file: P2, `lib/features/settings/settings_controller.dart`; phối hợp consumer Home trong `lib/features/media/media_library_screen.dart` nếu cần đồng bộ trạng thái preview. P1 không sửa hai file này.
- Evidence cũ: [setup ban đầu](test_evidence/task_00_06/record_setup_initial.png), [unsupported selection](test_evidence/task_00_06/unsupported_after.png). Defaults shared là 1080p/60 FPS; capability phụ thuộc thiết bị. Mixed không tự động là unsupported: phải kiểm tra `audioSources`.
- Evidence local mới: [widget test](../../test/recording_setup_sheet_test.dart) chứng minh selection stale vẫn được giữ, Start bị chặn, rồi người dùng chọn resolution hỗ trợ thì FPS được đồng bộ và Start chỉ nhận tuple hợp lệ. Không có retest Android trong phase local.
- P1 đã xử lý: exact codec/resolution/FPS capability filtering; resolution không bị khóa chỉ vì FPS cũ sai; chọn resolution cập nhật FPS hỗ trợ trong chips hiện có; Start kiểm tra tuple/audio/Performance policy và dùng error flow hiện có, không silently clamp.
- Phần còn lại: trước khi vào form P1, shared defaults/restore vẫn có thể hiển thị requested settings không phù hợp thiết bị. Không tự sửa shared controller hoặc tự ghi đè preference của người dùng.
- Minimal required change: P2 xác định policy phân biệt default chưa được chọn và preference đã lưu; cung cấp trạng thái validation/capability dùng chung cho preview và capture. Giữ lựa chọn người dùng cho đến khi họ chọn lại; dùng luồng thông báo/state binding hiện có. Không tự hạ cấu hình đã lưu hoặc thêm UI mới trong task này.
- Acceptance: mock thiết bị chỉ có AVC/720p/30 và Mute; requested/effective/validation không bị đánh đồng; Start không chạy tuple unsupported; sau explicit selection, preview và request trùng nhau. Thiết bị có tuple cao hơn vẫn giữ lựa chọn được hỗ trợ. Không đổi layout/icon/style.

QA-02 chưa chứng minh lỗi refresh production nên không yêu cầu P2 sửa Media Library. QA-01 liên quan test/framework/platform semantics, chưa có căn cứ quy ownership cho P2.
