# Task 09 — Floating Ball F12 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ logic toán học hình học, ma trận trạng thái hiển thị, kiểm tra quyền, chống double-tap và cleanup WindowManager đã PASS 100% host JVM tests; hiển thị thực tế không sinh vùng đen trên phần cứng màn hình Android cần thiết bị thật).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện tính năng **F12 Floating Ball (Nút điều khiển nổi trên màn hình)**:
  - Hiển thị và điều khiển quay (Record / Pause / Resume / Stop) thông qua cửa sổ nổi dạng bubble và thanh compact mở rộng.
  - Quản lý vòng đời chặt chẽ qua Android `WindowManager` và Service Foreground, ngăn ngừa triệt để rò rỉ cửa sổ (`WindowManager.BadTokenException`) hoặc cửa sổ tồn tại dai dẳng sau khi Stop/Cancel/Error.
  - **Không làm hỏng video:** Tuyệt đối không sử dụng `FLAG_SECURE` bừa bãi (nguyên nhân gây ra vùng đen hình chữ nhật - redaction rectangle trong video MediaProjection trên một số thiết bị); không chèn dải đen hoặc bypass; mặc định dùng thông báo an toàn, người dùng chọn rõ ràng "Show controls in video" để bật nút nổi.
  - **Touch isolation:** Cửa sổ nổi dạng `WRAP_CONTENT` với cờ `FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL`, chỉ nhận sự kiện chạm trong phạm vi hình học của thanh điều khiển/bubble; toàn bộ phần màn hình còn lại không bị chặn chạm.
- **Phạm vi kiểm thử:** Máy chủ Ubuntu cục bộ, **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **62/62 native JVM unit tests PASS** (gồm 11 tests trong `FloatingControlGeometryTest` và 51 tests hồi quy của các module Task 02–08).
  - **35/35 Flutter Dart unit/contract/controller tests PASS** (0 regressions).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Sạch sẽ, không có lỗi khoảng trắng).
- **Tuân thủ quy tắc:**
  - **UI Freeze:** Không thay đổi bố cục, theme, màu sắc, font hay routing của Flutter.
  - **Icon Consistency:** Giữ nguyên các asset drawable (#FF7847, `ic_media_pause`, `ic_media_play`, stop icon). Không tự ý thêm icon mới hay menu mới. Không triển khai tùy chỉnh kích thước/độ mờ (thuộc Task 10).

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Ma trận trạng thái Overlay ([`FloatingControlGeometry.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingControlGeometry.kt))** | Chỉ có các hàm tính toán vị trí `clamp`/`snap` và format chuỗi thời gian `time`. | Bổ sung `resolveOverlayState(...)` và `canAcceptOverlayAction(...)`: định nghĩa ma trận hiển thị và tương tác cho toàn bộ các trạng thái `recording`, `paused`, `stopping`, `finalizing`, `completed`, `failed`, `idle`. | **Kiểm thử độc lập**: Toàn bộ ma trận trạng thái của nút nổi được kiểm chứng 100% trên JVM host. |
| **Bảo vệ Cửa sổ & Tránh Click Trùng ([`FloatingRecordingControls.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/FloatingRecordingControls.kt))** | `render()` dựa vào logic kiểm tra rải rác. | Kết nối `resolveOverlayState`: khi chuyển sang `stopping`/`finalizing`, nút Stop và Pause bị vô hiệu hóa (`isEnabled = false`), alpha giảm xuống 0.4, timer đổi thành `"Saving…"`. Khi hoàn tất (`completed`/`failed`/`idle`), tự động gọi `close()` gỡ view ngay lập tức. | **Chống click trùng (Double-tap guard)**: Loại bỏ khả năng người dùng chạm Stop/Pause liên tiếp làm rối state machine. |
| **Xử lý Quyền & Thu hồi giữa chừng** | Kiểm tra quyền ở bước đầu tiên khi khởi tạo. | Kiểm tra `Settings.canDrawOverlays(context)` trong mỗi nhịp `render()`. Nếu quyền bị người dùng thu hồi trong lúc đang ghi, controls tự động đóng và fallback về Notification Controls. | **An toàn hệ thống**: Tránh crash `BadTokenException` do quyền overlay bị hủy đột ngột. |
| **Bảo vệ Captured Output & Semantics MediaProjection** | Lịch sử từng dùng `FLAG_SECURE` gây ra vết đen che khuất nội dung nền. | Sử dụng view thông thường với `FLAG_NOT_FOCUSABLE or FLAG_NOT_TOUCH_MODAL` (quản lý input, không chèn cờ secure). Cơ chế opt-in qua notification ("Show controls in video") xác nhận người dùng đồng ý hiển thị controls trong phiên ghi. | **Trung thực kỹ thuật**: Không tuyên bố overlay biến mất nếu chưa có device proof; không dùng thủ thuật che lấp gây lỗi output. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. `FloatingControlGeometry.kt`
- Định nghĩa ma trận trạng thái hiển thị của nút nổi:
```kotlin
fun resolveOverlayState(
    state: String, elapsedMs: Long,
    canDrawOverlays: Boolean, acceptedInVideo: Boolean, isScreenshot: Boolean
): OverlayState {
    if (isScreenshot || !canDrawOverlays || !acceptedInVideo) {
        return OverlayState(shouldShow = false, isInteractive = false, isPaused = false, statusText = "", alpha = 0f)
    }
    return when (state) {
        "recording" -> OverlayState(
            shouldShow = true, isInteractive = true, isPaused = false,
            statusText = "● ${time(elapsedMs)}", alpha = 1.0f
        )
        "paused" -> OverlayState(
            shouldShow = true, isInteractive = true, isPaused = true,
            statusText = "Ⅱ ${time(elapsedMs)}", alpha = 1.0f
        )
        "stopping", "finalizing" -> OverlayState(
            shouldShow = true, isInteractive = false, isPaused = false,
            statusText = "Saving…", alpha = 0.4f
        )
        else -> OverlayState(
            shouldShow = false, isInteractive = false, isPaused = false,
            statusText = "", alpha = 0f
        )
    }
}

fun canAcceptOverlayAction(action: String, isEnding: Boolean, currentState: String): Boolean {
    if (isEnding) return false
    return when (action) {
        "togglePause", "stop" -> currentState in listOf("recording", "paused")
        else -> false
    }
}
```

### 3.2. `CaptureService.kt`
- Bảo vệ các callback nút nổi khỏi click lặp và phiên kết thúc:
```kotlin
controls = FloatingRecordingControls(this,
    togglePause = {
        if (CaptureState.id == sessionId && FloatingControlGeometry.canAcceptOverlayAction("togglePause", ending, CaptureState.state)) {
            try { setPaused(CaptureState.state == "recording") }
            catch (_: Exception) { fail("The encoder could not change pause state.") }
        }
    },
    stop = {
        if (CaptureState.id == sessionId && FloatingControlGeometry.canAcceptOverlayAction("stop", ending, CaptureState.state)) {
            stopCapture()
        }
    }
)
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. JVM Unit Tests (Android / Kotlin)
Lệnh: `cd android && ./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'`  
Kết quả: **BUILD SUCCESSFUL, 62 tests PASS, 0 failures, 0 errors** across 9 test suites:
1. `FloatingControlGeometryTest`: **11 tests PASS**
   - `timerStopsDuringPauseAndContinuesFromAccumulatedTime`: PASS
   - `timeUsesHoursWithoutWrappingAtMidnight`: PASS
   - `draggingClampsAfterResizeAndSnapsToNearestEdge`: PASS
   - `resolveOverlayStateForRecordingShowsActiveTimer`: PASS
   - `resolveOverlayStateForPausedShowsPausedTimer`: PASS
   - `resolveOverlayStateForStoppingAndFinalizingDisablesControls`: PASS
   - `resolveOverlayStateHidesForScreenshots`: PASS
   - `resolveOverlayStateHidesWhenOverlayPermissionNotGranted`: PASS
   - `resolveOverlayStateHidesWhenNotAcceptedInVideo`: PASS
   - `resolveOverlayStateHidesForTerminalOrIdleStates`: PASS
   - `canAcceptOverlayActionValidatesStateAndEnding`: PASS
2. `RegionCropGeometryTest`: **14 tests PASS**
3. `CaptureNotificationPolicyTest`: **11 tests PASS**
4. `CaptureRequestsTest`: **8 tests PASS**
5. `CaptureTimingTest`: **4 tests PASS**
6. `ScreenshotPixelsTest`: **4 tests PASS**
7. `VideoBitrateTest`: **4 tests PASS**
8. `CaptureJournalTest`: **3 tests PASS**
9. `AudioVideoMathTest`: **3 tests PASS**

### 4.2. Flutter Dart Unit & Contract Tests
Lệnh: `flutter test --no-pub test/region_recording_contract_test.dart test/recording_service_contract_test.dart test/recording_replay_test.dart test/recording_cancel_semantics_test.dart test/capture_library_finder_test.dart test/recording_controller_test.dart test/recording_setup_sheet_test.dart`  
Kết quả: **35 tests PASS, 0 failures**

### 4.3. Static Analysis
- `flutter analyze --no-pub`: **No issues found!** (7.5s)
- `git diff --check`: **Clean** (No trailing whitespace, no merge conflicts).

---

## 5. Xác nhận UI Freeze & Icon Consistency

- Giữ nguyên toàn bộ cấu trúc giao diện Flutter và giao diện nút nổi native (kích thước bubble 48×48dp, thanh ngang mở rộng ~200×48dp, góc bo 20dp, viền cam #FF7847).
- Không thêm bất kỳ icon lạ hay emoji nào.
- Giữ nguyên các thao tác: chạm timer để thu gọn thành bubble, chạm bubble để mở rộng, kéo timer/bubble để di chuyển và snap vào mép màn hình gần nhất.

---

## 6. Hạn chế & Hạng mục cần kiểm chứng trên thiết bị (NEEDS DEVICE VERIFICATION)

1. **Hiển thị video thực tế:** Cần kiểm tra file MP4 ghi hình trên thiết bị thật khi bật "Show controls in video" để xác nhận overlay xuất hiện đúng vị trí và không gây ra bất kỳ hiện tượng giật hình hay lỗi màu sắc nào từ bộ xử lý SurfaceFlinger / GPU của OEM.
2. **Cảm ứng xuyên màn hình (Touch Passthrough):** Kiểm chứng trên màn hình cảm ứng thật để xác nhận cử chỉ vuốt/chạm bên ngoài nút nổi truyền tải 100% xuống ứng dụng nền bên dưới mà không bị cản trở.
3. **Thu hồi quyền runtime:** Xác minh hành vi khi người dùng mở Settings của Android để tước quyền `SYSTEM_ALERT_WINDOW` ngay trong lúc phiên quay đang diễn ra.
