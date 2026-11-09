# P2 Integration Requests — Task 09 (Floating Ball F12)

Ngày yêu cầu: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Trạng thái: **SUBMITTED / NON-BLOCKING**

---

### IR-09-01: Tùy chọn cấu hình "Bật/Tắt nút nổi mặc định" trong Cài đặt

- **Phạm vi file:** `lib/features/settings/settings_controller.dart` và `lib/features/settings/recording_settings_form.dart` (do P2 sở hữu)
- **Vấn đề:** 
  Hiện tại Floating Ball được điều khiển qua cơ chế an toàn: mặc định dùng Notification controls; người dùng bật/tắt qua notification action "Show controls in video" / "Hide controls".
  Nếu sản phẩm muốn cho phép người dùng cấu hình bật nút nổi ngay từ khi bắt đầu phiên trong mục Cài đặt (Settings), cần P2 bổ sung toggle:
  `final bool showFloatingBall;` trong Settings và UI Form tương ứng.
- **Tác động nếu chưa có:** Không chặn chức năng (Non-blocking); người dùng vẫn bật/tắt được nút nổi trong lúc quay qua thanh thông báo (Notification Action "Show controls in video").
- **Acceptance:** Toggle xuất hiện trong Settings UI và lưu vào SharedPreferences.
