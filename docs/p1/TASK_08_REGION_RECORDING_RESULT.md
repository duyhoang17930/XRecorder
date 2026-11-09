# Task 08 — Region Recording F03 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ toán học hình học, chuẩn hóa tọa độ DP ↔ Px, validation crop, tích hợp pipeline cấu hình native và Dart contract đã PASS 100% host tests; kiểm chứng pixel-perfect MP4 crop thực tế trên phần cứng cần thiết bị thật).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện hạ tầng chức năng **F03 Region Recording** (quay vùng màn hình lựa chọn): chuẩn hóa tọa độ Flutter DP / Physical Pixels, giới hạn bounds theo màn hình thực tế đang capture, căn chỉnh chẵn (even alignment) cho MediaCodec, bảo toàn tỉ lệ khung hình (aspect ratio) không méo và không tạo letterbox/pillarbox sai lệch; tôn trọng one-shot MediaProjection consent.
- **Phạm vi kiểm thử:** Máy chủ Ubuntu cục bộ, **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **54/54 native JVM unit tests PASS** (gồm 14 tests mới trong `RegionCropGeometryTest` và 40 tests hồi quy cho 8 test suites native cũ).
  - **35/35 Flutter Dart unit/contract/controller tests PASS** (gồm 3 tests mới trong `region_recording_contract_test.dart` và 32 tests hồi quy cũ).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Sạch sẽ, không có lỗi khoảng trắng).
- **Tuân thủ quy tắc:**
  - **UI Freeze:** Không tự ý tạo UI selector overlay hay cử chỉ mới; giữ nguyên 100% Flutter widget tree hiện hữu.
  - **P2 Integration:** Ghi nhận thiếu sót về UI chọn vùng và trường `crop` trong `RecordingSettings` tại [`TASK_08_P2_INTEGRATION_REQUESTS.md`](TASK_08_P2_INTEGRATION_REQUESTS.md).
  - **Engine Integrity:** Bảo toàn hoàn toàn vòng đời encoder, timers, audio sync và notification controls của các Task 02–07.

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Hình học & Toán học Crop ([`RegionCropGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/RegionCropGeometry.kt))** | Chưa có logic crop vùng; audit Task 01 xếp loại `F03: MISSING`. | Xây dựng bộ toán học thuần Kotlin: chuyển đổi DP ↔ Px, kẹp biên màn hình thực (`sanitizeRegion`), ép căn lề số chẵn (`alignment = 2` cho macroblocks), kiểm tra giới hạn kích thước tối thiểu (160×160), tính UV texture coordinates (`normalizedCrop`), và kiểm tra aspect ratio. | **Chính xác & Độc lập**: Hoàn toàn không phụ thuộc Android runtime stubs, kiểm thử được 100% trên JVM host. |
| **Cấu hình Native ([`CaptureConfig.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt))** | Chỉ nhận độ phân giải preset toàn màn hình (`width`, `height`). | Bổ sung các trường `cropX`, `cropY`, `cropWidth`, `cropHeight`, cờ `isRegion`. Khi có tọa độ vùng hợp lệ, độ phân giải encoder (`width`, `height`) được gán chính xác theo kích thước vùng đã cắt; bitrate tự động co giãn theo diện tích vùng. | **Đúng kích thước thực**: MP4 video sinh ra có kích thước đúng bằng vùng chọn, không dải đen, không méo hình. |
| **Bảo vệ Resize màn hình ([`CaptureService.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt))** | `onCapturedContentResize` tự động resize VirtualDisplay theo sự kiện hệ thống. | Với phiên `config.isRegion`, bỏ qua các lệnh resize VirtualDisplay giữa chừng để bảo toàn cố định khung canvas vùng chọn ban đầu. | Tránh phá vỡ tỉ lệ và cấu trúc encoder surface của vùng quay. |
| **Hợp đồng Dart ([`recording_service.dart`](../../lib/features/recording/recording_service.dart))** | `start(settings)` chỉ truyền payload preset cố định. | Mở rộng `start(settings, {int? cropX, int? cropY, int? cropWidth, int? cropHeight})` hoàn toàn tương thích ngược; tự động đính kèm thông số crop vào MethodChannel payload nếu có. | Cho phép kích hoạt quay khu vực ngay khi P2 bổ sung UI chọn vùng. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. `RegionCropGeometry.kt`
- Chuẩn hóa và kẹp biên vùng chọn theo độ phân giải màn hình thực:
```kotlin
fun sanitizeRegion(
    x: Int, y: Int, width: Int, height: Int,
    displayWidth: Int, displayHeight: Int,
    minDimension: Int = 160, alignment: Int = 2
): CropRect? {
    if (displayWidth <= 0 || displayHeight <= 0) return null
    if (width <= 0 || height <= 0) return null
    if (x >= displayWidth || y >= displayHeight || x + width <= 0 || y + height <= 0) return null

    val clampedX = maxOf(0, x)
    val clampedY = maxOf(0, y)
    val clampedRight = minOf(displayWidth, x + width)
    val clampedBottom = minOf(displayHeight, y + height)

    val clampedWidth = clampedRight - clampedX
    val clampedHeight = clampedBottom - clampedY
    if (clampedWidth <= 0 || clampedHeight <= 0) return null

    val alignFactor = maxOf(1, alignment)
    val alignedWidth = (clampedWidth / alignFactor) * alignFactor
    val alignedHeight = (clampedHeight / alignFactor) * alignFactor
    if (alignedWidth < minDimension || alignedHeight < minDimension) return null

    return CropRect(clampedX, clampedY, alignedWidth, alignedHeight)
}
```

### 3.2. `CaptureConfig.kt`
- Tích hợp vùng chọn vào kích thước encoder:
```kotlin
val rawCropX = (data["cropX"] as? Number)?.toInt()
val rawCropY = (data["cropY"] as? Number)?.toInt()
val rawCropW = (data["cropWidth"] as? Number)?.toInt()
val rawCropH = (data["cropHeight"] as? Number)?.toInt()

val metrics = context.resources.displayMetrics
val sanitizedCrop = if (rawCropX != null && rawCropY != null && rawCropW != null && rawCropH != null) {
    RegionCropGeometry.sanitizeRegion(
        rawCropX, rawCropY, rawCropW, rawCropH,
        metrics.widthPixels, metrics.heightPixels
    ) ?: throw IllegalArgumentException("Selected capture region is invalid or too small. Ensure it is within screen bounds and at least 160x160.")
} else null

val requestedWidth = sanitizedCrop?.width ?: number("width", 1280)
val requestedHeight = sanitizedCrop?.height ?: number("height", 720)
...
val width = sanitizedCrop?.width ?: if (portrait) shortEdge else longEdge
val height = sanitizedCrop?.height ?: if (portrait) longEdge else shortEdge
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. JVM Unit Tests (Android / Kotlin)
Lệnh: `cd android && ./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'`  
Kết quả: **BUILD SUCCESSFUL, 54 tests PASS, 0 failures, 0 errors** across 9 test suites:
1. `RegionCropGeometryTest`: **14 tests PASS**
   - `dpToPxConvertsAccurately`: PASS
   - `pxToDpConvertsAccurately`: PASS
   - `sanitizeRegionValidInBoundsAligned`: PASS
   - `sanitizeRegionClampsNegativeCoordinatesToZero`: PASS
   - `sanitizeRegionClampsOverflowingCoordinatesToDisplayBounds`: PASS
   - `sanitizeRegionEnforcesAlignmentToEvenNumbers`: PASS
   - `sanitizeRegionRejectsEmptyOrNegativeDimensions`: PASS
   - `sanitizeRegionRejectsCoordinatesCompletelyOutsideDisplay`: PASS
   - `sanitizeRegionRejectsRegionSmallerThanMinimumDimension`: PASS
   - `sanitizeRegionRejectsInvalidDisplayDimensions`: PASS
   - `fromDpConvertsAndSanitizes`: PASS
   - `normalizedCropCalculatesCorrectUvTextureCoordinates`: PASS
   - `aspectRatioCalculatesAccurateRatio`: PASS
   - `fitsDisplayValidatesBounds`: PASS
2. `CaptureNotificationPolicyTest`: **11 tests PASS**
3. `CaptureRequestsTest`: **8 tests PASS**
4. `CaptureTimingTest`: **4 tests PASS**
5. `ScreenshotPixelsTest`: **4 tests PASS**
6. `VideoBitrateTest`: **4 tests PASS**
7. `CaptureJournalTest`: **3 tests PASS**
8. `FloatingControlGeometryTest`: **3 tests PASS**
9. `AudioVideoMathTest`: **3 tests PASS**

### 4.2. Flutter Dart Unit & Contract Tests
Lệnh: `flutter test --no-pub test/region_recording_contract_test.dart test/recording_service_contract_test.dart test/recording_replay_test.dart test/recording_cancel_semantics_test.dart test/capture_library_finder_test.dart test/recording_controller_test.dart test/recording_setup_sheet_test.dart`  
Kết quả: **35 tests PASS, 0 failures**
- `region_recording_contract_test.dart` (3 tests): PASS kiểm tra chuyển tiếp tham số `cropX, cropY, cropWidth, cropHeight`, giữ nguyên mặc định khi không crop, và trích xuất cấu hình đúng từ snapshot native.
- Toàn bộ 32 test cases hồi quy của Task 00–07 PASS 100%.

### 4.3. Static Analysis
- `flutter analyze --no-pub`: **No issues found!** (ran in 8.5s)
- `git diff --check`: **Clean** (No trailing whitespace, no merge conflicts).

---

## 5. Xác nhận UI Freeze & Icon Consistency

- Không sửa đổi bất kỳ widget UI, màu sắc, typography hay router nào trong `lib/`.
- Không thêm bất kỳ icon mới nào.
- Giữ nguyên toàn bộ logic hiện tại của `recording_setup_sheet.dart` và `recording_settings_form.dart`.

---

## 6. Hạn chế & Hạng mục cần kiểm chứng trên thiết bị (NEEDS DEVICE VERIFICATION)

1. Kiểm chứng frame pixel-perfect khi MediaProjection ghi hình thực tế một vùng crop trên các chipset SoC khác nhau (Qualcomm Adreno, MediaTek Mali, PowerVR).
2. Xoay màn hình (orientation change): Trong lúc đang quay vùng chọn, việc xoay màn hình thiết bị có thể làm thay đổi nội dung vùng hiển thị bên dưới; phiên quay hiện tại khóa hướng theo thiết lập khởi tạo ban đầu (`config.orientation`).
3. Tích hợp UI chọn vùng từ P2: Chờ P2 triển khai UI kéo chọn vùng hoặc khung selector để kết nối trọn vẹn trải nghiệm người dùng từ giao diện đến native pipeline.
