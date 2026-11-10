# TASK 09 — Bàn giao lỗi P1 cho Người 1

HEAD: `9afcb124069d905dd4b285c890ca0709f5548b68` (`main`). Đây là hồ sơ bàn giao trong repository; chưa gửi email/chat hoặc tạo issue từ tài khoản người dùng. Source P1, MainActivity, Create capture UI và SettingsController được giữ nguyên.

## R1 — Tự thay Recording Settings khi mở màn hình — HIGH

- Nguồn: [recording_settings_form.dart](../../lib/features/settings/recording_settings_form.dart), `didChangeDependencies`, `_normalizeSelection`, các nhánh `supported` và `settings.update`.
- Repro: settings đã lưu 1080p/60 hoặc tuple không có trong capabilities; mở Recording Settings; chờ capabilities xong; không chọn option nào. So document trước/sau và đóng/mở lại.
- Expected: giữ nguyên ý định người dùng, nêu option không hỗ trợ, chỉ cập nhật khi có thao tác lựa chọn rõ ràng. Performance mode phải được validate nhất quán, không âm thầm đổi lựa chọn.
- Actual: normalization chạy sau capabilities và có thể ghi resolution/FPS/codec/bitrate; test lựa chọn stale nhận 720p thay 1080p. Ba test layout nhận 1920×1080/60 thay 1280×720/30 mong đợi.
- Bằng chứng: [baseline](../../build/verification/task09/run_20261109T091518633188Z/baseline_flutter.log), [full cuối 285 PASS/4 FAIL](../../build/verification/task09/run_20261109T091518633188Z/final_flutter_v4.log). Không bỏ test, không đổi expected để xanh.
- Hướng sửa thuộc P1: tách capability validation khỏi mutation; UI giữ lựa chọn không hợp lệ và hướng dẫn chọn option phù hợp. Thống nhất default/explicit-change semantics với contract đã merge.
- Acceptance: mở/đóng Settings không phát write; unsupported selection vẫn nhìn thấy và chưa Start được; đổi option hợp lệ mới persist; test 320/360/411dp và Performance guard đều đạt; regression consent/capture không đổi.

## R2 — Portrait tuple bị vô hiệu hóa sai — HIGH

- Nguồn: [CaptureConfig.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureConfig.kt), `capabilities(activity)`; hai đoạn so tuple tại `RecordingSettingsForm`.
- Repro host chạy lại: advertised 1280×720/30/AVC, settings 720p Portrait. `validateRecordingSelection` chấp nhận tuple; chip `720p HD` bị disabled. Landscape cùng capabilities bật được.
- Bằng chứng: [portrait_probe_task09_v1.log](../../build/verification/task09/run_20261109T091518633188Z/portrait_probe_task09_v1.log), 2 quan sát. Fixture probe là diagnostic có assertion triệu chứng; không được gọi là đã sửa R2.
- Hướng sửa P1: dùng cùng quy ước canonical/orientation và cùng validator cho UI + preflight + recorder; xét codec/FPS/size support thực, không bật option phần cứng không nhận.
- Acceptance: portrait/landscape cho cùng tuple hợp lệ; unsupported tuple vẫn bị chặn; không đổi preferences khi chỉ đọc; native encoder/output trên thiết bị được phép là gate riêng.

## R4 — Region origin chưa vào pixel pipeline — HIGH

- Nguồn: `CaptureConfig.from` nhận/sanitize cropX/cropY/cropWidth/cropHeight; [CaptureService.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt) tạo VirtualDisplay trực tiếp vào surface; [VideoEncoder.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/VideoEncoder.kt) không áp dụng offset crop.
- Repro cần P1 + thiết bị được cho phép: dựng bốn góc/ô màu khác nhau; ghi vùng cùng kích thước tại hai origin khác nhau, kiểm pixel và tọa độ nội dung output. Test geometry hiện có chỉ kiểm dữ liệu đầu vào.
- Expected: output phản ánh đúng vùng chọn; actual static: đường đi hiện tại chưa chứng minh origin được sử dụng.
- Không quay màn hình hoặc sửa encoder trong TASK09 này. Chưa có pixel oracle runtime, nên giữ **P1 HANDOFF / NOT VERIFIED**.
- Acceptance: pixel oracle cho origin 0 và khác 0, rotation, vùng vượt biên, cancel/consent, A/V sync; không chỉ đổi metadata hoặc output dimensions.

## R5 — MP4 RecoveryEngine chưa nối production — MEDIUM

- Nguồn: [Mp4RecoveryEngine.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngine.kt), [CaptureJournal.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureJournal.kt). Tìm production caller chỉ thấy định nghĩa engine; `initialize → cleanup` xử lý pending owned item và cache.
- Repro cần P1: process interruption khi có output pending hợp lệ; relaunch; quan sát invocation/retained recovery input, không dùng dữ liệu QA5560.
- Expected: recovery được gọi khi format/state đủ điều kiện, publish chỉ sau validate; dữ liệu không đủ điều kiện không được gắn Saved giả.
- Actual: helper JUnit có thể đạt nhưng production recovery chưa chứng minh nối; không suy unit PASS thành startup recovery PASS.
- Acceptance: test production journal → engine → output/publish hoặc giữ file phục hồi, failure/cancel/no-space, không quét/xóa media người dùng; valid MP4 full decode + A/V timeline.

## R6 — Advanced capture UI/model/semantics — MEDIUM

| Nhánh | Đã có trong source | Còn cần P1 xác nhận/hoàn thiện |
|---|---|---|
| Facecam | Overlay/camera/position-size backend và bridge APIs, contract tests | UI chọn camera/layout/size và đường persist/relaunch thực; permission denied/no camera; output parity |
| Drawing | DrawingStrokeEngine/overlay/bridge, touch events | Palette/width/undo/erase/exit ở capture UI, pass-through semantics và output đúng |
| Floating controls | Pause/stop/collapse/expand/drag; **có own preferences về scale/opacity/position** | Shared Settings/UI cho các option và trạng thái nhất quán; không ghi là toàn bộ persistence thiếu |
| Ducking/crop | Optional args trong AndroidRecordingService/CaptureConfig | Shared RecordingSettings/persistence và UI chọn có ý nghĩa; region pixel pipeline R4 |
| Show touches / shake | Shake có đường nối; TouchIndicatorEngine có helper | Xác nhận caller/UI của touch indicator; không biến helper không có caller thành feature DONE |

Các optional concrete args chưa có trong shared interface không được P2/P3 tự thêm vào model capture. Người 1 quyết định API và báo contract mới trước TASK10.

## Tương thích và gate

- Recording commands/events, CaptureController `onSaved → media.refresh`, MediaStore content URI và observer vẫn cùng contract source; main app trên QA mới nhận được các output editor qua Library. Đây không phải record→library end-to-end.
- Request codes P1 702–707; P2/P3 1701–1705; Support 704 nằm trong callback routing riêng, không có sửa registration trong TASK09.
- Kiểm hash bảo vệ 33 file P1/shared tại cuối phiên; xem manifest integrity trong báo cáo evidence. Không reset/restore/overwrite thay đổi của team.
- **P1: PARTIAL. TASK10 READY: NO** khi R1/R2/R4/R5 chưa được Người 1 sửa/xác nhận và native capture acceptance chưa chạy trên phạm vi được phép. TASK09 không chờ P1 để sửa các lỗi editor/library độc lập.
