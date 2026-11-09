# P1 — Compact controls và điều tra vùng đen trong MP4

Ngày rà soát lại: **2026-11-08**. **PARTIAL**: workspace đã có bản sửa compact/notification fallback và baseline tái hiện vùng đen từ 2026-11-07. Lần rà soát này giữ nguyên bản sửa native hiện có; không ghi đè các diff của task trước. Chưa có MP4 sau sửa: `adb devices -l` hiện trả danh sách rỗng. Việc từ chối cài debug bên dưới là kết quả lịch sử ngày 2026-11-07, không phải kết quả chạy hôm nay.

## Rà soát lại ngày 2026-11-08

- Đã đọc lại `FloatingRecordingControls`, `FloatingControlGeometry`, `CaptureService`, `CaptureState`, `FacecamOverlay`, `VideoEncoder` và các harness P1 liên quan. Không sửa Dart, Manifest, MainActivity hoặc UI chung.
- Đã xem trực tiếp `before-500.png`: rectangle nội vùng che nền xanh, khác với hai dải letterbox sát mép. Số đo/frame statistics bên dưới là artifact từ lần chạy trước, không phải MP4 mới hôm nay. Chưa có video tham chiếu mới của người dùng.
- Code hiện tại: WRAP_CONTENT × WRAP_CONTENT, TYPE_APPLICATION_OVERLAY (26+)/TYPE_PHONE (24–25), TOP|LEFT, PixelFormat.TRANSLUCENT, NOT_FOCUSABLE|NOT_TOUCH_MODAL; không có FLAG_SECURE. Root/panel là LinearLayout với TextView/ImageButton, không có SurfaceView/TextureView, không có lớp nền toàn màn hình. TextureView duy nhất trong module thuộc Facecam riêng.
- Show/Hide controls chỉ add/remove WindowManager view; không thay VirtualDisplay, encoder surface hoặc cấu hình ghi. Timer lấy `CaptureState.elapsedActiveMs` qua tick service hiện có; icon đổi sau `setPaused` native thành công. Stop giữ controls ở trạng thái Saving cho tới khi finalize/commit xong rồi gỡ.
- Kích thước **ước tính theo layout**, chưa đo thiết bị: expanded khoảng 200×48dp (96dp timer + 2×48dp nút + 8dp padding), bubble 48×48dp; font lớn có thể tăng chiều rộng. Chạm timer để thu gọn, chạm bubble để mở, kéo timer/bubble để di chuyển.
- Notification là mặc định; chỉ chọn “Show controls in video” mới chấp nhận controls có thể xuất hiện trong MP4. Không áp dụng thủ thuật secure/crop/pixel đen. Việc bỏ secure chỉ áp dụng cửa sổ controls chứa trạng thái/timer/nút, không thay chính sách bảo mật các cửa sổ khác.
- **A/B/C/D/E: NOT VERIFIED trong lần này** vì không có thiết bị ADB. Không suy từ unit test/build sang việc MP4 đã hết lỗi. Chưa đủ đối chứng để khẳng định FLAG_SECURE là nguyên nhân duy nhất hoặc xác nhận acceptance 6/7.
- **PASS hôm nay:** `./gradlew --offline :app:testDebugUnitTest --tests '*recording.*'` (BUILD SUCCESSFUL), gồm **21 tests, 0 failures/errors/skips** trong 6 suites: AudioVideoMath, CaptureRequests, CaptureTiming, FloatingControlGeometry, ScreenshotPixels, VideoBitrate. Đã compile Kotlin debug thành công. `git diff --check` sạch; kiểm tra thêm trailing whitespace của file controls và báo cáo chưa tracked cũng sạch. Không sửa Dart nên không cần chạy lại `flutter analyze` cho thay đổi lần này.
- **PASS build hôm nay:** `./gradlew --offline :app:assembleDebug` — BUILD SUCCESSFUL (2m05s), gồm native build arm64-v8a/armeabi-v7a/x86_64; APK tại `build/app/outputs/apk/debug/app-debug.apk`. Có warning deprecation AGP/Kotlin và warning C++ trong thư viện third-party hiện có; không đổi các module này. Không cài APK vì không có thiết bị kết nối.
- Không cần P2 tích hợp thay đổi Manifest/MainActivity. Không commit/push, reset Git hoặc thay đổi dữ liệu/video trên thiết bị.

## Bằng chứng trước sửa

- Window: WRAP_CONTENT cả hai chiều, TYPE_APPLICATION_OVERLAY (26+), TYPE_PHONE (24–25), TOP|LEFT, TRANSLUCENT, NOT_FOCUSABLE|NOT_TOUCH_MODAL|**SECURE**.
- Controls cũ là view Android thông thường, không có SurfaceView/TextureView. Root nền RGB(24,24,28), padding 8dp ngang/4dp dọc; panel 2 hàng, khoảng **184×104dp**. Không dùng MATCH_PARENT/window toàn màn hình. Facecam có TextureView riêng, không sửa trong task này.
- Show controls không thay VirtualDisplay hoặc encoder surface. Full-display projection vẫn ghi vào video.surface như cũ, không có crop/compositing riêng cho controls.
- Đã build/install baseline và tới OUTPUT_READY. Test Flutter sau đó bị ngắt (`did not complete`/listener cleanup error); không tính bài test này là PASS.
- MP4 baseline vừa tạo `Recording_1794061111476.mp4`: **720×1280, khoảng 5.853s**, giữ nguyên trên thiết bị và sao chép vào `build/verification/p1/compact-controls/before-secure.mp4`. Không đọc/xóa các video người dùng khác để phân tích.
- Trích frame bằng OpenCV ở 0.5s, 2s, 4s. Hai frame đầu có **hình chữ nhật đen nội vùng x=78, y=284, w=277, h=157px**, khớp tỷ lệ panel cũ khoảng 184×104dp. Frame 0.5s có đủ 43,489 pixel gần đen trong rectangle (ngưỡng max RGB <12), trong khi nền màn test là xanh. Đây khác với letterbox sát mép trái 65px/phải 66px xuyên suốt chiều cao. Không sửa các dải letterbox trong task này.
- Xem [frame 0.5s](../../build/verification/p1/compact-controls/before-500.png) và [thống kê](../../build/verification/p1/compact-controls/before-analysis.json). Có bằng chứng mạnh vùng che thuộc secure controls, không phải thiếu toàn bộ frame từ encoder. Chưa có đối chứng sau sửa để khẳng định đã loại lỗi runtime hoàn toàn; video lỗi tham chiếu của người dùng chưa được đính kèm.

## Sửa đúng phạm vi P1

- `recording/FloatingRecordingControls.kt`: bỏ FLAG_SECURE; panel ngang chỉ có trạng thái + HH:MM:SS + Pause/Resume + Stop. Window vẫn WRAP_CONTENT. Timer minWidth 96dp, mỗi nút 48×48dp, padding ngang tổng 8dp: **khoảng 200×48dp ở font scale chuẩn**, có thể rộng hơn khi phóng font. Không còn hàng phụ/collapse button/padding dọc. Bubble **48×48dp**.
- Chạm timer để thu gọn; chạm bubble để mở lại; kéo timer/bubble và thả để snap mép. Pause/Resume/Stop, elapsed getter/tick và cleanup dùng service/session cũ.
- `recording/CaptureService.kt`: mặc định **notification controls**, không tự show overlay chỉ vì đã có quyền. Thêm notification action **“Show controls in video”**: người dùng chấp nhận controls có thể xuất hiện trong MP4 cho chính phiên hiện tại; **“Hide controls”** quay về notification. Các action kiểm tra sessionId/state/ending, không tạo session thứ hai.
- Thêm `integration_test/floating_output_test.dart` để tạo mẫu A/B/C, giữ MP4; cập nhật marker trong `floating_controls_test.dart` và geometry unit test cho kích thước 200dp; cập nhật tài liệu cũ để không tiếp tục khuyên dùng FLAG_SECURE.
- Không sửa CaptureBridge, CaptureState, config/schema, encoder/audio, Facecam, Screenshot, MediaStore commit/Saved contract, Flutter UI, MainActivity/Manifest hoặc file P2/P3 trong task này. Các diff sẵn có từ task trước được giữ nguyên.

## Tác động bảo mật / output

- [FLAG_SECURE](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#FLAG_SECURE) bảo vệ nội dung window khỏi capture/non-secure display; không phải API đảm bảo nền bên dưới window được ghi lại đầy đủ. Việc dùng nó trước đây để giấu controls là không phù hợp, có thể tạo vùng redaction trên thiết bị này.
- Controls chỉ chứa timer/trạng thái/nút; bỏ secure flag không mở capture dữ liệu nhạy cảm trong window này. Không bỏ secure flags của Activity/window nào khác. Người dùng phải chọn rõ “Show controls in video”; quyền SYSTEM_ALERT_WINDOW đơn thuần không được xem là đồng ý đưa controls vào video.
- Không dùng NOT_FOCUSABLE/NOT_TOUCH_MODAL để tuyên bố overlay biến mất khỏi output: chúng chỉ quản lý input. Không gọi API private/privileged, không vẽ pixel đen, không crop hoặc đổi FPS/bitrate/resolution để che lỗi.
- Engine đang dùng full-display capture. [Android MediaProjection](https://developer.android.com/media/grow/media-projection) có app-only sharing ở API 34+, nhưng đổi capture mode sẽ đổi nội dung quay; task này không tự chuyển mode và không khẳng định có API public loại riêng controls khỏi full-display video trên mọi OEM.
- Phương án hiện tại chấp nhận control có thể nhìn thấy trong MP4 khi opt-in. Muốn output không có controls: dùng notification mặc định. Không bảo đảm loại mọi vùng đen từ nội dung DRM/secure của app khác hoặc letterboxing hiện có.

## Kiểm thử và hạn chế thực tế

- **PASS:** `./gradlew --offline :app:testDebugUnitTest --tests '*FloatingControlGeometryTest'` — 3 tests, 0 failures/errors; compile native và clamp/snap mẫu 200dp thành công.
- **PASS:** format và analyze `floating_controls_test.dart`, `floating_output_test.dart`; No issues found. `git diff --check` và whitespace files mới không có lỗi.
- **PASS:** `flutter build apk --debug --no-pub --target lib/main.dart`; APK tại `build/app/outputs/flutter-apk/app-debug.apk`. **Không cài lại** sau khi người dùng chọn chỉ host checks.
- Lần thử A bằng flutter drive: thiết bị API 36 có quyền overlay `allow`, nhưng cài bản mới thất bại với **INSTALL_FAILED_USER_RESTRICTED: Install canceled by user**. Đã dừng runner, không thay setting USB/appops, không vượt consent và không xóa dữ liệu/video. Bản đang cài trên thiết bị chưa được xác nhận là bản sửa; có thể còn entrypoint test baseline. Cần cài APK entrypoint bình thường khi thiết bị cho phép trước khi sử dụng app hằng ngày.
- **A (không overlay 10–15s): NOT VERIFIED sau sửa.**
- **B (overlay + Home + drag + nhiều frame): NOT VERIFIED sau sửa.**
- **C (5s quay / 3s pause / 5s quay): NOT VERIFIED trên thiết bị.** Unit timing không thay thế kiểm tra duration/MP4 thực.
- **D (window/touch/collapse thực): NOT VERIFIED.** Kích thước ở trên tính từ layout code, chưa đo lại bằng dumpsys window.
- **E (permission denied): NOT VERIFIED runtime.** Code chỉ add view khi có quyền, notification Pause/Resume/Stop hiện có là fallback.
- Không yêu cầu P2 tích hợp: Manifest đã có permission/service, bridge registration đã có. Không chạy release build, commit/push hoặc reset Git.

## Cách kiểm tra tiếp trên thiết bị

1. Cài debug APK bình thường khi Android cho phép; không clear data. Mỗi lần test chấp nhận MediaProjection consent qua hệ thống, Facecam Off để cô lập controls.
2. A: quay màn có nhiều màu 12s bằng notification, không chọn Show controls. Kiểm tra không có window controls và giữ MP4.
3. B: quay 15s, chọn **Show controls in video** trong notification, về Home, kéo thanh, chạm timer để collapse rồi mở bubble. Đo expanded window khoảng 200×48dp/bubble 48×48dp bằng dumpsys; kiểm tra thao tác ngoài window. Kiểm tra Hide controls và cleanup sau Stop.
4. C: quay 5s, Pause 3s, Resume 5s rồi Stop (thử cả Stop lúc paused); cùng session ID, timer đứng khi paused, MP4 khoảng 10s với sai lệch encoder hợp lý. Double Stop không thêm output/Saved.
5. E: từ chối overlay qua Android Settings, quay lại app và đồng ý projection; thử notification Pause/Resume/Stop. Không dùng adb appops để cấp quyền hộ.
6. Trích frame tại 0.5/2/5/8/10s bằng OpenCV hoặc ffmpeg, so với nội dung màn hình và vị trí window. Tách letterbox sát mép khỏi rectangle nội vùng. Chỉ đánh dấu hết lỗi sau khi MP4 mới không còn redaction tương ứng controls; controls nhìn thấy khi opt-in là hành vi có chủ ý.

Harness: `flutter drive --driver=test_driver/design_system_driver.dart --target=integration_test/floating_output_test.dart -d DEVICE --dart-define=OUTPUT_SAMPLE=after_no_overlay`; B thêm `--dart-define=OUTPUT_SECONDS=15` và chọn action notification; C thêm `--dart-define=OUTPUT_PAUSE=true`. Mỗi sample phải được host thao tác consent bình thường; harness không giả cấp quyền hoặc xóa media.
