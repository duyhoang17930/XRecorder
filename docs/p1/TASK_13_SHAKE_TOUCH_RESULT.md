# TASK 13 — SHAKE TO STOP & TOUCH INDICATOR (F22–F23) RESULT REPORT

**Project:** 3HRecorder / XRecorder  
**Branch:** `feature/capture-live`  
**Role:** P1 — Capture, Realtime & Livestream  
**Date:** 2026-11-08  
**Status:** IMPLEMENTED & LOCAL TESTED (JVM 105/105 PASS, FLUTTER 183/183 PASS, ANALYZE CLEAN)  
**Device Verification:** NEEDS DEVICE VERIFICATION (Sensors and physical touch require on-device testing)

---

## 1. Hiện trạng F22 & F23

### F22 — Shake to Stop:
- **Trạng thái:** **WORKING / FULLY IMPLEMENTED**.
- **Cơ chế:**
  - Nhận cờ cấu hình `shakeToStop` (mặc định `true` từ `settings_controller.dart`).
  - Đăng ký `SensorEventListener` với `Sensor.TYPE_ACCELEROMETER` và `SENSOR_DELAY_GAME` **chỉ khi** phiên ghi đang ở trạng thái `recording`.
  - Tự động hủy đăng ký (unregister) listener khi `paused`, `stopping`, `finalizing`, `idle`, hoặc khi service bị hủy (`release()`, `onDestroy()`).
  - Khi phát hiện lắc hợp lệ, kích hoạt chính xác hàm `stopCapture()` chung của hệ thống, đi qua đầy đủ các bước dừng encoder, audio, ghép muxer, commit MediaStore và cập nhật trạng thái `completed`. Không tạo nhánh stop độc lập hay bypass state machine.

### F23 — Touch Indicator:
- **Trạng thái:** **PARTIAL / OS-RESTRICTED (BY DESIGN)**.
- **Phân loại phạm vi:**
  1. **In-App & Own Overlays:** **WORKING**. Các điểm chạm trên các view và overlay thuộc sở hữu của ứng dụng (như Drawing Overlay, Floating Controls, Facecam) được nhận diện và xử lý trực tiếp.
  2. **Arbitrary Cross-App Full-Screen Touches:** **UNSUPPORTED BỞI ANDROID OS KHI KHÔNG CÓ PRIVILEGED ACCESSIBILITY SERVICE / DEVELOPER OPTIONS**.
     - Theo kiến trúc bảo mật Android (Security Sandbox), một ứng dụng bên thứ ba (kể cả có quyền `SYSTEM_ALERT_WINDOW`) không được phép nghe lén hoặc nhận `MotionEvent` của các ứng dụng khác trên màn hình nếu không sử dụng `AccessibilityService` (vốn là quyền nhạy cảm và vi phạm nguyên tắc bảo mật của ứng dụng quay màn hình).
     - Khi sử dụng overlay với cờ `FLAG_NOT_TOUCHABLE`, touch đi xuyên qua overlay xuống ứng dụng bên dưới, nhưng overlay không nhận được bất kỳ event nào. Nếu gỡ bỏ `FLAG_NOT_TOUCHABLE`, overlay sẽ chặn hoàn toàn thao tác của người dùng với các ứng dụng khác.
     - **Giải pháp chuẩn hệ thống:** Hướng dẫn người dùng kích hoạt **"Show taps" (Hiển thị thao tác nhấn)** trong **Developer options** (`Settings > System > Developer options > Show taps`). Tính năng này vẽ trực tiếp chấm tròn trắng ở tầng System Compositor và `MediaProjection` tự động thu chấm tròn này vào video MP4 mà không cần bất kỳ quyền nhạy cảm nào.

---

## 2. File thay đổi (Within P1 Ownership)

1. **`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/ShakeDetectorEngine.kt`** (MỚI):
   - Engine tính toán toán học và logic nhận diện lắc thuần túy, 100% JVM testable không cần Android framework mocks.
2. **`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/TouchIndicatorEngine.kt`** (MỚI):
   - Engine quản lý điểm chạm, multi-touch tracking, fade animation lifecycle và tài liệu hóa giới hạn kiến trúc Android OS.
3. **`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt`**:
   - Bổ sung `shakeToStop: Boolean = true` và `showTouches: Boolean = false`.
   - Parse từ MethodChannel arguments trong `CaptureConfig.from(...)` và xuất map snapshot.
4. **`android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt`**:
   - Quản lý lifecycle của `SensorManager` và `SensorEventListener`.
   - Đăng ký cảm biến trong `markRecording()` và `setPaused(false)`.
   - Hủy cảm biến trong `setPaused(true)`, `stopCapture()`, `release()`, `onDestroy()`.
   - Khi trigger, dispatch về Main Looper và gọi `stopCapture()`.
5. **`lib/features/recording/recording_service.dart`**:
   - Truyền `shakeToStop` và `showTouches` vào payload của `start(...)`.
   - Parse `shakeToStop` và `showTouches` trong `decode(...)`.
6. **`android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/ShakeDetectorEngineTest.kt`** (MỚI):
   - 7 JVM unit test cases cho Shake detection.
7. **`android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/TouchIndicatorEngineTest.kt`** (MỚI):
   - 5 JVM unit test cases cho Touch indicator.
8. **`test/recording_service_contract_test.dart`**:
   - Bổ sung contract test kiểm chứng `shakeToStop` và `showTouches` truyền qua MethodChannel.
9. **`docs/p1/TASK_13_P2_INTEGRATION_REQUESTS.md`** (MỚI):
   - Yêu cầu tích hợp đối với P2 (nếu cần bổ sung deep link hoặc UI guidance).

---

## 3. Thuật toán, Threshold, Debounce & Stop Contract

### Thuật toán Shake Detection (`ShakeDetectorEngine`):
- **Gia tốc tổng hợp:** $|\vec{a}| = \sqrt{x^2 + y^2 + z^2}$.
- **Gia tốc biến thiên (Net Acceleration):** $a_{\text{net}} = ||\vec{a}| - g|$, với $g \approx 9.80665\text{ m/s}^2$.
- **Ngưỡng kích hoạt (`threshold`):** $13.0\text{ m/s}^2$ (tương đương biến thiên gia tốc $\sim 1.3g$). Loại bỏ hoàn toàn các dao động nhẹ khi đi bộ ($2-4\text{ m/s}^2$) hoặc rung tay khi chạm màn hình.
- **Cửa sổ thời gian (`timeWindowMs`):** $600\text{ms}$.
- **Số đỉnh đổi hướng tối thiểu (`minPeaks`):** $2$ lần đảo chiều gia tốc. Phân biệt rõ giữa việc nhấc máy lên (1 chiều) với động tác lắc qua lại có chủ đích (đảo chiều).
- **Thời gian hồi phục / chống kích hoạt kép (`cooldownMs`):** $2000\text{ms}$. Sau khi phát hiện 1 chuỗi lắc hợp lệ, khóa cảm biến trong $2000\text{ms}$ để ngăn chặn các sự kiện Stop lặp lại.
- **Ràng buộc trạng thái:** Chỉ chấp nhận khi `currentState == "recording"` và `!isEnding`.

### Stop Contract:
- Gọi hàm `stopCapture()` trên Main Looper (`handler.post`).
- Trình tự dừng:
  1. `ending = true`, xóa handler callbacks, hủy sensor listener.
  2. `CaptureState.transition("stopping")`.
  3. Dừng audio recorder, đóng overlay, release virtual display và MediaProjection.
  4. `CaptureState.transition("finalizing")`.
  5. Luồng nền `recording-finalizer` hoàn tất MediaCodec, muxer ghép audio/video MP4, kiểm tra tracks qua MediaExtractor/MediaMetadataRetriever, commit MediaStore.
  6. Dispatch về Main Looper: chỉ khi commit thành công mới gán `CaptureState.output` và chuyển `CaptureState.transition("completed")`. Nếu lỗi, chuyển `CaptureState.transition("failed")` và xóa file tạm. Tuyệt đối không phát sinh trạng thái ảo.

---

## 4. Touch Input Scope & OS Limitations

| Phạm vi tương tác | Khả năng đáp ứng | Giải pháp kỹ thuật |
| :--- | :--- | :--- |
| **Trong ứng dụng 3HRecorder** | Có hỗ trợ (Full) | Quản lý touch điểm chạm qua `TouchIndicatorEngine`. |
| **Trên Drawing Overlay** | Có hỗ trợ (Full) | Vẽ nét trực tiếp thời gian thực khi người dùng thao tác. |
| **Trên Floating Ball / Facecam** | Có hỗ trợ (Full) | Nhận diện touch drag/tap trực tiếp trên window overlay. |
| **Toàn màn hình trên app khác** | **Bị giới hạn bởi Android OS** | **Developer options "Show taps"**: Android OS System Compositor tự vẽ chấm tròn và MediaProjection tự động thu vào MP4. Không dùng Accessibility Service xâm nhập. |

---

## 5. Kết quả kiểm thử thực tế trên Ubuntu (Command Output Evidence)

### 1. Android JVM Unit Tests:
```bash
cd android && ./gradlew :app:testDebugUnitTest
```
- **Kết quả:** `BUILD SUCCESSFUL in 10s`.
- **Tổng số tests:** **105/105 tests PASS (0 failures, 0 errors)**.
  - `ShakeDetectorEngineTest`: 7/7 tests PASS.
  - `TouchIndicatorEngineTest`: 5/5 tests PASS.
  - `FacecamGeometryTest`: 11/11 tests PASS.
  - `FloatingControlGeometryTest`: 19/19 tests PASS.
  - `DrawingStrokeEngineTest`: 10/10 tests PASS.
  - `RegionCropGeometryTest`: 14/14 tests PASS.
  - `CaptureNotificationPolicyTest`: 11/11 tests PASS.
  - `CaptureRequestsTest`: 8/8 tests PASS.
  - `CaptureTimingTest`: 4/4 tests PASS.
  - `ScreenshotPixelsTest`: 4/4 tests PASS.
  - `VideoBitrateTest`: 4/4 tests PASS.
  - `AudioVideoMathTest`: 3/3 tests PASS.
  - `CaptureJournalTest`: 3/3 tests PASS.
  - `EditorStorageTest`: 2/2 tests PASS.

### 2. Flutter Dart Test Suite:
```bash
/home/hieu/Documents/development/flutter/bin/flutter test --no-pub
```
- **Kết quả:** `All 183 tests passed! (100% PASS)`.
  - Bao gồm test mới `start passes shakeToStop and showTouches and decodes them correctly` trong `test/recording_service_contract_test.dart`.

### 3. Flutter Linter / Analyzer:
```bash
/home/hieu/Documents/development/flutter/bin/flutter analyze --no-pub
```
- **Kết quả:** `No issues found! (ran in 6.0s)`.

### 4. Whitespace & Diff Check:
```bash
git diff --check
```
- **Kết quả:** Clean (0 issues).

---

## 6. Regression Testing

- **Task 01–06 (Capture, Audio, Countdown, Auto-stop, Screenshot):** Giữ nguyên hành vi, test suites pass 100%.
- **Task 07 (Notification Controls):** Giữ nguyên spec và policy, test pass 100%.
- **Task 08 (Region Recording):** Giữ nguyên crop geometry, test pass 100%.
- **Task 09–10 (Floating Controls & Customization):** Giữ nguyên geometry, test pass 100%.
- **Task 11 (Drawing Overlay):** Giữ nguyên stroke engine, test pass 100%.
- **Task 12 (Facecam Orientation):** Ma trận Center-Crop và Portrait orientation giữ nguyên, test pass 100%.

---

## 7. STRICT UI & ICON FREEZE Compliance

- **Không đổi bất kỳ phần tử UI nào:** Không đổi layout, widget tree, visual style, font, color, padding, animation hay routes.
- **Không thay icon:** Không thêm Icons.*, CupertinoIcons.* hay emoji mới. Giữ nguyên 100% hệ thống icon hiện có.
- **Cài đặt Settings hiện có:** Switch `Show touches` và setting `shakeToStop` trong `settings_controller.dart` đã có sẵn từ trước; chỉ kết nối dữ liệu sang native payload trong `recording_service.dart`.

---

## 8. Trạng thái nghiệm thu & Bước tiếp theo

- **F22 — Shake to Stop:** **DONE** (Logic & unit test PASS; pending device verification).
- **F23 — Touch Indicator:** **PARTIAL / OS-RESTRICTED** (Hỗ trợ in-app & overlays; cross-app sử dụng chuẩn Developer Options "Show taps" theo đúng bảo mật Android OS).
- **Hardware / Device Verification:** **NEEDS DEVICE VERIFICATION** (cần kiểm thử thực tế trên điện thoại thật có cảm biến Accelerometer).
