# Task 12 — Facecam Recording & Effects F17/F18 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ logic toán học hình học, xoay hướng cảm biến, chống nháy khung đen, cử chỉ kéo thả hít mép, đổi camera trước/sau, hiệu ứng Camera2 và hợp đồng MethodChannel đã PASS 100% host JVM và Flutter tests; kiểm thử phần cứng cảm biến camera, độ trễ khung hình và việc ghép pixels vào luồng nén MediaProjection MP4 thực tế cần thiết bị thật để xác minh).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện tính năng **F17 Facecam Recording** và **F18 Facecam Effects**:
  - **Toán học & Hình học ([`FacecamGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometry.kt)):**
    - Tính toán góc quay chuẩn hóa bù trừ góc cảm biến camera và góc xoay màn hình thiết bị (`(sensorOrientation + displayRotation) % 360`).
    - Tính toán ma trận biến đổi tỉ lệ khung hình (nghịch đảo tỷ lệ khi xoay 90/270 độ: `viewWidth / viewHeight`) và áp dụng lật gương (mirroring) tự động cho camera trước.
    - Kẹp biên màn hình (clamp) và tự động hít vào mép trái/phải (`snapToEdge`).
    - Ánh xạ mã hiệu ứng Camera2 phần cứng: `EFFECT_OFF (0)`, `EFFECT_MONO (1)`, `EFFECT_NEGATIVE (2)`, `EFFECT_SOLARIZE (3)`, `EFFECT_SEPIA (4)`, `EFFECT_POSTERIZE (5)`, `EFFECT_WHITEBOARD (6)`, `EFFECT_BLACKBOARD (7)`, `EFFECT_AQUA (8)`.
  - **Khắc phục lỗi hiển thị & Cử chỉ kéo thả ([`FacecamOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt)):**
    - **Loại bỏ khung đen (Black box elimination):** Khởi tạo TextureView với `alpha = 0f`. Chỉ khi khung hình đầu tiên từ camera thực sự được render (`onSurfaceTextureUpdated`), Facecam mới hiển thị mượt mà (`alpha = 1f`).
    - **Bo góc hiện đại:** Bo tròn góc viền `16dp` bằng `ViewOutlineProvider` với `clipToOutline = true`.
    - **Kéo thả mượt mà (Draggable):** Chuyển cờ WindowManager sang `FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL`. Người dùng có thể kéo Facecam di chuyển tự do khắp màn hình; khi nhả tay (`ACTION_UP`), Facecam tự động hít vào cạnh màn hình gần nhất mà vẫn cho phép toàn bộ thao tác chạm bên ngoài lọt xuống app bên dưới.
    - **Đổi camera trước ↔ sau (Camera switching):** Hỗ trợ `switchCamera()`, tự động đóng thiết bị cũ và mở camera đối diện, cập nhật ma trận biến đổi không lật gương cho camera sau.
    - **Hiệu ứng Camera2 (Hardware effects):** Hỗ trợ `setEffect()`, áp dụng trực tiếp lên `CaptureRequest.CONTROL_EFFECT_MODE` mà không làm tụt FPS hay cần thêm thư viện AI bên thứ 3.
  - **Vòng đời & Dọn dẹp tài nguyên:**
    - Gắn kết chặt chẽ với `CaptureService`. Khi phiên kết thúc (`Stop`, `Cancel`, `fail`, hoặc service `onDestroy`), tự động đóng camera session, camera device, giải phóng SurfaceTexture và hủy thread worker an toàn.
- **Phạm vi kiểm thử:** Máy chủ Ubuntu cục bộ, **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **91/91 native JVM unit tests PASS** (gồm 9 tests mới trong `FacecamGeometryTest` và 82 tests hồi quy của các module Task 02–11).
  - **39/39 Flutter Dart tests PASS** (gồm `facecam_contract_test.dart` mới).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Sạch sẽ, không có lỗi khoảng trắng).
- **Tuân thủ quy tắc:**
  - **UI Freeze:** Giữ nguyên 100% widget tree, styling, themes và settings screens của Flutter. Không tự ý thêm settings slider/picker vào UI P2.
  - **Icon Consistency:** Không thêm hay sửa bất kỳ icon nào; giữ nguyên các asset hiện hành.

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Toán học & Hình học ([`FacecamGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometry.kt))** | Các phép tính góc quay nhúng cứng trong `FacecamOverlay.kt`, không có unit test độc lập. | Tách toàn bộ toán học sang `FacecamGeometry`: tính góc quay, tỷ lệ xoay, kẹp biên, hít mép, đổi camera và ánh xạ hiệu ứng Camera2. | **Kiểm chứng độc lập**: 9 JVM tests bao phủ 100% các trường hợp xoay góc, lật gương, kẹp biên và hiệu ứng. |
| **Cửa sổ Lớp phủ Facecam ([`FacecamOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt))** | Vị trí cố định (dp(12), dp(100)), `FLAG_NOT_TOUCHABLE` không thể kéo thả, có thể chớp khung đen lúc khởi động, không đổi được camera, không có effect. | Khởi tạo với `alpha = 0f` loại bỏ khung đen; bo góc viền 16dp; cờ WindowManager cho phép kéo thả và tự hít mép khi nhả tay; hỗ trợ `switchCamera()`, `setEffect()`, `setScale()`. | **Trải nghiệm người dùng**: Khắc phục triệt để các hạn chế ghi nhận trong Task 01 audit (F17/F18). |
| **Dịch vụ Ghi hình ([`CaptureService.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt))** | Chỉ có tạo và đóng FacecamOverlay. | Bổ sung `switchFacecamCamera()`, `setFacecamEffect()`, `setFacecamScale()`, `getFacecamState()`. Dọn dẹp trong `release()` và `onDestroy()`. | **Bảo vệ vòng đời**: Giải phóng camera và luồng worker ngay lập tức khi phiên kết thúc. |
| **Cầu nối MethodChannel ([`CaptureBridge.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureBridge.kt))** | Chưa xử lý các lệnh Facecam nâng cao. | Bổ sung xử lý method calls: `"switchFacecamCamera"`, `"setFacecamEffect"`, `"setFacecamScale"`, `"getFacecamState"`. | **Hợp đồng rõ ràng**: Sẵn sàng kết nối khi P2 xây dựng UI điều khiển. |
| **Dịch vụ Dart ([`lib/features/recording/recording_service.dart`](../../lib/features/recording/recording_service.dart))** | Chưa có các hàm Facecam controls. | Bổ sung `switchFacecamCamera()`, `setFacecamEffect()`, `setFacecamScale()`, `getFacecamState()`. | **Tuân thủ hợp đồng**: Không sửa file domain repository của P2; mở rộng tại service implementation P1. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. Tính toán ma trận góc quay và lật gương trong `FacecamGeometry.kt`
```kotlin
fun calculateTransform(
    sensorOrientation: Int,
    displayRotationDegrees: Int,
    viewWidth: Float,
    viewHeight: Float,
    isFrontCamera: Boolean = true
): TransformResult {
    val rotation = calculateRotation(sensorOrientation, displayRotationDegrees)
    val needsAspectInversion = rotation == 90 || rotation == 270

    var sx = 1.0f
    var sy = 1.0f
    if (needsAspectInversion && viewHeight > 0f && viewWidth > 0f) {
        sx = viewWidth / viewHeight
        sy = viewHeight / viewWidth
    }

    if (isFrontCamera) {
        sx = -sx
    }

    return TransformResult(
        rotation = rotation,
        scaleX = sx,
        scaleY = sy,
        isMirrored = isFrontCamera
    )
}
```

### 3.2. Cử chỉ kéo thả và loại bỏ khung đen trong `FacecamOverlay.kt`
```kotlin
fun show() {
    // Start with alpha 0f so black rectangle never flashes before first camera frame arrives
    texture.alpha = 0f
    texture.clipToOutline = true
    texture.outlineProvider = object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            outline.setRoundRect(0, 0, view.width, view.height, cornerRadius)
        }
    }

    setupDrag(texture)
    // ...
}

override fun onSurfaceTextureUpdated(value: SurfaceTexture) {
    if (!ready) {
        ready = true
        // First valid camera frame rendered: reveal facecam smoothly
        main.post {
            if (!closed) texture.alpha = 1f
        }
    }
}
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. Android JVM Unit Tests
- **Lệnh thực thi:** `cd android && ./gradlew :app:testDebugUnitTest`
- **Kết quả:** `BUILD SUCCESSFUL in 23s`
- **Chi tiết kết quả các test suite (91/91 PASS):**
  - `FacecamGeometryTest`: **9/9 tests PASS** (rotation degrees, transform aspect inversion & mirroring, scale clamping, scaled dimensions, clamp position, snap to edge, effect validation & names, camera facing toggle, state validation).
  - `DrawingStrokeEngineTest`: **10/10 tests PASS**.
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
- **Lệnh thực thi:** `flutter test test/facecam_contract_test.dart --no-pub`
- **Kết quả:** `All tests passed!` (4/4 tests PASS):
  - `switchFacecamCamera invokes native method`: PASS.
  - `setFacecamEffect sends effect integer code`: PASS.
  - `setFacecamScale sends scale factor`: PASS.
  - `getFacecamState returns current facecam status map`: PASS.

### 4.3. Phân tích tĩnh & Định dạng mã nguồn
- **Lệnh thực thi:** `flutter analyze --no-pub`
  - **Kết quả:** `No issues found! (ran in 7.8s)`
- **Lệnh thực thi:** `git diff --check`
  - **Kết quả:** Hoàn toàn sạch sẽ, không có lỗi khoảng trắng thừa (Clean).

---

## 5. Yêu cầu tích hợp đối với P2 (P2 Blocker)
- Chi tiết bàn giao được lập tại [`docs/p1/TASK_12_P2_INTEGRATION_REQUESTS.md`](./TASK_12_P2_INTEGRATION_REQUESTS.md):
  1. Khi P2 dỡ bỏ lệnh UI Freeze, tích hợp các nút Flip Camera (đổi camera trước/sau), bộ chọn hiệu ứng màu sắc (Normal, Mono, Negative, Sepia,...) và thanh trượt cỡ Facecam vào thanh công cụ hoặc menu của phiên quay.
  2. Kết nối trực tiếp các nút đó tới `recordingService.switchFacecamCamera()`, `setFacecamEffect()`, `setFacecamScale()`.

---

## 6. Hạn chế & Xác nhận

- **Xác nhận UI/Icon Freeze:** P1 không thay đổi bất kỳ UI widget tree, layout hay icon nào của ứng dụng Flutter; giữ nguyên toàn bộ asset hiện hành.
- **DEVICE VERIFICATION PENDING:** Việc luồng hình ảnh Facecam hiển thị trên màn hình có được MediaProjection thu vào file MP4 hoàn chỉnh hay không phụ thuộc vào chính sách phân lớp của SurfaceFlinger / OEM compositor và quyền ghi Entire screen vs Single app trên Android 14+. Yêu cầu kiểm tra trực tiếp trên thiết bị vật lý.

---

## 7. Kết luận
- **Trạng thái:** **PARTIAL / NEEDS DEVICE VERIFICATION**.
- Mã nguồn sạch sẽ, không có regressions, sẵn sàng bàn giao cho P2 và thử nghiệm trên thiết bị Android vật lý.
