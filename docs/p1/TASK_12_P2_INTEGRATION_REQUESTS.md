# Task 12 — P2 Integration Requests: Facecam Recording & Effects (F17/F18)

Ngày: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Đối tượng tiếp nhận: P2 (Platform, Media Library, Shared Integration / Architecture / UI)  

---

## 1. Bối cảnh & Mục đích
- Nhóm P1 đã củng cố toàn bộ hạ tầng logic Android native cho tính năng **F17 Facecam Recording** và **F18 Facecam Effects**:
  - Lớp tính toán toán học [`FacecamGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometry.kt):
    - Tính toán góc quay bù trừ hướng cảm biến camera và góc xoay màn hình thiết bị (`(sensorOrientation + displayRotation) % 360`).
    - Nghịch đảo tỷ lệ khung hình khi xoay 90/270 độ (`viewWidth / viewHeight`) và áp dụng lật gương (mirroring) cho camera trước.
    - Kẹp biên màn hình (clamping) và tự hít vào mép trái/phải (`snapToEdge`).
    - Hỗ trợ các effect Camera2 phần cứng: `EFFECT_OFF (0)`, `EFFECT_MONO (1)`, `EFFECT_NEGATIVE (2)`, `EFFECT_SOLARIZE (3)`, `EFFECT_SEPIA (4)`, `EFFECT_POSTERIZE (5)`, `EFFECT_WHITEBOARD (6)`, `EFFECT_BLACKBOARD (7)`, `EFFECT_AQUA (8)`.
  - Cửa sổ lớp phủ [`FacecamOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt):
    - Khắc phục triệt để hiện tượng nháy khung đen trước khi camera sẵn sàng (`alpha = 0f` ban đầu, mượt mà chuyển `alpha = 1f` khi khung hình đầu tiên từ camera đến).
    - Bo góc tròn hiện đại (`cornerRadius = 16dp`, `clipToOutline = true`).
    - Hỗ trợ kéo thả (drag) mượt mà bằng cử chỉ chạm, tự động hít mép khi nhả tay mà vẫn bảo đảm các chạm bên ngoài lọt qua app khác (`FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL`).
    - Hỗ trợ đổi camera trước ↔ sau (`switchCamera()`).
    - Hỗ trợ áp dụng hiệu ứng Camera2 trực tiếp (`setEffect()`).
    - Hỗ trợ thay đổi tỷ lệ kích thước (`setScale()`).
    - Quản lý vòng đời camera chặt chẽ: giải phóng camera, capture session và worker thread ngay khi phiên dừng/hủy/lỗi.
  - Cầu nối MethodChannel `com.xrecorder/capture`: Hỗ trợ `switchFacecamCamera`, `setFacecamEffect`, `setFacecamScale`, `getFacecamState`.
- Do tuân thủ quy tắc **STRICT UI FREEZE** và **OWNERSHIP**, P1 không tự ý thêm các nút/slider chọn hiệu ứng Facecam hay nút đổi camera vào giao diện Flutter của P2.

---

## 2. Các yêu cầu tích hợp đối với P2

### 2.1. Cung cấp UI chuyển đổi Camera & Hiệu ứng Facecam (Khi P2 dỡ bỏ UI Freeze)
- **Tệp liên quan:** `lib/features/recording/` hoặc menu công cụ nổi của P2.
- **Mục tiêu:** Cung cấp các nút điều khiển nhỏ gọn:
  1. **Nút đổi camera (Flip/Switch Camera):** Gọi `recordingService.switchFacecamCamera()` để luân chuyển giữa camera trước và camera sau.
  2. **Bộ chọn hiệu ứng (Effect Picker):** Cung cấp các preset: Bình thường (0), Đơn sắc/Mono (1), Âm bản/Negative (2), Nắng gắt/Solarize (3), Nâu đỏ/Sepia (4), v.v. Gọi `recordingService.setFacecamEffect(effectId)`.
  3. **Thu phóng cỡ Facecam (Scale Slider):** Gọi `recordingService.setFacecamScale(scale)` (dải `0.75x` đến `1.75x`).

---

## 3. Tiêu chí nghiệm thu (Acceptance Criteria)
1. Bật Facecam trong cài đặt quay hình không làm nháy khung đen lúc khởi tạo.
2. Người dùng có thể kéo thả cửa sổ Facecam quanh màn hình và thả tay để hít vào mép viền.
3. Chuyển đổi camera trước/sau qua `switchFacecamCamera()` hoạt động trơn tru không gây crash `CameraAccessException`.
4. Gọi `setFacecamEffect()` áp dụng hiệu ứng màu sắc ngay trên luồng camera thời gian thực.
5. Khi kết thúc phiên quay, tài nguyên CameraDevice và SurfaceTexture được giải phóng 100%.
