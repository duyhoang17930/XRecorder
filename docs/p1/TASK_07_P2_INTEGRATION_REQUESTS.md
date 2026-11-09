# P2 Integration Requests — Task 07 (Notification Controls F14)

Ngày yêu cầu: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Trạng thái: **SUBMITTED / NON-BLOCKING**

---

### IR-07-01: Bộ drawable đơn sắc (Monochrome Vector Drawables) cho Android Notification

- **Phạm vi file:** `android/app/src/main/res/drawable/`
- **Vấn đề:** 
  Hiện tại ứng dụng sử dụng các drawable tiêu chuẩn hệ thống Android:
  - Video recording: `android.R.drawable.presence_video_online`
  - Screenshot: `android.R.drawable.ic_menu_camera`
  Để đảm bảo tính đồng bộ nhận diện thương hiệu và hiển thị tối ưu trên thanh trạng thái (status bar) của Android 12+ (yêu cầu biểu tượng flat monochrome / alpha-only), đề nghị P2 cung cấp các asset vector drawable tương ứng:
  1. `ic_notification_record.xml`: Biểu tượng quay video đơn sắc (ví dụ hình tròn ghi hình hoặc camera quay).
  2. `ic_notification_pause.xml`: Biểu tượng tạm dừng (hai vạch dọc).
  3. `ic_notification_stop.xml`: Biểu tượng dừng (hình vuông).
  4. `ic_notification_screenshot.xml`: Biểu tượng máy ảnh chụp nhanh.
- **Đề nghị thay đổi tối thiểu:**
  P2 bổ sung các file vector `.xml` trên vào `android/app/src/main/res/drawable/`. P1 sẽ tham chiếu các ID drawable này trong `CaptureService.kt` / `CaptureNotificationPolicy.kt`.
- **Tác động nếu chưa có:** Không chặn chức năng (Non-blocking); hệ thống tiếp tục hoạt động ổn định với drawable hệ thống `android.R.drawable.*`.
- **Acceptance:** Status bar hiển thị biểu tượng đơn sắc sắc nét trên Android 12, 13, 14.
