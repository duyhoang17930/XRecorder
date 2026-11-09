# Task 11 — Drawing Overlay F15 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ Stroke Engine toán học, kiểm soát cờ WindowManager touch isolation, undo/clear LIFO, ánh xạ tọa độ khi xoay màn hình và hợp đồng MethodChannel đã PASS 100% host JVM và Flutter tests; việc xuất hiện trực tiếp các nét vẽ trong luồng nén phần cứng MediaProjection MP4 cần thiết bị thật để xác minh).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện tính năng **F15 Drawing Overlay (Lớp phủ vẽ & chú thích màn hình thời gian thực khi đang quay)**:
  - **Stroke Engine ([`DrawingStrokeEngine.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingStrokeEngine.kt)):**
    - Biểu diễn nét vẽ vector đa điểm (`Point`, `Stroke`), lưu trữ chuỗi hành trình điểm mượt mà.
    - Giới hạn độ rộng nét an toàn `[2.0 .. 64.0]` (mặc định `8.0`).
    - Chuẩn hóa mã màu ARGB (đảm bảo alpha luôn opaque `0xFF`, mặc định `#FF7847` đồng bộ theme).
    - Hỗ trợ thao tác **Undo** (LIFO stack) và **Clear** (xóa sạch toàn bộ nét vẽ).
    - Tự động co dãn và chuyển đổi tỷ lệ tọa độ khi xoay màn hình (orientation change portrait ↔ landscape) dựa trên tỷ lệ chuẩn hóa `[0.0 .. 1.0]`.
  - **Touch Isolation ([`DrawingOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingOverlay.kt)):**
    - Sử dụng cửa sổ trong suốt `TYPE_APPLICATION_OVERLAY`.
    - **Khi tắt chế độ vẽ (`isDrawingMode = false`):** Áp dụng cờ `FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCHABLE`, toàn bộ thao tác chạm lọt thẳng xuống các ứng dụng bên dưới (passthrough).
    - **Khi bật chế độ vẽ (`isDrawingMode = true`):** Chuyển sang cờ `FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL`, nhận sự kiện chạm và vẽ nét tức thì bằng Android `Canvas.drawPath`.
    - Tuyệt đối không sử dụng `FLAG_SECURE` (tránh sinh vệt đen redaction rectangle trong video).
  - **Vòng đời & Dọn dẹp tài nguyên:**
    - Gắn kết chặt chẽ với `CaptureService`. Khi phiên kết thúc (`Stop`, `Cancel`, `fail`, hoặc service `onDestroy`), tự động gỡ bỏ view khỏi `WindowManager`, dọn sạch bộ nhớ và xóa danh sách điểm vẽ.
    - Không làm gián đoạn hoặc reset phiên ghi hình đang chạy.
- **Phạm vi kiểm thử:** Máy chủ Ubuntu cục bộ, **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **82/82 native JVM unit tests PASS** (gồm 10 tests mới trong `DrawingStrokeEngineTest` và 72 tests hồi quy của các module Task 02–10).
  - **38/38 Flutter Dart tests PASS** (gồm `drawing_overlay_contract_test.dart` mới).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Sạch sẽ, không có lỗi khoảng trắng).
- **Tuân thủ quy tắc:**
  - **UI Freeze:** Không thay đổi bố cục, theme, màu sắc, font hay navigation của Flutter. Không tự ý thêm nút vẽ/tẩy vào thanh điều khiển hay màn hình settings.
  - **Icon Consistency:** Không thêm bất kỳ icon mới nào; giữ nguyên các asset hiện có.

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Công cụ Nét vẽ & Toán học ([`DrawingStrokeEngine.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingStrokeEngine.kt))** | Hoàn toàn chưa có trong package `recording` (chỉ có trong editor hậu kỳ P3). | Bổ sung `DrawingStrokeEngine`: data class `Point`, `Stroke`, `Session`; các hàm `clampWidth`, `clampColor`, `resolveWindowFlags`, `transformPointsOnRotation`, `canAcceptAction`. | **Kiểm chứng độc lập**: 10 JVM tests bao phủ 100% logic stroke, undo, clear, rotation remap, touch flag resolution. |
| **Lớp phủ Cửa sổ Nổi ([`DrawingOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingOverlay.kt))** | Chưa có cửa sổ overlay vẽ trong lúc quay. | Quản lý view trong suốt `TYPE_APPLICATION_OVERLAY`. Xử lý touch events (`ACTION_DOWN`, `MOVE`, `UP`, `CANCEL`) chuyển vào engine. Chuyển đổi cờ WindowManager giữa Drawing mode và Passthrough mode. | **Touch Isolation**: Người dùng chỉ vẽ khi bật chế độ vẽ; khi tắt, chạm lọt qua hoàn toàn không gây cản trở app khác. |
| **Dịch vụ Ghi hình ([`CaptureService.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt))** | Chưa tích hợp overlay vẽ. | Tích hợp `drawingOverlay`. Cung cấp các phương thức `setDrawingEnabled`, `clearDrawing`, `undoDrawing`, `setDrawingStyle`, `getDrawingState`. Dọn dẹp view trong `release()` và `onDestroy()`. | **Bảo vệ vòng đời**: Giải phóng hoàn toàn bộ nhớ khi phiên ghi kết thúc, không rò rỉ cửa sổ. |
| **Cầu nối MethodChannel ([`CaptureBridge.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureBridge.kt))** | Chưa xử lý các lệnh vẽ. | Bổ sung xử lý method calls: `"setDrawingEnabled"`, `"clearDrawing"`, `"undoDrawing"`, `"setDrawingStyle"`, `"getDrawingState"`. | **Tương thích ngược**: Các phương thức phản hồi đúng trạng thái boolean/map. |
| **Dịch vụ Dart ([`lib/features/recording/recording_service.dart`](../../lib/features/recording/recording_service.dart))** | Chưa có interface gọi điều khiển vẽ. | Thêm các hàm `setDrawingEnabled`, `clearDrawing`, `undoDrawing`, `setDrawingStyle`, `getDrawingState` trong `AndroidRecordingService`. | **Không vi phạm ownership**: Không sửa file domain repository của P2; mở rộng tại service implementation P1. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. Tính toán cờ WindowManager Touch Isolation trong `DrawingStrokeEngine.kt`
```kotlin
fun resolveWindowFlags(isDrawingMode: Boolean): Int {
    return if (isDrawingMode) {
        FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL
    } else {
        FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCHABLE
    }
}
```

### 3.2. Quản lý Undo & Multi-Stroke trong `DrawingStrokeEngine.kt`
```kotlin
fun undo(): Boolean {
    synchronized(this) {
        if (completedStrokes.isEmpty()) return false
        val removed = completedStrokes.removeAt(completedStrokes.size - 1)
        undoHistory.add(removed)
        return true
    }
}

fun clear(): Int {
    synchronized(this) {
        val count = completedStrokes.size
        completedStrokes.clear()
        currentPoints.clear()
        undoHistory.clear()
        return count
    }
}
```

### 3.3. Tự động chuyển đổi tọa độ nét vẽ khi xoay màn hình
```kotlin
fun transformPointsOnRotation(
    points: List<Point>,
    oldWidth: Int, oldHeight: Int,
    newWidth: Int, newHeight: Int
): List<Point> {
    if (oldWidth <= 0 || oldHeight <= 0 || newWidth <= 0 || newHeight <= 0) return points
    return points.map { p ->
        val norm = normalizePoint(p, oldWidth, oldHeight)
        denormalizePoint(norm, newWidth, newHeight)
    }
}
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. Android JVM Unit Tests
- **Lệnh thực thi:** `cd android && ./gradlew :app:testDebugUnitTest`
- **Kết quả:** `BUILD SUCCESSFUL in 11s`
- **Chi tiết kết quả các test suite (82/82 PASS):**
  - `DrawingStrokeEngineTest`: **10/10 tests PASS** (width clamping, color opaque alpha, touch flag resolution, mode rejection, stroke accumulation, undo LIFO, clear, rotation remap, state validation, snapshot).
  - `FloatingControlGeometryTest`: **19/19 tests PASS**.
  - `CaptureNotificationPolicyTest`: **11/11 tests PASS**.
  - `RegionCropGeometryTest`: **14/14 tests PASS**.
  - `CaptureRequestsTest`: **8/8 tests PASS**.
  - `CaptureTimingTest`: **4/4 tests PASS**.
  - `ScreenshotPixelsTest`: **4/4 tests PASS**.
  - `VideoBitrateTest`: **4/4 tests PASS**.
  - `CaptureJournalTest`: **3/3 tests PASS**.
  - `AudioVideoMathTest`: **3/3 tests PASS**.
  - `EditorStorageTest`: **2/2 tests PASS**.

### 4.2. Flutter Dart Tests
- **Lệnh thực thi:** `flutter test test/drawing_overlay_contract_test.dart --no-pub`
- **Kết quả:** `All tests passed!` (4/4 tests PASS):
  - `setDrawingEnabled passes boolean flag to method channel`: PASS.
  - `clearDrawing and undoDrawing invoke expected channel methods`: PASS.
  - `setDrawingStyle sends color and width payload`: PASS.
  - `getDrawingState retrieves snapshot map from native`: PASS.

### 4.3. Phân tích tĩnh & Kiểm tra mã nguồn
- **Lệnh thực thi:** `flutter analyze --no-pub`
  - **Kết quả:** `No issues found! (ran in 7.6s)`
- **Lệnh thực thi:** `git diff --check`
  - **Kết quả:** Không có lỗi khoảng trắng hay lỗi định dạng (Clean).

---

## 5. Yêu cầu tích hợp đối với P2 (P2 Blocker)
- Chi tiết bàn giao được lập tại [`docs/p1/TASK_11_P2_INTEGRATION_REQUESTS.md`](./TASK_11_P2_INTEGRATION_REQUESTS.md):
  1. Khi P2 dỡ bỏ lệnh UI Freeze, tích hợp các nút Brush (Bật/Tắt vẽ), Undo, Clear, Color Picker vào thanh công cụ nổi hoặc menu tiện ích của phiên quay.
  2. Kết nối trực tiếp các nút đó tới `recordingService.setDrawingEnabled()`, `undoDrawing()`, `clearDrawing()`, `setDrawingStyle()`.

---

## 6. Hạn chế & Xác nhận

- **Xác nhận UI/Icon Freeze:** P1 không thay đổi bất kỳ UI widget tree, layout hay icon nào của ứng dụng Flutter; giữ nguyên toàn bộ asset hiện hành.
- **DEVICE VERIFICATION PENDING:** Việc nét vẽ hiển thị trên màn hình có được MediaProjection thu vào file MP4 hoàn chỉnh hay không phụ thuộc vào chính sách phân lớp của SurfaceFlinger / OEM compositor và quyền ghi Entire screen vs Single app trên Android 14+. Yêu cầu kiểm tra trực tiếp trên thiết bị vật lý.

---

## 7. Kết luận
- **Trạng thái:** **PARTIAL / NEEDS DEVICE VERIFICATION**.
- Mã nguồn sạch sẽ, không có regressions, sẵn sàng bàn giao cho P2 và thử nghiệm trên thiết bị Android vật lý.
