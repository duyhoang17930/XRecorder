# TASK 12 — FIX FACECAM UPSIDE-DOWN IN BOTH LANDSCAPE DIRECTIONS REPORT

**Project:** 3HRecorder / XRecorder  
**Branch:** `feature/capture-live`  
**Role:** P1 — Capture, Realtime & Livestream  
**Date:** 2026-11-09  
**Status:** IMPLEMENTED & UNIT TESTED (JVM 127/127 PASS, 14/14 FACECAM TESTS PASS, DEVICE VERIFICATION PENDING)

---

## 1. Root Cause Analysis

### 1.1. Thực trạng trước khi sửa
Trên thiết bị kiểm thử thực tế của người dùng:
- **Portrait (điện thoại dọc):** Hình ảnh người dùng thẳng đứng, tự nhiên, đầu ở trên, thân ở dưới (**ĐÚNG**).
- **Landscape Left (xoay ngang sang trái / 90°):** Người bị lộn ngược 180° (**NGƯỢC**).
- **Landscape Right (xoay ngang sang phải / 270°):** Người bị lộn ngược 180° (**NGƯỢC**).
- **Khung UI Facecam:** Kích thước cố định ($110 \times 147\text{ dp}$), vị trí, bo góc $16\text{ dp}$ hoàn toàn phù hợp và không thay đổi.

### 1.2. Nguyên nhân cốt lõi khiến Landscape bị lộn ngược cả hai hướng (Upside-Down in Both Directions)
1. **Toán học góc quay bù trừ ma trận TextureView và phép lật gương:**
   - Trong Camera2, camera trước (`LENS_FACING_FRONT`) có `sensorOrientation = 270°`. Camera HAL tự động định hướng buffer cho Portrait khi hiển thị qua `SurfaceTexture`.
   - Để tạo hiệu ứng gương soi cho camera trước, ma trận `TextureView` áp dụng `scaleX < 0` (lật gương trục hoành).
   - Khi áp dụng ma trận: $\mathbf{M} = \mathbf{S}(-sx, sy) \times \mathbf{R}(\theta)$.
   - Đối với vector từ thân lên đầu người dùng trong camera stream khi xoay máy:
     * Ở **Landscape Left (90°)**: Người dùng ngồi thẳng đứng trước máy xoay ngang 90° ngược chiều kim đồng hồ $\implies$ vector đầu người trong stream là $\mathbf{v} = (1, 0)$.
     * Khi áp dụng góc xoay $\theta = 90^\circ$:
       $$Y_{\text{head}} = sy \sin(90^\circ) = +sy > 0 \implies \text{Đầu người bị đẩy xuống dưới (NGƯỢC 180°)!}$$
     * Ở **Landscape Right (270°)**: Vector đầu người trong stream là $\mathbf{v} = (-1, 0)$.
     * Khi áp dụng góc xoay $\theta = 270^\circ$:
       $$Y_{\text{head}} = -sy \sin(270^\circ) = -sy(-1) = +sy > 0 \implies \text{Đầu người bị đẩy xuống dưới (NGƯỢC 180°)!}$$
   - **Kết luận:** Khi trước đây gán góc quay cho Landscape Left là $90^\circ$ và Landscape Right là $270^\circ$, giá trị $\sin(\theta)$ mang dấu dương khiến tọa độ trục $Y$ của đầu người luôn rơi vào nửa dưới màn hình ($Y > 0$), dẫn đến người bị lộn ngược cả 2 hướng ngang!

2. **Khắc phục dứt điểm:**
   - Để đầu người hướng lên trên ($Y_{\text{head}} < 0$):
     * Ở Landscape Left (90°): $\theta$ **bắt buộc phải là $270^\circ$** $\implies Y_{\text{head}} = sy \sin(270^\circ) = -sy < 0$ (Đầu ở trên, thân ở dưới).
     * Ở Landscape Right (270°): $\theta$ **bắt buộc phải là $90^\circ$** $\implies Y_{\text{head}} = -sy \sin(90^\circ) = -sy < 0$ (Đầu ở trên, thân ở dưới).
   - Công thức toán học chuẩn xác, thuần túy và đối xứng cho mọi góc quay:
     $$\text{rotation} = (360 - \text{displayRotationDegrees}) \pmod{360}$$
     * $0^\circ \to 0^\circ$ (Portrait giữ nguyên 100%).
     * $90^\circ \to 270^\circ$ (Landscape Left đầu ở trên).
     * $180^\circ \to 180^\circ$ (Reverse Portrait).
     * $270^\circ \to 90^\circ$ (Landscape Right đầu ở trên).

---

## 2. Transformation Trước và Sau khi sửa

| Chiều quay thiết bị | Display Rotation | Góc xoay cũ (Lỗi ngược đầu) | Góc xoay mới (Đầu trên - Thân dưới) | Hướng đầu người ($Y_{\text{head}}$) |
| :--- | :--- | :--- | :--- | :--- |
| **Portrait (Dọc)** | $0^\circ$ | $0^\circ$ | **$0^\circ$** (Giữ nguyên) | $Y < 0$ (Ở TRÊN) |
| **Landscape Left (Ngang trái)** | $90^\circ$ | $90^\circ$ | **$270^\circ$** | $Y < 0$ (Ở TRÊN) |
| **Reverse Portrait (Dọc ngược)** | $180^\circ$ | $180^\circ$ | **$180^\circ$** | $Y < 0$ (Ở TRÊN) |
| **Landscape Right (Ngang phải)** | $270^\circ$ | $270^\circ$ | **$90^\circ$** | $Y < 0$ (Ở TRÊN) |

### Center-Crop và bảo toàn Aspect Ratio (Không méo hình):
- Khi xoay $90^\circ$ hoặc $270^\circ$, các trục của camera stream bị hoán đổi so với khung chữ nhật đứng $110 \times 147$:
  * Scale X: $|sx| = \frac{P_{\text{short}}}{P_{\text{long}}} = \frac{480}{640} = 0.75$.
  * Scale Y: $sy = \frac{H_{\text{view}}}{W_{\text{view}}} = \frac{147}{110} \approx 1.33636$.
- Kích thước hiển thị thực tế trên màn hình:
  * Chiều ngang: $147 \times 0.75 = 110.25\text{ px}$ (lấp đầy bề rộng $110\text{ px}$, crop nhẹ $0.25\text{ px}$).
  * Chiều dọc: $110 \times 1.33636 = 147.0\text{ px}$ (lấp đầy hoàn hảo bề cao $147\text{ px}$).
- Tỷ lệ khung hình hiển thị: $\frac{110.25}{147} = 0.75$, **đồng nhất 100% với tỷ lệ ở chế độ Portrait**, loại bỏ hoàn toàn hiện tượng méo mặt hay kéo dãn.

---

## 3. Tại sao Portrait đúng nhưng Landscape sai?
- Ở chế độ Portrait ($0^\circ$), không có phép quay ma trận nào được áp dụng ($\theta = 0^\circ$). Trục Y của camera buffer đi thẳng vào trục Y của màn hình, do đó người dùng hiển thị thẳng đứng tự nhiên.
- Khi xoay sang Landscape, góc xoay cũ chọn $90^\circ$ và $270^\circ$ tương thích với camera sau nhưng lại làm đảo ngược dấu của trục Y khi đi qua ma trận lật gương ngang của camera trước, làm cho đầu người bị hướng xuống đáy màn hình ở cả 2 hướng ngang.

---

## 4. Xử lý Landscape Left & Landscape Right
- **Landscape Left ($90^\circ$):** Ma trận `postRotate(270f)` sau đó `postScale(-sx, sy)`. Đầu người ở phía trên theo hướng người dùng đang nhìn màn hình.
- **Landscape Right ($270^\circ$):** Ma trận `postRotate(90f)` sau đó `postScale(-sx, sy)`. Đầu người ở phía trên theo hướng người dùng đang nhìn màn hình.
- **Xoay qua lại giữa Landscape Left $\leftrightarrow$ Landscape Right:** Hàm thuần túy đọc trực tiếp hướng hiển thị hệ thống thông qua `DisplayManager.DisplayListener`, tính toán lại từ đầu, không cộng dồn, không trễ, không rò rỉ góc xoay.

---

## 5. UI Facecam và Container có giữ nguyên không?
- **STRICT UI FREEZE TUYỆT ĐỐI:**
  * Khung container Facecam giữ nguyên $110\text{ dp} \times 147\text{ dp}$, bo góc $16\text{ dp}$.
  * Container KHÔNG bị xoay, không bị đổi thành khung ngang, không thay đổi layout hay icon.
  * Chỉ sửa ma trận biến đổi của `TextureView` bên trong khung chứa.

---

## 6. Live Preview và Recorded MP4
- Facecam được render vào cửa sổ hệ thống `TYPE_APPLICATION_OVERLAY`.
- `MediaProjection` thu lại toàn bộ bề mặt màn hình để encode vào MP4.
- Do đó, khi live preview hiển thị người đứng thẳng đúng chiều, video MP4 ghi lại cũng sẽ xuất hiện người đứng thẳng đúng chiều tương ứng. Không can thiệp sửa metadata xoay của toàn bộ file video MP4.

---

## 7. Kết quả Test Tự Động

### Android JVM Unit Tests
```bash
./gradlew :app:testDebugUnitTest
BUILD SUCCESSFUL in 18s (50 actionable tasks)
```
- `com.xrecorder.xrecorder.recording.FacecamGeometryTest`: **14/14 tests PASS**.
- Toàn bộ test suite Android: **127/127 tests PASS** (100%).

Bao gồm 12 kịch bản bắt buộc theo prompt:
1. `sensorOrientation = 90°, display = 0°` $\to$ `rotation = 0°`, scaleX > 0 (PASS).
2. `sensorOrientation = 90°, display = 90°` $\to$ `rotation = 270°`, scaleX > 0 (PASS).
3. `sensorOrientation = 90°, display = 270°` $\to$ `rotation = 90°`, scaleX > 0 (PASS).
4. `sensorOrientation = 270°, display = 0°` $\to$ `rotation = 0°`, scaleX < 0 (PASS).
5. `sensorOrientation = 270°, display = 90°` $\to$ `rotation = 270°`, scaleX < 0 (PASS).
6. `sensorOrientation = 270°, display = 270°` $\to$ `rotation = 90°`, scaleX < 0 (PASS).
7. `Portrait -> Landscape Right -> Portrait` $\to$ 0° $\to$ 90° $\to$ 0° (PASS).
8. `Portrait -> Landscape Left -> Portrait` $\to$ 0° $\to$ 270° $\to$ 0° (PASS).
9. `Landscape Right -> Landscape Left` $\to$ 90° $\to$ 270° (PASS).
10. `No accumulated rotation` $\to$ giá trị độc lập, không tích lũy qua các vòng lặp (PASS).
11. `Mirroring independent from rotation` $\to$ góc quay đồng nhất giữa front/back, chỉ khác dấu scaleX (PASS).
12. `Aspect ratio preservation` $\to$ tỷ lệ khung hình trên màn hình là 0.75 cho cả Portrait và Landscape, không méo hình (PASS).

---

## 8. Các File Đã Thay Đổi
1. [`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometry.kt`](file:///home/hieu/Documents/Training/XRecorder/android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometry.kt):
   * Sửa `calculateRotation`: chuẩn hóa công thức `(360 - normalizedDisplay) % 360` cho mọi góc xoay.
   * Cải tiến `calculateTransform`: scale Center-Crop chống méo hình khi xoay $90^\circ/270^\circ$.
2. [`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt`](file:///home/hieu/Documents/Training/XRecorder/android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FacecamOverlay.kt):
   * Đăng ký `DisplayManager.DisplayListener` lắng nghe sự kiện xoay màn hình tự động ở cấp độ phần cứng / WindowManager hệ thống.
   * Cung cấp `onConfigurationChanged()` để đồng bộ xoay khi ứng dụng thay đổi cấu hình.
   * Giải phóng listener sạch sẽ trong `close()` chống rò rỉ bộ nhớ.
3. [`android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometryTest.kt`](file:///home/hieu/Documents/Training/XRecorder/android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/FacecamGeometryTest.kt):
   * Bổ sung đầy đủ 14 unit tests kiểm thử 12 kịch bản hướng xoay và ma trận.

---

## 9. Những vấn đề cần kiểm chứng trên thiết bị thực tế (Device Verification Pending)
* Do quy tắc kiểm thử `LOCAL TEST ONLY` (không dùng thiết bị thật, không ADB), cần kiểm chứng thực tế:
  1. Mở ứng dụng, bật Facecam ở chế độ Portrait $\implies$ xác nhận đầu ở trên, thân ở dưới.
  2. Xoay máy sang ngang bên trái (Landscape Left) $\implies$ xác nhận hình ảnh lập tức xoay, đầu người ở trên, thân ở dưới.
  3. Xoay máy sang ngang bên phải (Landscape Right) $\implies$ xác nhận hình ảnh lập tức xoay, đầu người ở trên, thân ở dưới.
  4. Mở một tựa game Landscape toàn màn hình $\implies$ xác nhận Facecam overlay tự động cập nhật đúng hướng người xem.
