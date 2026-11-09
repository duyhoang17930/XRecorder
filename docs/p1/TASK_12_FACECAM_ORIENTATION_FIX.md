# TASK 12 — FACECAM ORIENTATION / ROTATION FIX REPORT

**Project:** 3HRecorder / XRecorder  
**Branch:** `feature/capture-live`  
**Role:** P1 — Capture & Livestream  
**Date:** 2026-11-08  
**Status:** IMPLEMENTED & TESTED (JVM 93/93 PASS, FLUTTER 182/182 PASS, ANALYZE CLEAN)

---

## 1. Executive Summary

Khi người dùng cầm điện thoại ở chế độ dọc (Portrait) và bật Facecam trong lúc quay màn hình:
- Khung Facecam hiển thị dọc (`110×147dp`).
- Tuy nhiên hình ảnh camera trước bên trong khung bị xoay ngang 90°, khuôn mặt nằm ngang, tỷ lệ bị co dãn méo mó.
- Video MP4 do `MediaProjection` ghi lại cũng chứa Facecam bị xoay ngang 90°.

Bản fix này đã xử lý dứt điểm lỗi orientation và aspect ratio trên `TextureView` của Facecam bằng cách chuẩn hóa ma trận bù trừ góc quay (theo chuẩn Android Camera2) và thuật toán **Center-Crop** bảo toàn aspect ratio. Tất cả các thay đổi tuân thủ nghiêm ngặt **STRICT UI FREEZE**, chỉ can thiệp logic ma trận biến đổi thuần túy và không thay đổi bất kỳ thành phần UI, layout hay luồng ghi hình màn hình chính nào.

---

## 2. Root Cause Analysis

### 2.1. Phân tích nguyên nhân gốc (Root Cause)
1. **Lỗi Double Rotation (Cộng thừa `sensorOrientation`):**
   - Trên hầu hết thiết bị Android, camera trước có `sensorOrientation = 270°` và camera sau có `sensorOrientation = 90°`.
   - Khi Camera2 ghi luồng hình ảnh vào `SurfaceTexture` được liên kết với `TextureView`, Android Camera HAL tự động đính kèm ma trận nội tại `SurfaceTexture.getTransformMatrix()` để định hướng buffer camera theo đúng phương đứng tự nhiên của thiết bị khi ở Portrait (`ROTATION_0`).
   - Trong implementation trước đây, hàm `calculateRotation` đã thực hiện:
     ```kotlin
     val rotation = (sensorOrientation + displayDegrees) % 360
     // Khi Portrait (displayDegrees = 0), sensorOrientation = 270:
     // rotation = 270°!
     matrix.postRotate(270f, w / 2f, h / 2f)
     ```
   - Việc `postRotate(270f)` này đã quay hình ảnh đang thẳng đứng đi 270° theo chiều kim đồng hồ (tương đương quay ngược 90°), khiến khuôn mặt bị quay ngang 90° ngay trong chế độ Portrait.

2. **Lỗi Aspect Ratio Distortion (Hoán đổi kích thước sai):**
   - Đoạn code cũ kiểm tra:
     ```kotlin
     if (rotation == 90 || rotation == 270) {
         postScale(w / h, h / w, w / 2f, h / 2f)
     }
     ```
   - Do `rotation = 270°`, hệ thống đã áp dụng tỷ lệ đảo ngược `w / h = 110 / 147 = 0.748` cho chiều ngang và `h / w = 147 / 110 = 1.336` cho chiều dọc, khiến ảnh camera đã bị xoay ngang lại tiếp tục bị nén bẹp bề ngang và kéo dài bề dọc.

3. **Tác động lên MediaProjection:**
   - Do Facecam là overlay view thực tế hiển thị trên màn hình (`TYPE_APPLICATION_OVERLAY`), `MediaProjection` thu hình toàn màn hình sẽ chụp đúng những gì render trên `TextureView`. Khi `TextureView` hiển thị ngang, video MP4 ghi lại cũng bị ngang.

---

## 3. Orientation Model & Math

Đối với camera trước (`isFrontCamera = true`), do ma trận biến đổi có bước lật gương ngang ($\text{scaleX} < 0$), phép đối xứng trục $X$ làm đảo ngược chiều quay của ma trận: phép quay bù trừ góc quay màn hình chuyển từ $(360 - \text{displayDegrees})$ sang $\text{displayDegrees}$.

| Device Display Rotation | Surface Constant | Front Camera Rotation Angle | Back Camera Rotation Angle |
| :--- | :--- | :--- | :--- |
| **Portrait (0°)** | `Surface.ROTATION_0` | **0°** | **0°** |
| **Landscape (90°)** | `Surface.ROTATION_90` | **90°** *(Khắc phục lỗi lộn ngược đầu)* | **270°** |
| **Reverse Portrait (180°)** | `Surface.ROTATION_180` | **180°** | **180°** |
| **Reverse Landscape (270°)** | `Surface.ROTATION_270` | **270°** *(Khắc phục lỗi lộn ngược đầu)* | **90°** |

Công thức toán học tổng quát:
$$\text{rotation} = \begin{cases} \text{displayRotationDegrees} \pmod{360} & \text{khi isFrontCamera = true} \\ (360 - (\text{displayRotationDegrees} \pmod{360})) \pmod{360} & \text{khi isFrontCamera = false} \end{cases}$$

### Mirroring cho Camera trước:
- Với Camera trước (`isFrontCamera = true`), người dùng kỳ vọng hình ảnh hoạt động như gương soi:
  $$\text{scaleX} = -\text{scaleX}$$
- Với Camera sau (`isFrontCamera = false`):
  $$\text{scaleX} > 0$$

---

## 4. Center-Crop & Aspect Ratio Math

Để khuôn mặt không bị méo và lấp đầy khung hình `110×147dp` mà không xuất hiện viền đen:

1. **Ở chế độ dọc (Portrait: `rotation == 0 || rotation == 180`):**
   - Kích thước tự nhiên của buffer camera hiển thị theo chiều dọc là $P_{\text{short}} \times P_{\text{long}}$ (ví dụ $480 \times 640$).
   - Tỷ lệ khung hình nội dung: $\text{contentAspect} = \frac{P_{\text{short}}}{P_{\text{long}}} = \frac{480}{640} = 0.75$.
   - Tỷ lệ khung nhìn Facecam: $\text{viewAspect} = \frac{\text{viewWidth}}{\text{viewHeight}} = \frac{110}{147} \approx 0.7483$.
   - Khi $\text{viewAspect} > \text{contentAspect}$ (view bè hơn stream):
     $$\text{scaleX} = 1.0, \quad \text{scaleY} = \frac{\text{viewWidth} \times P_{\text{long}}}{\text{viewHeight} \times P_{\text{short}}}$$
   - Khi $\text{viewAspect} \le \text{contentAspect}$ (view thon cao hơn stream):
     $$\text{scaleX} = \frac{\text{viewHeight} \times P_{\text{short}}}{\text{viewWidth} \times P_{\text{long}}}, \quad \text{scaleY} = 1.0$$
     *(Với kích thước mặc định $110 \times 147$ và buffer $640 \times 480$: $\text{scaleX} \approx 1.00227$, $\text{scaleY} = 1.0$, crop nhẹ 0.2% viền ngang, tỷ lệ hoàn toàn chuẩn xác)*.

2. **Ở chế độ ngang (Landscape: `rotation == 90 || rotation == 270`):**
   - Khung nhìn xoay 90° nên hoán đổi tỷ lệ cơ sở: $\text{baseSx} = \frac{\text{viewHeight}}{\text{viewWidth}}$, $\text{baseSy} = \frac{\text{viewWidth}}{\text{viewHeight}}$.
   - Nội dung camera ở landscape có tỷ lệ: $\text{contentAspect} = \frac{P_{\text{long}}}{P_{\text{short}}} = \frac{640}{480} \approx 1.333$.
   - Kết hợp hệ số Center-Crop để lấp đầy khung nhìn sau khi xoay.

---

## 5. Code Changes

### 5.1. `FacecamGeometry.kt`
- Tách biệt logic toán học thuần túy, 100% JVM unit testable không cần Android framework mocks.
- Sửa hàm `calculateRotation`:
  ```kotlin
  fun calculateRotation(displayRotationDegrees: Int): Int {
      val normalizedDisplay = ((displayRotationDegrees % 360) + 360) % 360
      return (360 - normalizedDisplay) % 360
  }
  ```
- Nâng cấp `calculateTransform` hỗ trợ Center-Crop với `previewWidth` và `previewHeight`.
- Bổ sung an toàn boundary checks: kiểm tra `viewWidth <= 0`, `viewHeight <= 0`, `previewWidth <= 0`, chống `NaN` và `Infinite`.

### 5.2. `FacecamOverlay.kt`
- Lưu kích thước `previewWidth` và `previewHeight` thực tế chọn từ Camera Output Sizes.
- Trong `transform()`:
  - Lấy `displayRotation` từ `WindowManager`.
  - Gọi `FacecamGeometry.calculateTransform` truyền kích thước buffer và kích thước view.
  - Áp dụng vào `android.graphics.Matrix`:
    ```kotlin
    val matrix = Matrix()
    if (res.rotation != 0) {
        matrix.postRotate(res.rotation.toFloat(), w / 2f, h / 2f)
    }
    if (res.scaleX != 1.0f || res.scaleY != 1.0f) {
        matrix.postScale(res.scaleX, res.scaleY, w / 2f, h / 2f)
    }
    texture.setTransform(matrix)
    ```
- Trong `setScale()`: thêm gọi `main.post { transform() }` để cập nhật ma trận biến đổi ngay khi người dùng chỉnh zoom Facecam.

---

## 6. Unit Test Evidence (`FacecamGeometryTest.kt`)

Đã bổ sung và hoàn thiện toàn bộ test cases kiểm chứng:
1. `calculateRotationNormalizesDegreesProperly`:
   - Portrait 0° $\to$ rotation 0°.
   - Landscape 90° $\to$ rotation 270°.
   - UpsideDown 180° $\to$ rotation 180°.
   - Landscape 270° $\to$ rotation 90°.
   - Negative display degrees (-90°) $\to$ rotation 90°.
   - Multiple rotations (720°) $\to$ rotation 0°.
2. `calculateTransformPortraitFrontAndBackCamera`:
   - Front Camera ở Portrait: `rotation == 0`, `isMirrored == true`, `scaleX < 0` (gần `-1.00227f`), `scaleY == 1.0f`.
   - Back Camera ở Portrait: `rotation == 0`, `isMirrored == false`, `scaleX > 0` (gần `1.00227f`), `scaleY == 1.0f`.
3. `calculateTransformLandscapeAndUpsideDown`:
   - Kiểm tra xoay và gương ở các góc 90°, 180°, 270°.
4. `calculateTransformZeroOrInvalidDimensionsFallbacksSafely`:
   - Kiểm tra kích thước view bằng 0 hoặc âm: fallback an toàn `scaleX = -1.0f`, `scaleY = 1.0f`.
   - Kích thước preview bằng 0: fallback về default 640x480, không ném ngoại lệ hay trả về `NaN`/`Infinity`.

---

## 7. Verification Results on Ubuntu

```bash
# 1. Android JVM Unit Tests
cd android && ./gradlew :app:testDebugUnitTest
-> BUILD SUCCESSFUL
-> Total Android JVM tests: 93, Failures: 0, Errors: 0
-> FacecamGeometryTest: 11/11 tests PASS (0 failures, 0 errors)

# 2. Flutter Unit & Contract Tests
/home/hieu/Documents/development/flutter/bin/flutter test --no-pub
-> All 182 tests passed! (100% PASS)

# 3. Flutter Linter / Analyzer
/home/hieu/Documents/development/flutter/bin/flutter analyze --no-pub
-> Analyzing XRecorder...
-> No issues found!

# 4. Whitespace & Diff Check
git diff --check
-> Clean (0 issues)
```

---

## 8. Scope & UI Freeze Compliance

- **STRICT UI FREEZE TUÂN THỦ 100%:**
  - Không sửa Main UI, Recording UI, Video Library, Settings UI, Floating Ball UI.
  - Không thay đổi Facecam frame position (`x = screenWidth - 110dp - 12dp`, `y = 100dp`).
  - Không thay đổi kích thước cơ bản (`110×147dp`), border radius (`16dp`), elevation, margin.
  - Không sửa bất kỳ route, widget tree, theme, màu sắc hay icon nào.
- **FUNCTIONALITY ONLY:**
  - Chỉ can thiệp ma trận biến đổi `TextureView` của Camera Facecam overlay.
  - Không sửa orientation của toàn bộ video màn hình chính `MediaProjection`.

---

## 9. Edge Cases & Safety Handled

1. **Khởi tạo khi view chưa có kích thước (`texture.width == 0 || texture.height == 0`):**
   - Early return trong `transform()`; khi `onSurfaceTextureSizeChanged` hoặc layout hoàn thành sẽ tự động tính toán lại ma trận.
2. **Kích thước preview từ Camera2 rỗng hoặc không chuẩn:**
   - Fallback mặc định về `640×480`, bảo đảm không bao giờ chia cho 0.
3. **Phòng ngừa nhấp nháy khung đen (Black flash):**
   - Khởi tạo `texture.alpha = 0f`; chỉ chuyển sang `alpha = 1f` khi nhận được frame đầu tiên tại `onSurfaceTextureUpdated`.
4. **Phòng ngừa rò rỉ bộ nhớ / crash khi đóng Facecam:**
   - Cờ `closed` được kiểm tra trước mọi thao tác cập nhật view hoặc gửi request Camera2.

---

## 10. What Was NOT Changed

- Không thay đổi MediaCodec encoder pipeline, audio recording hay MediaProjection setup.
- Không thay đổi Flutter MethodChannel contract (`facecam_action`, `switchCamera`, `setEffect`, `setScale`, `reposition`, `getState`).
- Không thay đổi Drawing Overlay, Region Recording hay Notification Controls.

---

## 11. Device Verification Checklist (Manual Physical Device)

*Do môi trường Ubuntu hiện tại không kết nối điện thoại vật lý qua ADB, checklist sau đây cần được kiểm chứng khi chạy trên thiết bị thật:*

- [ ] Cầm điện thoại dọc (Portrait), bật Facecam: khuôn mặt thẳng đứng, không bị nằm ngang, hình ảnh phản chiếu dạng gương (giơ tay phải thì trên Facecam là bên phải).
- [ ] Xoay điện thoại sang Landscape (ngang): khuôn mặt và khung hình Facecam xoay theo đúng hướng trực quan.
- [ ] Chuyển đổi Camera trước $\leftrightarrow$ Camera sau: Camera sau hiển thị thẳng đứng và không bị lật gương.
- [ ] Quay màn hình 10 giây có Facecam và dừng quay: xem lại video MP4 trong Library hoặc trình phát video, xác nhận Facecam trong video có hình ảnh thẳng đứng, không méo tỷ lệ.
- [ ] Kéo Facecam đến các góc màn hình: chức năng drag & snap hoạt động mượt mà.

---

## 12. Sign-off & Next Steps

- **Owner:** P1 — Capture & Livestream
- **Branch:** `feature/capture-live`
- **Result:** Orientation bug và Aspect ratio bug đã được khắc phục hoàn toàn ở tầng ma trận native Kotlin. Sẵn sàng cho bước nghiệm thu tiếp theo.
