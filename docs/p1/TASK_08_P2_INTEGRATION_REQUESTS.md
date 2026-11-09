# P2 Integration Requests — Task 08 (Region Recording F03)

Ngày yêu cầu: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Trạng thái: **SUBMITTED / PENDING P2 REVIEW**

---

### IR-08-01: Bổ sung trường cấu hình vùng chọn vào `RecordingSettings`

- **Phạm vi file:** `lib/core/domain/models.dart` (do P2 sở hữu)
- **Vấn đề:** 
  Hiện tại `RecordingSettings` chỉ hỗ trợ các preset toàn màn hình (`width`, `height`), chưa có trường chứa tọa độ vùng cắt (`cropX`, `cropY`, `cropWidth`, `cropHeight` hoặc `Rect? region`).
- **Đề nghị thay đổi tối thiểu:**
  Bổ sung vào `RecordingSettings`:
  ```dart
  class RecordingSettings {
    const RecordingSettings({
      ...
      this.cropX,
      this.cropY,
      this.cropWidth,
      this.cropHeight,
    });
    final int? cropX, cropY, cropWidth, cropHeight;
    bool get isRegion => cropWidth != null && cropHeight != null && cropWidth! > 0 && cropHeight! > 0;
  }
  ```
- **Tác động nếu chưa có:** P1 đã hỗ trợ tham số tùy chọn `cropX, cropY, cropWidth, cropHeight` trực tiếp trong `AndroidRecordingService.start(settings, cropX: ..., ...)` và native engine, nhưng tầng UI và Domain model dùng chung chưa lưu trữ được trạng thái này.

---

### IR-08-02: Bổ sung UI chọn vùng màn hình (Region Selector Affordance / Sheet)

- **Phạm vi file:** `lib/features/recording/recording_setup_sheet.dart` hoặc `lib/core/widgets/studio_create_sheet.dart`
- **Vấn đề:** 
  Tuân thủ quy tắc **UI Freeze** của dự án, P1 không tự ý thiết kế thêm widget tree, dialog hoặc overlay chọn vùng. Cần P2 cung cấp affordance / selector UI cho tính năng "Quay khu vực" (Region Recording) theo đúng Design System của ứng dụng.
- **Đề nghị thay đổi tối thiểu:**
  1. Thêm tùy chọn "Vùng tùy chọn" (Custom Region) trong Sheet cài đặt quay.
  2. Truyền tọa độ hình chữ nhật đã chọn (`cropX, cropY, cropWidth, cropHeight`) vào callback bắt đầu quay của `AndroidRecordingService`.
- **Acceptance:** Người dùng có thể kéo thả/chọn vùng trên UI và ứng dụng kích hoạt phiên quay khu vực chuẩn xác.
