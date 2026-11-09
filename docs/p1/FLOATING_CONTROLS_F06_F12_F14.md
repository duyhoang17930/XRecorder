# P1 — Floating Recording Controls (F06 / F12 / F14)

> Cập nhật sau task Compact/Black Rectangle: phần mô tả tự show overlay và dùng FLAG_SECURE dưới đây là lịch sử implementation cũ. Bản hiện tại bỏ FLAG_SECURE, dùng notification mặc định và chỉ hiện thanh 1 hàng khi người dùng chọn “Show controls in video”. Xem [báo cáo sửa output](FLOATING_CONTROLS_COMPACT_OUTPUT.md) cho kết quả và giới hạn mới nhất.

Ngày: 2026-11-07. Branch `feature/capture-live`. **PARTIAL: code và host checks hoàn tất; runtime overlay chưa xác minh.**

## Baseline và phạm vi

- Working tree ban đầu đã có các thay đổi Task 00 và Recording Settings; giữ nguyên, không reset/stage/commit/push.
- Engine có MediaProjection/foreground service, active elapsed time bằng elapsedRealtime, pause/resume, notification actions và finalize/validate/commit MP4. WindowManager hiện có chỉ phục vụ Facecam.
- Chỉ thay đổi native `recording/`, bổ sung capture tests và tài liệu này. Không sửa Flutter UI/controller, native encoder/muxer, MainActivity, Manifest, Gradle, pubspec hoặc module P2/P3 trong task này.

## File thay đổi trong task này

- `recording/FloatingRecordingControls.kt` — mới: một window nhỏ, dark/orange #FF7847, timer, Pause/Resume/Stop, collapse/bubble, drag/clamp/snap.
- `recording/FloatingControlGeometry.kt` — mới: tính elapsed/HH:MM:SS và giới hạn vị trí thuần Kotlin để kiểm thử.
- `recording/CaptureService.kt` — gắn window vào service/tick có sẵn; cleanup và thông báo kết quả thật.
- `recording/CaptureState.kt` — dùng một getter elapsedActiveMs cho snapshot và overlay, giữ schema event.
- `recording/CaptureBridge.kt` — flow quyền overlay tùy chọn trước projection consent đối với video không dùng Facecam.
- `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/FloatingControlGeometryTest.kt` — mới: 3 unit tests.
- `integration_test/floating_controls_test.dart` — mới: kiểm chứng native session/MP4, có host thao tác nút nổi và consent.
- Tài liệu này.

## Hành vi và contract

- Sau khi engine xác nhận recording, tick service 250ms có sẵn hiển thị/cập nhật controls. Hiển thị cả trong app lẫn khi chuyển Home/app khác nếu Android cho phép. Screenshot không tạo controls hoặc xin quyền controls.
- Window có owner là service, không giữ Activity/Flutter context, không tạo session/controller/timer thứ hai. Activity recreation không tự tạo window mới. Một panel mỗi service; show có guard attached.
- HH:MM:SS dùng elapsed tích lũy + elapsedRealtime hiện tại khi recording; paused chỉ dùng elapsed tích lũy. Không reset ở Flutter refresh/recreate. File duration được kiểm tra riêng bởi finalizer, không giả đồng nhất với timer.
- Pause/Resume gọi trực tiếp setPaused trên cùng service và ID đã capture; chỉ cập nhật UI sau chuyển state native. Không tạo projection/file mới.
- Stop dùng stopCapture hiện tại; ending chặn lặp, disable nút ngay khi stopping; hiển thị Saving nhỏ tới khi finalize kết thúc. Bubble vẫn có thể mở lại, notification vẫn tồn tại.
- Saved Toast/event chỉ sau metadata validation và MediaOutput.commit thành công. Không thêm callback Saved riêng; vẫn CaptureState.completed → CaptureController.onSaved → media.refresh. Finalizer failure báo lỗi thật, không Saved. Failure trước finalize cũng báo lỗi và cleanup.
- Release/cancel/failure/onDestroy và finalizer terminal đều đóng window. Đổi kích thước/rotation clamp trong vùng khả dụng; kéo timer/bubble, thả để snap mép. Chỉ vùng panel nhận touch; không chiếm focus hoặc dựng một lớp full-screen để bắt touch.

## Quyền và P2 integration

- Manifest đã có SYSTEM_ALERT_WINDOW và service mediaProjection/microphone/camera; MainActivity đã forward mọi activity result sang CaptureBridge. **Không cần thay P2 registration/permission/dependency.**
- API 26+: TYPE_APPLICATION_OVERLAY; API 24–25 dùng TYPE_PHONE theo minSdk hiện tại. Chỉ add window nếu Settings.canDrawOverlays trả true.
- Video không Facecam: nếu thiếu quyền, mở ACTION_MANAGE_OVERLAY_PERMISSION; khi Back/deny vẫn đi tới MediaProjection consent và recording với notification controls. ActivityNotFound/SecurityException cũng fallback. Không tự cấp quyền bằng appops hoặc bỏ qua consent.
- Facecam giữ nguyên yêu cầu quyền overlay/camera bắt buộc của implementation cũ. Nếu từ chối quyền Facecam, cần tắt Facecam để quay không camera; task không âm thầm đổi config người dùng.
- Quyền notification giữ flow hiện có; nếu người dùng từ chối cả notification và overlay, không bảo đảm có nút nổi/notification ngoài app. Có thể quay lại app để điều khiển.
- Không tái sử dụng projection token hoặc khởi động service từ background tùy tiện; giữ flow consent/foreground service hiện tại. Theo [Android MediaProjection](https://developer.android.com/media/grow/media-projection), mỗi phiên projection cần consent riêng và token chỉ dùng một lần để tạo virtual display.

## Overlay trong output và giới hạn nền tảng

- Dùng FLAG_SECURE trên window controls để yêu cầu Android bảo vệ nội dung window khỏi capture, theo [WindowManager.LayoutParams](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#FLAG_SECURE). Đây không phải cơ chế vẽ đè/crop để giả giấu overlay.
- Chưa kiểm tra video/pixels thực trên thiết bị: không tuyên bố controls chắc chắn biến mất hoàn hảo hoặc vùng nền phía dưới được khôi phục trên mọi OEM/API. Cần kiểm tra full-display MP4; nếu có vùng che/blank, ghi nhận hạn chế compositor thay vì bypass.
- TYPE_APPLICATION_OVERLAY nằm dưới status bar/IME; Android có quyền thay vị trí/visibility. App/system có thể chặn overlay ở vùng nhạy cảm. Notification là đường dự phòng, không dùng accessibility hoặc API riêng để vượt hạn chế.
- Quyền được kiểm tra trước khi show; nếu bị thu hồi trong phiên, đóng controls và dùng notification. Grant mới sau khi đã fallback cần phiên quay tiếp theo để show lại controls.

## Bằng chứng kiểm thử

| Kiểm tra | Kết quả |
| --- | --- |
| Kotlin compile debug | PASS: `./gradlew --offline :app:compileDebugKotlin` |
| Debug app sau test | PASS: `flutter build apk --debug --no-pub --target lib/main.dart`; cài lại APK entrypoint bình thường bằng `adb install -r`, giữ app data, không để entrypoint test trên thiết bị |
| Timer/format/drag geometry | PASS: `./gradlew --offline :app:testDebugUnitTest --tests '*FloatingControlGeometryTest'` — 3 tests, 0 failures/errors |
| Capture Saved/Cancel/Failure/replay | PASS: `flutter test --no-pub test/recording_controller_test.dart` — 6 tests |
| Integration test analysis/format | PASS: `dart format integration_test/floating_controls_test.dart`; `flutter analyze --no-pub integration_test/floating_controls_test.dart` |
| Device attempt | Debug APK build/install thành công trên thiết bị model 2602DPT53G, API 36; log tới FLOAT_TEST_CONSENT. Quyền overlay đang ignore, chưa có consent chạy capture. Người dùng chưa tiện thao tác thiết bị; dừng test và force-stop app test, không cấp quyền hộ. Test bị interrupted/did not complete, có Flutter listener cleanup error lúc interrupt; đây không phải PASS runtime. |
| Native Home/timer/Pause/Resume/Stop/MP4 | NOT VERIFIED — cần hoàn tất consent và thao tác thiết bị |
| Collapse/drag/snap/pass-through/rotation | Unit geometry PASS, interaction thực NOT VERIFIED |
| Denied permission → notification | Code đã nối fallback; runtime NOT VERIFIED |
| Activity recreation, repeated Stop, failure injection, leak và output pixels | NOT VERIFIED trên thiết bị |

Integration test mặc định chờ host cấp quyền rồi theo marker: FLOAT_TEST_HOME_AND_PAUSE → Home và nút Pause; FLOAT_TEST_RESUME → Resume; FLOAT_TEST_STOP → Stop. Test kiểm tra cùng ID, timer đứng khi pause, URI/file metadata thật, duration so với elapsed (sai lệch <2.5s), Saved một lần và repeated Stop. Với `--dart-define=EXPECT_FLOATING_OVERLAY=false`, dùng lệnh bridge để kiểm tra fallback sau khi host từ chối overlay và chấp nhận projection; không xem đó là bằng chứng thao tác notification UI.

PASS: `git diff --check` và kiểm tra whitespace từng file mới; diff của task này chỉ thuộc native recording, capture tests và tài liệu P1. Không chạy release build hoặc toàn bộ test repo. Các lần chạy cần consent còn thiếu không được tính là hoàn thành nghiệm thu.
