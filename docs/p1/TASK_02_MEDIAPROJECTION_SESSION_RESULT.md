# Task 02 — MediaProjection & Session

Trạng thái: **PARTIAL / NEEDS DEVICE VERIFICATION**. Ngày 2026-11-07; branch `feature/capture-live`, giữ nguyên working tree cũ.

- Sửa A01/A02/A03/A08/A10 của Task 01: stale notification Stop không stopSelf khi phiên khác đang busy; chặn start lại trong lúc projection đã có hoặc service cũ chưa destroy; gắn permission/consent result với ID và chỉ consume một lần; giữ request ownership qua Activity recreation. Sau Cancel, cần đóng hộp thoại Android còn pending trước khi Start lại để tránh nhận nhầm token.
- Encoder giải phóng codec khi constructor muxer lỗi và giải phóng input Surface khi configure/start lỗi. Snapshot async refresh/start/screenshot không ghi đè event mới; Saved dedupe theo tập session ID trong vòng đời controller, kể cả A/B/A.
- API 34+: video dùng system app/whole-display selector; screenshot giữ default-display. Callback resize cập nhật cùng VirtualDisplay, giữ canvas encoder cố định; khác aspect ratio có thể letterbox, không crop/restart token. Chưa hỗ trợ đổi resolution encoder động. API cũ dùng consent chuẩn hiện có.
- Giữ state names và stop/finalize/commit hiện tại. Cancel → idle không Saved; quá muộn khi finalizer đã sở hữu output vẫn trả lỗi. Callback projection đăng ký trước VirtualDisplay, onStop theo đúng phiên; không giả resume sau process death.
- File sửa: CaptureBridge.kt, CaptureService.kt, VideoEncoder.kt, CaptureRequests.kt; phần controller trong recording_service.dart; recording_controller_test.dart, CaptureRequestsTest.kt và báo cáo này.
- PASS host lần kiểm tra lại Task 02: 10 controller tests, gồm Start lặp khi pending/recording và controller mới reconnect snapshot paused mà không Stop/Saved. `flutter analyze --no-pub`: No issues found; `git diff --check`: PASS. Native compileDebugKotlin và CaptureRequestsTest (3) + FloatingControlGeometryTest (3) đã PASS ở lượt triển khai trước; không chạy lại vì không đổi Kotlin lần này. Test reconnect dùng fixture, không phải Activity recreation thật.
- NOT RUN: consent/Activity recreation thật, system revoke/lock, init fault injection, Stop/Cancel cleanup storage, MP4 playback và app-window resize. Theo lựa chọn người dùng chỉ code/host checks, không cài hoặc thao tác thiết bị.
- Không sửa UI, shared API, MainActivity, Manifest hoặc P2/P3; không cần P2 tích hợp mới. Giữ MediaProjection/FGS, audio, screenshot, facecam, floating controls, MediaStore và callback Media Library. UI dirty từ các task trước giữ nguyên.
- Giới hạn: request pending chỉ giữ trong process (không giữ token); Activity recreation thật và timeout native worker chưa được fault-test. Dedupe không phải exactly-once xuyên process; reconnect vẫn refresh catalog từ completed snapshot hợp lệ.

Cơ chế selector/resize theo [Android MediaProjection](https://developer.android.com/media/grow/media-projection); khác tỷ lệ giữa nội dung và Surface có thể tạo letterboxing.

Lượt nhận lại Task 02: đối chiếu Task 00/01 và source hiện tại; không phát hiện thêm lỗi cần sửa production trong phạm vi kiểm tra. Chỉ bổ sung `test/recording_controller_test.dart` và cập nhật báo cáo này. Checksum production/controller/UI không đổi so với đầu lượt; giữ nguyên thay đổi Task 03/04. Không tạo P2 request mới, không commit/push hoặc thao tác thiết bị.
