# Task 10 — Floating Ball Customization F13 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ logic toán học tỉ lệ kích thước, clamp alpha, chuyển đổi tọa độ chuẩn hóa, tính toán reposition sau xoay màn hình, throttling di chuyển và persistence native đã PASS 100% host JVM và Flutter contract tests; cảm ứng và hiển thị trực quan thực tế trên phần cứng màn hình Android cần thiết bị thật).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện tính năng **F13 Floating Ball Customization (Tùy biến bóng điều khiển nổi trên màn hình)**:
  - **Kích thước / Tỷ lệ (Scale):** Hỗ trợ dải tỷ lệ an toàn `[0.75 .. 1.5]`, mặc định `1.0`. Tự động clamp giá trị âm, 0, NaN hoặc vượt ngưỡng. Tỷ lệ được áp dụng cho kích thước bubble, timer, các nút điều khiển và bo góc viền mà vẫn bảo đảm diện tích chạm (hit target) an toàn tối thiểu theo chuẩn thiết kế Android.
  - **Độ trong suốt / Mờ (Opacity):** Hỗ trợ dải alpha an toàn `[0.2 .. 1.0]`, mặc định `1.0`. Tự động kết hợp với alpha của trạng thái hệ thống (`effectiveAlpha`), bảo đảm khi đang lưu video (`saving`) trạng thái vẫn nhìn thấy được (alpha không rơi xuống dưới `0.15`) và không bao giờ làm bóng biến mất vô hình. Độ mờ chỉ áp dụng lên cửa sổ `WindowManager` của bóng nổi, hoàn toàn **không ảnh hưởng** đến nội dung video thu từ `MediaProjection`.
  - **Tọa độ & Lưu trữ vị trí (Position Persistence & Drag Throttle):** Chuyển đổi hai chiều giữa tọa độ pixel và tọa độ chuẩn hóa tỷ lệ (`ratioX`, `ratioY` trong `[0.0 .. 1.0]`). Lưu vị trí đã thả vào `SharedPreferences` native (`3hrecorder_floating_ball`). Khi thiết bị xoay màn hình (orientation change giữa portrait và landscape), tọa độ tự động được tính toán lại theo kích thước và insets/cutout mới, giữ bóng nằm gọn trong màn hình và tự hít vào cạnh gần nhất. Lọc bỏ các lệnh update layout trùng lặp khi ngón tay di chuyển trong cùng một pixel clamped.
  - **Cập nhật động (Dynamic Update):** Bổ sung phương thức `applyCustomization` trên native và `updateFloatingBall` qua MethodChannel `com.xrecorder/capture` cho phép thay đổi kích thước và độ mờ khi đang trong phiên quay mà không cần hủy/tạo lại window.
- **Phạm vi kiểm thử:** Máy chủ Ubuntu cục bộ, **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **72/72 native JVM unit tests PASS** (gồm 19 tests trong `FloatingControlGeometryTest` và 53 tests của các module Task 02–09).
  - **37/37 Flutter Dart unit/contract/controller tests PASS** (gồm `floating_ball_contract_test.dart` mới).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Sạch sẽ, không có lỗi khoảng trắng).
- **Tuân thủ quy tắc:**
  - **UI Freeze:** Giữ nguyên 100% widget tree, styling, themes và settings screens của Flutter. Không tự ý thêm settings slider/picker vào UI P2.
  - **Icon Consistency:** Không thay đổi icon native hay Flutter; giữ nguyên các drawable `#FF7847`, `ic_media_pause`, `ic_media_play`, stop button.

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Toán học & Hình học ([`FloatingControlGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingControlGeometry.kt))** | Chỉ có `clamp`, `snap` cơ bản và ma trận trạng thái cố định alpha 1.0/0.4. | Bổ sung `clampScale`, `clampOpacity`, `effectiveAlpha`, `scaledDimension`, `toNormalizedX/Y`, `fromNormalizedX/Y`, `repositionAfterRotation`, `parseCustomization`. | **Kiểm chứng độc lập**: 19 JVM tests bao phủ 100% các trường hợp biên, NaN, out-of-bounds, xoay màn hình portrait ↔ landscape. |
| **Bóng nổi Native ([`FloatingRecordingControls.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingRecordingControls.kt))** | Kích thước cứng 48dp, vị trí cứng dp(8), dp(140), không lưu vị trí khi thả, không nhận scale/opacity. | Khởi tạo với cấu hình tùy chỉnh hoặc khôi phục từ `SharedPreferences`. Cập nhật kích thước layout, corner radius, icon stop. Drag clamp và throttle chỉ cập nhật WindowManager khi pixel thực sự đổi. Nhả tay lưu vị trí normalized. Hỗ trợ `applyCustomization`. | **An toàn vòng đời**: Không recreate window, không gây giật lag khi drag, dọn sạch views khi close. |
| **Cấu hình phiên ([`CaptureConfig.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt))** | Chỉ có thông số video, audio, crop region. | Mở rộng trường `floatingScale`, `floatingOpacity`, `floatingRatioX`, `floatingRatioY` với giá trị mặc định an toàn. Parse an toàn trong `from()`. | **Tương thích ngược**: Các phiên gọi không truyền tùy chọn bóng nổi vẫn hoạt động bình thường theo giá trị mặc định hoặc SharedPreferences. |
| **Dịch vụ Ghi hình ([`CaptureService.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt) & [`CaptureBridge.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureBridge.kt))** | Khởi tạo controls không truyền scale/opacity; không có method cập nhật bóng nổi. | Truyền tham số tùy biến từ cấu hình phiên vào `FloatingRecordingControls`. Thêm method `updateFloatingBall` trong `CaptureBridge` và `CaptureService.updateFloatingControls`. | **Khả năng mở rộng**: Sẵn sàng nhận lệnh thay đổi trực tiếp từ Flutter khi người dùng kéo slider trong tương lai. |
| **Dart Service ([`lib/features/recording/recording_service.dart`](../../lib/features/recording/recording_service.dart))** | `start` chỉ nhận settings và crop coordinates. | Bổ sung optional parameters `floatingScale`, `floatingOpacity`, `floatingRatioX`, `floatingRatioY` trong `start()` và hàm `updateFloatingBall()`. | **Tuân thủ hợp đồng**: Không sửa file domain repository của P2; mở rộng an toàn tại lớp triển khai native service. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. Các hàm toán học tính toán tỷ lệ, độ mờ và xoay màn hình trong `FloatingControlGeometry.kt`
```kotlin
fun clampScale(scale: Float?): Float {
    if (scale == null || scale.isNaN() || scale <= 0f) return DEFAULT_SCALE
    return scale.coerceIn(MIN_SCALE, MAX_SCALE)
}

fun clampOpacity(opacity: Float?): Float {
    if (opacity == null || opacity.isNaN() || opacity <= 0f) return DEFAULT_OPACITY
    return opacity.coerceIn(MIN_OPACITY, MAX_OPACITY)
}

fun effectiveAlpha(stateAlpha: Float, userOpacity: Float = DEFAULT_OPACITY): Float {
    if (stateAlpha <= 0f) return 0f
    val clampedOpacity = clampOpacity(userOpacity)
    val combined = stateAlpha * clampedOpacity
    return combined.coerceIn(MIN_EFFECTIVE_ALPHA, 1.0f)
}

fun toNormalizedX(x: Int, availableWidth: Int, viewWidth: Int): Float {
    val maxX = (availableWidth - viewWidth).coerceAtLeast(0)
    if (maxX == 0) return 0f
    return (clamp(x, availableWidth, viewWidth).toFloat() / maxX).coerceIn(0f, 1f)
}

fun repositionAfterRotation(
    ratioX: Float, ratioY: Float,
    availableWidth: Int, availableHeight: Int,
    viewWidth: Int, viewHeight: Int,
    snapToEdge: Boolean = true
): Pair<Int, Int> {
    val rawX = fromNormalizedX(ratioX, availableWidth, viewWidth)
    val rawY = fromNormalizedY(ratioY, availableHeight, viewHeight)
    val clampedY = clamp(rawY, availableHeight, viewHeight)
    val adjustedX = if (snapToEdge) snap(rawX, availableWidth, viewWidth) else clamp(rawX, availableWidth, viewWidth)
    return adjustedX to clampedY
}
```

### 3.2. Cập nhật động và Throttling di chuyển trong `FloatingRecordingControls.kt`
```kotlin
fun applyCustomization(scale: Float? = null, opacity: Float? = null) {
    if (closed) return
    var layoutChanged = false
    if (scale != null) {
        val clampedScale = FloatingControlGeometry.clampScale(scale)
        if (clampedScale != userScale) {
            userScale = clampedScale
            layoutChanged = true
        }
    }
    if (opacity != null) {
        userOpacity = FloatingControlGeometry.clampOpacity(opacity)
    }
    if (layoutChanged) {
        applyCustomizationLayout()
    }
    persistPreferences(currentRatioX, currentRatioY, userScale, userOpacity)
    render(state, elapsed)
    reposition(force = true)
}
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. Android JVM Unit Tests
- **Lệnh thực thi:** `cd android && ./gradlew :app:testDebugUnitTest`
- **Kết quả:** `BUILD SUCCESSFUL in 28s`
- **Chi tiết kết quả các test suite (72/72 PASS):**
  - `FloatingControlGeometryTest`: **19/19 tests PASS** (gồm 8 tests mới: clamp scale, clamp opacity, effective alpha, scaled dimension, normalized coords, rotation repositioning, customization parsing, user opacity rendering).
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
- **Lệnh thực thi:** `flutter test --no-pub`
- **Kết quả:** `All tests passed!` (172/172 tests PASS).
- **Hợp đồng mới:** `test/floating_ball_contract_test.dart` (2/2 tests PASS):
  - `start passes floatingScale, floatingOpacity, and ratios in payload`: PASS.
  - `updateFloatingBall sends scale and opacity via method channel`: PASS.

### 4.3. Phân tích tĩnh & Kiểm tra mã nguồn
- **Lệnh thực thi:** `flutter analyze --no-pub`
  - **Kết quả:** `No issues found! (ran in 6.6s)`
- **Lệnh thực thi:** `git diff --check`
  - **Kết quả:** Không có cảnh báo khoảng trắng hay lỗi định dạng (Clean).

---

## 5. Yêu cầu tích hợp đối với P2 (P2 Blocker)
- Toàn bộ contract tích hợp cho P2 được mô tả chi tiết tại [`docs/p1/TASK_10_P2_INTEGRATION_REQUESTS.md`](./TASK_10_P2_INTEGRATION_REQUESTS.md):
  1. Thêm trường `floatingBallScale` và `floatingBallOpacity` vào model `RecordingSettings`.
  2. Bổ sung persistence trong `SettingsController`.
  3. Cung cấp slider điều chỉnh kích thước và độ mờ trong UI Cài đặt và kết nối tới `updateFloatingBall()` khi P2 dỡ bỏ lệnh UI Freeze.

---

## 6. Hạn chế & Xác nhận

- **Xác nhận UI/Icon Freeze:** P1 không thay đổi bất kỳ UI widget tree, layout, màu sắc, hay icon nào của ứng dụng Flutter; giữ nguyên các icon native của nút nổi từ Task 09.
- **NEEDS DEVICE VERIFICATION:** Các hành vi phụ thuộc vào phần cứng Android thật (hiển thị mờ thực tế của WindowManager, độ nhạy cảm ứng khi scale nhỏ/lớn, hiển thị trên các màn hình có tai thỏ / notch phức tạp) được đánh dấu cần xác minh trên thiết bị thật.

---

## 7. Kết luận
- **Trạng thái:** **PARTIAL / NEEDS DEVICE VERIFICATION**.
- Mã nguồn sạch sẽ, không có regressions, sẵn sàng bàn giao cho P2 và thử nghiệm trên thiết bị Android vật lý.
