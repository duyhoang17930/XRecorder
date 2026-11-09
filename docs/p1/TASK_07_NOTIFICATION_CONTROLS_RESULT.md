# Task 07 — Notification Controls F14 Result

Ngày: 2026-11-08  
Nhánh: `feature/capture-live`  
Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION** (Toàn bộ logic native policy và state machine đã PASS host JVM tests & Flutter tests; thao tác trực tiếp trên Android notification shade cần thiết bị thực tế để nghiệm thu cuối).

---

## 1. Tóm tắt kết quả (Summary)

- **Mục tiêu:** Hoàn thiện điều khiển Recording từ thanh thông báo Android (F14 Notification Controls): Pause, Resume, Stop, Countdown Cancel; đảm bảo idempotency, loại bỏ hoàn toàn stale actions khi dừng/lưu file, và cách ly chức năng chụp màn hình (không hứa screenshot đồng thời khi engine chưa hỗ trợ).
- **Phạm vi kiểm thử:** Chạy kiểm thử hoàn toàn trên môi trường máy chủ cục bộ (Ubuntu), **không dùng điện thoại thật, adb, emulator hay instrumentation**.
- **Chỉ số kiểm thử:**
  - **40/40 native JVM unit tests PASS** (gồm 11 tests mới cho `CaptureNotificationPolicyTest` và 29 tests hồi quy cho 7 test suites native cũ).
  - **32/32 Flutter Dart unit/contract/controller tests PASS** (0 regressions).
  - **`flutter analyze --no-pub`:** PASS (No issues found!).
  - **`git diff --check`:** PASS (Không có lỗi khoảng trắng hoặc conflict).
- **Tuân thủ quy tắc:**
  - **UI & Icon Freeze:** Giữ nguyên 100% Flutter widget tree, layout, theme, icon và router; không thêm icon lạ, không sửa UI của P2/P3.
  - **P1 Ownership:** Chỉ thêm/chỉnh sửa file trong phạm vi P1: `CaptureNotificationPolicy.kt`, `CaptureRequests.kt`, `CaptureService.kt`, và test suite `CaptureNotificationPolicyTest.kt`. Không can thiệp `AndroidManifest.xml` hay file ngoài P1.

---

## 2. Chi tiết thay đổi (Implementation Before vs After)

| Thành phần | Trước khi sửa (Before) | Sau khi sửa (After) | Đánh giá / Ghi chú |
|---|---|---|---|
| **Chính sách Notification (Policy)** | Logic phân tán trực tiếp trong `CaptureService.kt`, phụ thuộc vào `android.jar`, khó kiểm thử đơn vị độc lập. | Tách module `CaptureNotificationPolicy.kt` thuần Kotlin: định nghĩa rõ `NotificationSpec`, `ActionSpec`, ánh xạ trạng thái và hàm kiểm tra `canAcceptAction`. | **Tối ưu kiến trúc**: Cho phép kiểm thử 100% các nhánh chuyển trạng thái và intent guards trên host JVM. |
| **PendingIntent Request Codes** | Dùng chung requestCode 3 cho cả `PAUSE` và `RESUME`. | Phân định rõ ràng từng requestCode: `1: STOP`, `2: OPEN`, `3: PAUSE`, `4: RESUME`, `5: VISIBILITY`. Cờ cố định `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE`. | **Chống xung đột Intent**: Tránh tình trạng cache intent hoặc ghi đè hành động sai trên Android 12+. |
| **Xử lý Countdown** | `countdown()` chỉ gọi `notify()` cập nhật thông báo khi là `screenshot`. Với video, thông báo giữ nguyên "Preparing screen recording" và nút "Stop". | Cập nhật thông báo sau mỗi giây đếm ngược cho cả video và screenshot. Tiêu đề hiển thị `"Recording in Xs"` (hoặc `"Screenshot in Xs"`), nút hành động là `"Cancel"` (dẫn tới hủy phiên an toàn về `idle`). | **Trực quan & Nhất quán**: Người dùng theo dõi được đếm ngược trên thanh thông báo và có thể hủy trước khi encoder khởi chạy. |
| **Loại bỏ Stale Actions khi Stopping/Finalizing** | Khi gọi `stopCapture()`, trạng thái chuyển sang `stopping` rồi `finalizing` nhưng không cập nhật thông báo. Các nút Pause/Resume/Stop vẫn hiển thị trên shade trong lúc file MP4 đang được mux/commit. | Ngay khi vào `stopCapture()`, gọi `notify()` với spec mới: Tiêu đề `"Saving recording"`, văn bản `"Processing and saving video..."`, danh sách actions **rỗng** (loại bỏ hoàn toàn các nút bấm). | **Idempotent & Stale-Safe**: Ngăn chặn người dùng bấm liên tiếp hoặc kích hoạt hành động khi phiên quay đã kết thúc. |
| **Xử lý Intent đến (`onStartCommand`)** | Chỉ so sánh chuỗi `sessionId == CaptureState.id`, chưa chặn triệt để khi `ending == true` hoặc trạng thái không hợp lệ. | Sử dụng `CaptureNotificationPolicy.canAcceptAction(...)`: kiểm tra quyền sở hữu phiên (`CaptureRequests.owns`), cờ `ending`, tính bận `busy`, và trạng thái chính xác (`recording` cho PAUSE, `paused` cho RESUME). | **Bảo vệ State Machine**: Double-tap hoặc intent muộn từ phiên cũ bị loại bỏ an toàn (no-op). |
| **Chụp màn hình đồng thời (Screenshot Isolation)** | Không có action screenshot trong thanh thông báo video recording. | **Giữ nguyên không thêm**: Tiếp tục tuân thủ báo cáo Task 06 (engine dùng single-use projection token, không hỗ trợ chụp đồng thời khi đang quay). Không hứa hẹn action screenshot trên thông báo video. | Độc lập hoàn toàn với phiên quay video. |
| **Tần suất cảnh báo (Alert Spam)** | Thông báo video không đặt `setOnlyAlertOnce(true)`. | Bổ sung `.setOnlyAlertOnce(true)` cho toàn bộ các cập nhật thông báo tiến trình/ghi hình. | Tránh rung/chuông lặp lại mỗi khi cập nhật đếm ngược hoặc đổi trạng thái. |

---

## 3. Bằng chứng mã nguồn (Code Evidence)

### 3.1. `CaptureNotificationPolicy.kt`
- Định nghĩa phân giải nội dung thông báo theo trạng thái:
```kotlin
fun resolve(...): NotificationSpec {
    // Screenshot: đếm ngược hiển thị Cancel, finalizing hiển thị Saving screenshot (không action)
    // Video:
    // - "countdown": Title "Recording in ${countdownRemaining}s", Action: Cancel (STOP)
    // - "recording": Title "Screen recording", Actions: Pause, (Show/Hide controls), Stop
    // - "paused": Title "Recording paused", Actions: Resume, (Show/Hide controls), Stop
    // - "stopping", "finalizing": Title "Saving recording", Actions: EMPTY (không có nút bấm)
}
```
- Bộ lọc nhận diện Intent hợp lệ:
```kotlin
fun canAcceptAction(...): Boolean {
    if (action == null) return false
    val ownsSession = CaptureRequests.owns(commandSessionId, currentSessionId)
    return when (action) {
        CaptureService.PAUSE -> ownsSession && !ending && state == "recording"
        CaptureService.RESUME -> ownsSession && !ending && state == "paused"
        CaptureService.STOP -> (ownsSession && busy && !ending) || (!busy && !started)
        CaptureService.SHOW_CONTROLS, CaptureService.HIDE_CONTROLS ->
            ownsSession && !ending && state in listOf("recording", "paused")
        else -> false
    }
}
```

### 3.2. Cập nhật `CaptureService.kt`
- Cập nhật thông báo ngay khi bắt đầu dừng phiên:
```kotlin
if (CaptureState.state == "recording") CaptureState.elapsed += SystemClock.elapsedRealtime() - CaptureState.activeStart
CaptureState.transition("stopping")
updateControls()
getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(false))
```
- Cập nhật thông báo trong từng nhịp đếm ngược:
```kotlin
if (remainingMs == 0L) { startEncoder(); return }
getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(false))
handler.postDelayed({ countdown() }, minOf(1000L, remainingMs))
```

---

## 4. Kết quả kiểm thử cục bộ (Local Test Results)

### 4.1. JVM Unit Tests (Android / Kotlin)
Lệnh: `cd android && ./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'`
Kết quả: **BUILD SUCCESSFUL, 40 tests PASS, 0 failures, 0 errors** across 8 test suites:
1. `CaptureNotificationPolicyTest`: **11 tests PASS**
   - `resolveRecordingShowsPauseAndStopActions`: PASS
   - `resolveRecordingWithOverlaysShowsVisibilityToggle`: PASS
   - `resolvePausedShowsResumeAndStopActions`: PASS
   - `resolveCountdownShowsSecondsAndCancelAction`: PASS
   - `resolveStartingShowsPreparingAndCancelAction`: PASS
   - `resolveStoppingAndFinalizingHidesAllActionsToPreventStaleClicks`: PASS
   - `resolveScreenshotStates`: PASS
   - `canAcceptActionValidatesPauseTransitions`: PASS
   - `canAcceptActionValidatesResumeTransitions`: PASS
   - `canAcceptActionValidatesStopTransitions`: PASS
   - `canAcceptActionRejectsUnknownOrNullActions`: PASS
2. `CaptureRequestsTest`: **8 tests PASS**
3. `CaptureTimingTest`: **4 tests PASS**
4. `CaptureJournalTest`: **3 tests PASS**
5. `FloatingControlGeometryTest`: **3 tests PASS**
6. `ScreenshotPixelsTest`: **4 tests PASS**
7. `VideoBitrateTest`: **4 tests PASS**
8. `AudioVideoMathTest`: **3 tests PASS**

### 4.2. Flutter Dart Unit & Contract Tests
Lệnh: `flutter test --no-pub test/recording_service_contract_test.dart test/recording_replay_test.dart test/recording_cancel_semantics_test.dart test/capture_library_finder_test.dart test/recording_controller_test.dart test/recording_setup_sheet_test.dart`
Kết quả: **32 tests PASS, 0 failures**
- Contract & Controller: Bảo toàn logic ghi nhận Saved event chỉ sau MediaStore commit, không tạo double session, không phát Saved giả khi Cancel/Stop lỗi.
- Settings & Setup Sheet: Bảo toàn bố cục và ràng buộc khả năng phần cứng (320dp, 360dp, 411dp).

### 4.3. Static Analysis
- `flutter analyze --no-pub`: **No issues found!** (ran in 7.1s)
- `git diff --check`: **Clean** (No trailing whitespace, no merge conflicts).

---

## 5. Xác nhận UI Freeze & Icon Consistency

- **UI Widget Tree:** Không thay đổi bất kỳ file UI nào trong `lib/` (không sửa `studio_create_sheet.dart`, `recording_setup_sheet.dart`, `help_screen.dart`, router, hay theme).
- **Icons:** Giữ nguyên các drawable hệ thống hiện hành (`android.R.drawable.presence_video_online` và `android.R.drawable.ic_menu_camera`). Không tự ý thêm icon bên ngoài hoặc emoji.
- **Yêu cầu P2:** Đã lập yêu cầu tích hợp không chặn (Non-blocking Integration Request) tại [`docs/p1/TASK_07_P2_INTEGRATION_REQUESTS.md`](TASK_07_P2_INTEGRATION_REQUESTS.md) để P2 thiết kế bộ monochrome drawables chuẩn cho thanh trạng thái nếu cần nhận diện riêng.

---

## 6. Hạn chế & Hạng mục cần kiểm chứng trên thiết bị (NEEDS DEVICE VERIFICATION)

Các nội dung sau không thể kiểm chứng trực tiếp trên máy chủ Ubuntu do chính sách cấm dùng thiết bị thật/ADB:
1. Hiển thị thực tế của thông báo trong Android Notification Shade trên các phiên bản Android khác nhau (đặc biệt là giao diện mở rộng/thu gọn của Notification Actions trên Android 11, 12, 13, 14).
2. Tác động của quyền `POST_NOTIFICATIONS` trên Android 13+ khi người dùng từ chối quyền thông báo (Foreground Service vẫn chạy nhưng thông báo có thể bị ẩn trong Notification Drawer).
3. Thao tác chạm nhanh nhiều lần liên tục (rapid double-tap) trực tiếp trên giao diện cảm ứng của notification shade phần cứng.
4. Tương tác khi thiết bị ở chế độ Always-On Display (AOD) hoặc màn hình khóa (Lockscreen).
