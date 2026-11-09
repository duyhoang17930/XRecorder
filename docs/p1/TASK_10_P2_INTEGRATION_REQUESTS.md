# Task 10 — P2 Integration Requests: Floating Ball Customization (F13)

Ngày: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Đối tượng tiếp nhận: P2 (Platform, Media Library, Shared Integration / Architecture / UI)  

---

## 1. Bối cảnh & Mục đích
- Nhóm P1 đã hoàn thiện hạ tầng logic Android native cho **F13 Floating Ball Customization**:
  - Tùy chỉnh tỷ lệ kích thước (`scale` trong phạm vi an toàn `0.75` đến `1.5`, mặc định `1.0`).
  - Tùy chỉnh độ trong suốt / mờ (`opacity` trong phạm vi an toàn `0.2` đến `1.0`, mặc định `1.0`).
  - Lưu và phục hồi tọa độ chuẩn hóa (`ratioX`, `ratioY` trong `[0.0 .. 1.0]`) qua `SharedPreferences` native (`3hrecorder_floating_ball`).
  - Tự động thích ứng khi xoay màn hình (orientation change giữa portrait và landscape) mà không để nút bay ra ngoài màn hình hay bị khuất dưới thanh trạng thái/tai thỏ.
  - Hỗ trợ gọi cập nhật động (`updateFloatingBall(scale, opacity)`) qua method channel `com.xrecorder/capture` mà không cần recreate cửa sổ.
- Theo quy định **STRICT UI FREEZE** và **OWNERSHIP**, P1 không được tự ý sửa đổi `lib/core/domain/models.dart`, `lib/features/settings/settings_controller.dart` hoặc bổ sung UI controls trong màn hình cài đặt của P2.

---

## 2. Các yêu cầu tích hợp đối với P2

### 2.1. Bổ sung trường cấu hình Floating Ball vào `RecordingSettings`
- **Tệp:** `lib/core/domain/models.dart`
- **Mục tiêu:** Mở rộng model `RecordingSettings` để lưu trữ tùy chọn kích thước và độ mờ của bóng nổi:
```dart
class RecordingSettings {
  final double floatingBallScale;    // Mặc định: 1.0, phạm vi [0.75 .. 1.5]
  final double floatingBallOpacity;  // Mặc định: 1.0, phạm vi [0.2 .. 1.0]

  const RecordingSettings({
    // ... các trường hiện có
    this.floatingBallScale = 1.0,
    this.floatingBallOpacity = 1.0,
  });
}
```

### 2.2. Persistence trong `SettingsController`
- **Tệp:** `lib/features/settings/settings_controller.dart`
- **Mục tiêu:** Serialize/deserialize `floatingBallScale` và `floatingBallOpacity` vào JSON storage của SharedPreferences phía Flutter để giữ trạng thái cài đặt đồng bộ giữa các lần mở ứng dụng.

### 2.3. Cung cấp UI điều chỉnh trong Cài đặt (Khi P2 bỏ UI Freeze)
- **Tệp:** `lib/features/settings/recording_settings_form.dart`
- **Mục tiêu:** Hiển thị slider / segmented picker cho:
  - Kích thước bóng nổi: 0.8x, 1.0x, 1.25x (hoặc slider 75% – 150%).
  - Độ mờ bóng nổi: Slider 20% – 100%.
  - Khi người dùng thay đổi giá trị trong lúc đang ghi hình, gọi:
    ```dart
    await recordingService.updateFloatingBall(
      scale: newScale,
      opacity: newOpacity,
    );
    ```

---

## 3. Tiêu chí nghiệm thu (Acceptance Criteria)
1. Cấu hình `floatingBallScale` và `floatingBallOpacity` truyền qua `start()` được native nhận và áp dụng kích thước/độ mờ chính xác.
2. Gọi `updateFloatingBall(scale, opacity)` làm thay đổi trực quan bóng nổi ngay lập tức mà không gây crash hoặc chớp giật layout.
3. Không làm ảnh hưởng đến video ghi hình (overlay view alpha không làm đổi VirtualDisplay video).
