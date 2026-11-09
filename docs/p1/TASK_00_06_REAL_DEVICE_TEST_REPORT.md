# Task 00–06 — Real Android Device Test Report

**PARTIAL — TEST EXECUTION CLOSED**
Ngày kiểm thử: 2026-11-08; cập nhật 2026-11-08T11:22:38+07:00, Asia/Ho_Chi_Minh. Chỉ test/bằng chứng/báo cáo, không sửa source/UI/icon.

## 1. Executive Summary

- Thiết bị thật: **OPPO CPH2349, Android 11/API 30, arm64-v8a**, USB authorized, serial rút gọn **RGDM…AAT4**. Chỉ serial đã được xác nhận được dùng cho thao tác thiết bị; không chọn Linux/Chrome/emulator.
- App: **com.xrecorder.xrecorder, 0.1.0+1 debug**, branch **feature/capture-live**, HEAD **4ce6a53966a1ad1a4a33e10462cba9a0c6b3e905**, cộng working tree chưa commit có sẵn trước lượt test.
- Danh mục **93 cases**: **PASS: 55**, **FAIL: 1**, **BLOCKED: 0**, **NOT RUN: 29**, **UNSUPPORTED: 8**, **N/A: 0**.
- Danh mục gồm 92 cases yêu cầu và 1 case replay metadata bổ sung T06-19. Các lượt automation không hoàn tất không được tính PASS.

- Harness riêng: **3 PASS / 2 FAIL**. Configuration, controls, output30 PASS; Cancel retry FAIL end-of-test SemanticsHandle; Screenshot native FAIL chờ video row hiển thị. Cancel attempt đầu gián đoạn bởi automation/carrier UI không tính là product failure.
- Microphone denied đã xác nhận bằng dialog thật và native failed/outputUri=null; screenshot mới sau lỗi completed và PNG decode hợp lệ. Không dùng query catalog sai quoting để kết luận no Saved event.

- Recording thật, session/Pause/Resume/Stop, MP4 30s, native active 5-minute auto-stop ở Home, Mute/AAC mono, Portrait/Landscape canvas, bitrate/Performance policy và PNG/View/Library/repeated shots đã có evidence.
- Timer bổ sung qua Settings UI: countdown5s; auto-stop30s native30.003s/MP4 30.034s. auto-stop60s native60.002s/MP4 60.027s. Hai MP4 mới chỉ quay own-app đã decode lần lượt487/487 và877/877frames; không mở notification shade/private apps ở hai phiên này.

- Phiên dài: native **300.006s**, MP4 **300.312s**, **4230/4230 frames** đã decode; AAC mono 48kHz **300.023s**. Average sample FPS **14.085**, target **30**. Không chứng nhận CFR hoặc motion quality từ mẫu tĩnh này.
- Không suy PASS audio đúng nguồn/chất lượng, A/V sync, stereo, exactly-once Saved callbacks, Activity recreation/system revoke/lock, fault/leak hoặc Android 14+ từ các sample này.
- Một lượt retry sau unlock đã được cấp quyền micro và chạy recording, được dừng qua Stop; lưu riêng microphone_retry_unexpected_* và URI1000002324, không tính là denied test. Các lượt thiếu target/empty hierarchy được dừng, không bấm đoán.

- Giữ mọi output trên điện thoại. Full clip dài có đoạn notification shade đã được loại bỏ khỏi host evidence sau khi full decode; giữ hash/metadata/kết quả decode và frame an toàn đã kiểm. Hai clip trước URI2317 (Landscape) và URI2318 (Performance-overlay) chỉ metadata; không copy full MP4 sau auto-review rejection.
- Không có task nào được tự động tích Google Sheets; không đủ căn cứ coi toàn bộ Task 00–06 DONE.

## 2. Environment

| Hạng mục | Actual |
|---|---|
| Device | OPPO CPH2349, RGDM…AAT4, Android 11/API 30, arm64-v8a |
| Display | 720×1600 physical; 320 dpi (2 px/dp). PNG native observed 720×1456; không giả định bằng physical display. |
| Storage đầu lượt | /data còn 2,380,496 KiB (~2.27 GiB); không fill storage để thử lỗi. |
| Host / SDK | Ubuntu 24.04.4 LTS; Flutter 3.47.7/Dart 3.13.5; ADB 37.0.1; OpenCV hệ thống 4.6.0 |
| Media tools | ffprobe/ffmpeg không có trong PATH; Python stdlib đọc MP4 atoms; OpenCV decode video. GStreamer có nhưng thiếu AAC/H.264 decoding plugins; không cài thêm package. Audio chưa decode/nghe. |
| Main APK SHA-256 | 72edd81b5fb4a6007ad2414892b39ac5e3d82125e96488d4236887baf865d64a |
| Signer SHA-256 | 032ad9b4fd062c482a1e30c67f2d1b8ebdf4a58e2d6c8c797284dec3606be153 (Android Debug) |
| Installed app ban đầu | Version 0.1.0+1; APK hash trùng byte-for-byte debug local 56d455a7516320cc3dc37cd3e9d3fa76e51f2501b55c9546e93de4349eb46d8f. Không mặc định bản cài là latest. |

Xem [environment.json](test_evidence/task_00_06/environment.json), [git_status_before.txt](test_evidence/task_00_06/git_status_before.txt), [main_apk.json](test_evidence/task_00_06/main_apk.json), [main_build.log](test_evidence/task_00_06/main_build.log).

### Phương pháp / bảo vệ

- Chỉ đọc các báo cáo P1 yêu cầu và source cần xác minh target/test issue; không audit lại toàn repo hoặc Stitch.
- Build debug từ existing integration_test, không sửa test. ADB install -t -r chỉ sau kiểm cùng package/version/signer; dừng nếu install thất bại, không uninstall fallback, không -g, pm clear, root hoặc grant/revoke quyền qua developer command.
- Không dùng đường launch/install tự phục hồi của Flutter SDK vì nó có nhánh tự uninstall khi install thất bại. Launch harness bằng ADB; sau harness phục hồi lib/main.dart. Không dùng Desktop/Chrome cho kết quả Android.
- Trước AUTONOMOUS, người dùng xác nhận một số consent ở configuration test. Sau AUTONOMOUS, tự đọc hierarchy, tính tâm bounds, tap/swipe và xử lý dialog thật đúng test/3HRecorder. Không reuse projection token.
- Overlay không được OPPO UIAutomator expose; dùng screenshot đã xem cộng bounds WindowManager để định vị, rồi xác nhận native state. Không tap tọa độ suy đoán từ đầu.
- Mọi ADB tương tác có serial. UI/consent actions, bounds, native snapshots và test URI được lưu riêng. Logcat theo PID, loại VM service URLs. Không mở app nhạy cảm, livestream hoặc tài khoản.
- Khi chuyển Settings và sau permission revocation, một số lượt không tìm thấy target/empty hierarchy; automation dừng và đọc lại UI, dùng wakeup khi màn hình tắt, không vượt secure lock. Người dùng mở khóa bằng phương thức bình thường.

- Source freeze: SHA-256 536 file có sẵn; build/cache là generated, tách khỏi source. Giữ nguyên mọi diff trước test; không reset/restore/stage/commit/push.
- PASS chỉ đúng phạm vi actual/expected đã ghi. PASS functional case không biến Cancel/Screenshot harness thành PASS; hai suite FAIL vẫn là lỗi kiểm thử cần xử lý.

### Harness results

| Existing harness | Status | Actual / evidence |
|---|---|---|
| recording_configuration_test.dart | PASS | Bốn modes, gain snapshots .75/.5, countdown 1s/auto-stop 4s; [configuration_logcat.txt](test_evidence/task_00_06/configuration_logcat.txt) |
| recording_controls_test.dart | PASS | Pause 4s, cùng ID/reconnect, stop paused/double stop; [controls_logcat.txt](test_evidence/task_00_06/controls_logcat.txt) |
| floating_output_test.dart, OUTPUT_SECONDS=30 | PASS | MP4 30.069s/native 30.006s. Direct-launch harness không render nền xanh như dự kiến; screenshot live cũng tối, không dùng làm full overlay-output acceptance; [output30_logcat.txt](test_evidence/task_00_06/output30_logcat.txt) |
| recording_cancel_test.dart retry | FAIL | Functional assertions đi hết; active SemanticsHandle cuối test; [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt) |
| screenshot_native_test.dart + PRESERVE_TEST_OUTPUTS=true | FAIL | Hai PNG/countdown/View/feedback qua tới VIDEO; timeout tại line 197 chờ video row. Main app scroll thấy đúng file; [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt); [main_library_scrolled.xml](test_evidence/task_00_06/main_library_scrolled.xml) |

## 3. Test Results by Task

NOT RUN/BLOCKED/UNSUPPORTED/N/A không tính PASS. Các bước ở hàng NOT RUN chưa được thực hiện đầy đủ. Unsupported ghi rõ là app/implementation policy hay Android API, không suy hardware maximum.

### Task 00

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T00-01 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Đọc tài liệu/Git và so sánh hash. | Xác định branch hiện tại. | Branch feature/capture-live, HEAD 4ce6a53; working tree dirty đã được ghi trước test. | PASS | [git_identity.txt](test_evidence/task_00_06/git_identity.txt)<br>[git_status_before.txt](test_evidence/task_00_06/git_status_before.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T00-02 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Đọc tài liệu/Git và so sánh hash. | Xác minh các file P1/P2/P3 tuân thủ ownership. | So với baseline 536 file: không file có sẵn nào đổi; ownership theo báo cáo P1 hiện hữu, IR-00-01 vẫn pending xác nhận owner chính thức. | PASS | [source_freeze_interim.json](test_evidence/task_00_06/source_freeze_interim.json)<br>[git_status_before.txt](test_evidence/task_00_06/git_status_before.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T00-03 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Capture success → Saved event hợp lệ. | Hai PNG completed, is_pending=0, decode thật; harness qua Saved feedback và View trước marker VIDEO. | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_media_analysis.json](test_evidence/task_00_06/screenshot_media_analysis.json)<br>[screenshot_native_1_mediastore.txt](test_evidence/task_00_06/screenshot_native_1_mediastore.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T00-04 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Capture Cancel → không Saved event. | Các assertion cancel countdown/recording/paused/awaitingPermission, Saved không tăng và catalog không tăng đã đi hết; native idle/output null. Suite tổng thể FAIL ở end-of-test SemanticsHandle, không giấu kết quả này. | PASS | [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt)<br>[cancel_retry_actions.json](test_evidence/task_00_06/cancel_retry_actions.json)<br>[cancel_native_final.xml](test_evidence/task_00_06/cancel_native_final.xml) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T00-05 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Chưa thực hiện đầy đủ test case này. | Capture Error → không Saved event. | Đã quan sát lỗi micro denied thật: failed/outputUri=null và message rõ. Chưa instrument Saved event count; query catalog trước thử sai quoting nên chưa chứng minh đầy đủ no Saved event. | NOT RUN | [mic_deny_actual_native.json](test_evidence/task_00_06/mic_deny_actual_native.json)<br>[mic_deny_actual_ui.xml](test_evidence/task_00_06/mic_deny_actual_ui.xml) | NOT RUN cho toàn bộ contract event assertion; không suy no Saved event chỉ từ outputUri null. |
| T00-06 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Chưa thực hiện đầy đủ test case này. | Không xuất hiện duplicate Saved event. | Đã kiểm duplicate Stop giữ URI và duplicate screenshot không tăng file, nhưng chưa instrument chính xác số Saved event callback qua mọi replay/process. Không suy từ số file sang exactly-once event. | NOT RUN | Không có runtime evidence đủ cho case này. | Đã kiểm duplicate Stop giữ URI và duplicate screenshot không tăng file, nhưng chưa instrument chính xác số Saved event callback qua mọi replay/process. Không suy từ số file sang exactly-once event. |
| T00-07 | Working tree hiện tại và build debug cùng chữ ký; không thay source. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Media Library nhận kết quả đã lưu hợp lệ. | App bình thường hiển thị đúng MP4 regression trong Library sau scroll; PNG xuất hiện Photo Library/View theo assertion harness. | PASS | [main_library_scrolled.xml](test_evidence/task_00_06/main_library_scrolled.xml)<br>[main_library_scrolled.png](test_evidence/task_00_06/main_library_scrolled.png)<br>[screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |

### Task 01

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T01-01 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có Feature Audit Matrix. | Đã kiểm tra tài liệu: Feature Audit Matrix. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-02 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có danh sách trạng thái F01–F18, F20–F23, F52–F53. | Đã kiểm tra tài liệu: đủ 24 feature F01–F18/F20–F23/F52–F53. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-03 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có bằng chứng file/line. | Đã kiểm tra tài liệu: file/line evidence. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-04 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có bug/risk list. | Đã kiểm tra tài liệu: bug/risk list. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-05 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có P2 integration requests. | Đã kiểm tra tài liệu: P2 integration requests. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-06 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Đọc tài liệu/Git và so sánh hash. | Có recommended next tasks. | Đã kiểm tra tài liệu: recommended next tasks. Audit là snapshot lịch sử 2026-11-07, các task sau đã sửa một số issue. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T01-07 | Các báo cáo Task 00–06 hiện có, đọc trong phạm vi yêu cầu. | Chưa thực hiện đầy đủ test case này. | Không thay đổi UI/source ngoài báo cáo audit. | Chưa có checksum lịch sử riêng của lần Task 01. Lượt verification hiện tại giữ nguyên 536 file; không tự xác nhận lại lịch sử source/UI ngoài evidence đã có. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa có checksum lịch sử riêng của lần Task 01. Lượt verification hiện tại giữ nguyên 536 file; không tự xác nhận lại lịch sử source/UI ngoài evidence đã có. |

### Task 02

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T02-01 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Start → Android consent dialog. | Có dialog MediaProjection thật của 3HRecorder; nút được chọn từ hierarchy. | PASS | [T02-01_mixed_consent.xml](test_evidence/task_00_06/T02-01_mixed_consent.xml)<br>[T02-03_video_consent_denied.xml](test_evidence/task_00_06/T02-03_video_consent_denied.xml) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-02 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Consent Accept → Recording. | Consent accept dẫn tới native recording, foreground service/projection hoạt động và output thực. | PASS | [output30_native_recording.json](test_evidence/task_00_06/output30_native_recording.json)<br>[output30_projection_active.txt](test_evidence/task_00_06/output30_projection_active.txt)<br>[output30_service_active.txt](test_evidence/task_00_06/output30_service_active.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-03 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Consent Denied/Cancelled. | Chọn HỦY consent video: native idle, outputUri null, video IDs không tăng. | PASS | [T02-03_action.json](test_evidence/task_00_06/T02-03_action.json)<br>[T02-03_native_after_deny.json](test_evidence/task_00_06/T02-03_native_after_deny.json)<br>[T02-03_video_ids_after_deny.txt](test_evidence/task_00_06/T02-03_video_ids_after_deny.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-04 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Record 30s → Stop → playable MP4. | MP4 30.069s, native elapsed 30.006s; giải mã đủ 174/174 frames. Mẫu trực quan tối giống screenshot live; không dùng làm bằng chứng toàn diện cho overlay. | PASS | [output30_logcat.txt](test_evidence/task_00_06/output30_logcat.txt)<br>[output30_mediastore.txt](test_evidence/task_00_06/output30_mediastore.txt)<br>[output30_frame_analysis.json](test_evidence/task_00_06/output30_frame_analysis.json)<br>[output30.mp4](test_evidence/task_00_06/output30.mp4) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-05 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Start → Pause → Resume → Stop. | Controls harness native pause 4s, resume cùng ID, stop lúc paused; MP4 6.338s, 81/81 frames. | PASS | [controls_logcat.txt](test_evidence/task_00_06/controls_logcat.txt)<br>[controls_journal.xml](test_evidence/task_00_06/controls_journal.xml)<br>[controls_decode.json](test_evidence/task_00_06/controls_decode.json)<br>[controls.mp4](test_evidence/task_00_06/controls.mp4) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-06 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chưa thực hiện đầy đủ test case này. | Double Start không tạo session thứ hai. | UI không hiển thị Start khi active; chưa gọi duplicate native Start trong cùng phiên bằng harness hiện có. Không dùng tap tọa độ stale khi dialog đã đổi. | NOT RUN | Không có runtime evidence đủ cho case này. | UI không hiển thị Start khi active; chưa gọi duplicate native Start trong cùng phiên bằng harness hiện có. Không dùng tap tọa độ stale khi dialog đã đổi. |
| T02-07 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Double Stop không tạo video trùng. | Double Stop sau completed giữ nguyên output URI, assertion harness PASS. | PASS | [controls_logcat.txt](test_evidence/task_00_06/controls_logcat.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-08 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Recording → chuyển app → quay lại. | Home/background/return giữ nguyên native recording ID; sau return UI timer 168s, không reset. | PASS | [long_background_return.json](test_evidence/task_00_06/long_background_return.json)<br>[long_ui_after_background.xml](test_evidence/task_00_06/long_ui_after_background.xml) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T02-09 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chưa thực hiện đầy đủ test case này. | Recording → Lock/Unlock. | Không chụp lockscreen/notification cá nhân. Cần test có lockscreen được chuẩn bị an toàn hoặc sự tham gia của chủ thiết bị. | NOT RUN | Không có runtime evidence đủ cho case này. | Không chụp lockscreen/notification cá nhân. Cần test có lockscreen được chuẩn bị an toàn hoặc sự tham gia của chủ thiết bị. |
| T02-10 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chưa thực hiện đầy đủ test case này. | Recording → Rotate. | Đã kiểm Portrait/Landscape canvas khi start; chưa đổi orientation màn hình trong lúc quay. Không thay global rotation setting khi chưa cần. | NOT RUN | Không có runtime evidence đủ cho case này. | Đã kiểm Portrait/Landscape canvas khi start; chưa đổi orientation màn hình trong lúc quay. Không thay global rotation setting khi chưa cần. |
| T02-11 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chưa thực hiện đầy đủ test case này. | Android system stops screen sharing. | Chưa xác định node Android system Stop screen sharing riêng trên ROM này. Stop app notification không được tính là OS revoke. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa xác định node Android system Stop screen sharing riêng trên ROM này. Stop app notification không được tính là OS revoke. |
| T02-12 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chưa thực hiện đầy đủ test case này. | Activity recreation. | Home/return đã chạy, không đồng nghĩa Activity recreation. Chưa có test hook safe recreation hiện có; không kill phiên người dùng hoặc đổi Don’t keep activities. | NOT RUN | Không có runtime evidence đủ cho case này. | Home/return đã chạy, không đồng nghĩa Activity recreation. Chưa có test hook safe recreation hiện có; không kill phiên người dùng hoặc đổi Don’t keep activities. |
| T02-13 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | App-window capture trên Android hỗ trợ. | Thiết bị API 30; không kiểm thử app-window capture Android 14+. | UNSUPPORTED | [environment.json](test_evidence/task_00_06/environment.json) | Không tính là PASS. |
| T02-14 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Saved event chỉ sau khi file hợp lệ. | Output có duration/track hợp lệ, is_pending=0 và native completed; source contract commit-before-completed đã có trong báo cáo Task 00/04. Không fault-inject commit failure. | PASS | [output30_mediastore.txt](test_evidence/task_00_06/output30_mediastore.txt)<br>[output30_native_completed.xml](test_evidence/task_00_06/output30_native_completed.xml)<br>[configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-15 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Cancel/Failure không tạo output thành công giả. | Cancel functional assertions và video consent denied không publish output mới. Fault paths encoder/storage chưa chạy. | PASS | [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt)<br>[cancel_native_final.xml](test_evidence/task_00_06/cancel_native_final.xml)<br>[T02-03_native_after_deny.json](test_evidence/task_00_06/T02-03_native_after_deny.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T02-16 | OPPO API30; cùng recording session; consent hệ thống bình thường. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Recording 5–10 phút. | Phiên native active 300.006s, MP4 300.312s; giải mã đủ 4230/4230 frames. | PASS | [long_autostop_observations.json](test_evidence/task_00_06/long_autostop_observations.json)<br>[long_mediastore.txt](test_evidence/task_00_06/long_mediastore.txt)<br>[all_media_analysis.json](test_evidence/task_00_06/all_media_analysis.json)<br>[media_privacy_retention.json](test_evidence/task_00_06/media_privacy_retention.json) | Full decode đã thực hiện thật; sau rà soát privacy, bản sao MP4 cục bộ mới tạo đã được loại bỏ vì có notification shade. File gốc trên điện thoại được giữ nguyên. Không suy từ decode sang nội dung mọi frame an toàn. |

### Task 03

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T03-01 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Mute. | Mute tạo đúng 1 video track, không audio track; MP4 decode thành công. | PASS | [configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json)<br>[config_mute_mediastore.txt](test_evidence/task_00_06/config_mute_mediastore.txt)<br>[config_mute.mp4](test_evidence/task_00_06/config_mute.mp4) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T03-02 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Microphone. | AAC microphone thật và 5-minute duration đã kiểm; chưa có người nghe hoặc tín hiệu âm được phê duyệt để xác minh đúng nguồn/chất lượng. PENDING MANUAL VERIFICATION. | NOT RUN | Không có runtime evidence đủ cho case này. | AAC microphone thật và 5-minute duration đã kiểm; chưa có người nghe hoặc tín hiệu âm được phê duyệt để xác minh đúng nguồn/chất lượng. PENDING MANUAL VERIFICATION. |
| T03-03 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Internal Audio. | Internal tạo AAC track, nhưng không tự phát nhạc/app riêng tư và chưa có nguồn test internal được cho phép; chưa chứng nhận tiếng đúng nguồn. PENDING MANUAL VERIFICATION. | NOT RUN | Không có runtime evidence đủ cho case này. | Internal tạo AAC track, nhưng không tự phát nhạc/app riêng tư và chưa có nguồn test internal được cho phép; chưa chứng nhận tiếng đúng nguồn. PENDING MANUAL VERIFICATION. |
| T03-04 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Mixed Audio. | Mixed tạo AAC track và snapshot đúng source/gains; chưa có hai tín hiệu test để xác minh pha trộn nghe được. PENDING MANUAL VERIFICATION. | NOT RUN | Không có runtime evidence đủ cho case này. | Mixed tạo AAC track và snapshot đúng source/gains; chưa có hai tín hiệu test để xác minh pha trộn nghe được. PENDING MANUAL VERIFICATION. |
| T03-05 | Microphone selected; denied qua system Settings; app yêu cầu quyền ghi âm thật. | adb -s RGDMSKDY7PPBAAT4 exec-out uiautomator dump /dev/tty; xác định dialog Cho phép 3HRecorder ghi âm?; tap tâm bounds permission_deny_and_dont_ask_again_button; đọc native capture journal. | Microphone permission denied. | Native failed, outputUri=null; error: Audio permission was denied. Select mute to record without audio. Không bypass quyền hoặc tạo MediaProjection mới. | PASS | [mic_deny_runtime_dialog.xml](test_evidence/task_00_06/mic_deny_runtime_dialog.xml)<br>[mic_deny_actual_action.json](test_evidence/task_00_06/mic_deny_actual_action.json)<br>[mic_deny_actual_native.json](test_evidence/task_00_06/mic_deny_actual_native.json)<br>[mic_deny_actual_ui.xml](test_evidence/task_00_06/mic_deny_actual_ui.xml) | PASS denied/error path. Query catalog trước thử sai quoting, không dùng làm bằng chứng không tăng file hoặc đếm Saved callbacks. Lượt sau unlock ban đầu được cấp quyền và đã dừng; lưu riêng, không tính denied. |
| T03-06 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | App nguồn không cho internal capture. | Không có nguồn app protected-audio test được cho phép; không mở app nội dung riêng tư hoặc bypass capture policy. | NOT RUN | Không có runtime evidence đủ cho case này. | Không có nguồn app protected-audio test được cho phép; không mở app nội dung riêng tư hoặc bypass capture policy. |
| T03-07 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Microphone gain. | Runtime snapshot gain .75 trong configuration harness đã qua assertion; chưa đo amplitude/waveform trên tín hiệu chuẩn. | NOT RUN | Không có runtime evidence đủ cho case này. | Runtime snapshot gain .75 trong configuration harness đã qua assertion; chưa đo amplitude/waveform trên tín hiệu chuẩn. |
| T03-08 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Internal gain. | Runtime snapshot internal gain .5 đã qua assertion; chưa có nguồn test được phép để đo amplitude/waveform. | NOT RUN | Không có runtime evidence đủ cho case này. | Runtime snapshot internal gain .5 đã qua assertion; chưa có nguồn test được phép để đo amplitude/waveform. |
| T03-09 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Mono/Stereo. | Output thật là AAC mono 48kHz; implementation hiện tại không cung cấp stereo. Không kết luận phần cứng không hỗ trợ stereo. | UNSUPPORTED | [configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json) | Không tính là PASS. |
| T03-10 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Pause/Resume audio sync. | Pause duration và track durations đã kiểm; chênh track-end 0.289s của mẫu dài không phải phép đo A/V sync bằng tín hiệu mốc. Chưa nghe/đo drift. | NOT RUN | Không có runtime evidence đủ cho case này. | Pause duration và track durations đã kiểm; chênh track-end 0.289s của mẫu dài không phải phép đo A/V sync bằng tín hiệu mốc. Chưa nghe/đo drift. |
| T03-11 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Recording 5 phút có audio. | Recording 5 phút với microphone: AAC mono 48kHz, audio duration 300.023s/14063 AAC samples, video 300.312s. Chưa nghe/waveform hoặc chứng nhận drift A/V. | PASS | [all_media_analysis.json](test_evidence/task_00_06/all_media_analysis.json)<br>[long_mediastore.txt](test_evidence/task_00_06/long_mediastore.txt) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T03-12 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Stop/Cancel cleanup. | Các output stop đã published, service/projection null; hai temp MP4/M4A đúng session dài không còn trong cache. Cancel assertions không tăng catalog. Không fault-test driver/I/O. | PASS | [long_temp_cleanup.json](test_evidence/task_00_06/long_temp_cleanup.json)<br>[long_cleanup_projection.txt](test_evidence/task_00_06/long_cleanup_projection.txt)<br>[long_cleanup_service.txt](test_evidence/task_00_06/long_cleanup_service.txt)<br>[cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T03-13 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chưa thực hiện đầy đủ test case này. | Audio hoạt động khi app background. | Session/FGS tiếp tục ở background, AAC timeline đủ 300.023s; chưa xác minh waveform/tiếng mic khi background nên không PASS đầy đủ audio correctness. | NOT RUN | Không có runtime evidence đủ cho case này. | Session/FGS tiếp tục ở background, AAC timeline đủ 300.023s; chưa xác minh waveform/tiếng mic khi background nên không PASS đầy đủ audio correctness. |
| T03-14 | AudioRecord/codec thật; chất lượng nguồn cần audio test được phép và đánh giá nghe. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Không bị giữ cấu hình audio từ phiên trước. | Harness lần lượt mute/microphone/internal/mixed, assert configSnapshot audio source và hasAudio đúng mỗi lượt. | PASS | [configuration_logcat.txt](test_evidence/task_00_06/configuration_logcat.txt)<br>[configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |

### Task 04

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T04-01 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | 720p/30 FPS. | Effective config 720x1280, 30 FPS target, AVC; file decode thật. FPS trung bình đo được trên mẫu tĩnh khác 30, không chứng nhận CFR/actual 30 FPS. | PASS | [configuration_logcat.txt](test_evidence/task_00_06/configuration_logcat.txt)<br>[configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json)<br>[output30_native_recording.json](test_evidence/task_00_06/output30_native_recording.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T04-02 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | 1080p/30 FPS. | 1080p disabled trong UI capability hiện tại; không tạo 1080p MP4, không suy ra codec hardware maximum. | UNSUPPORTED | [record_setup_initial.xml](test_evidence/task_00_06/record_setup_initial.xml)<br>[record_setup_initial.png](test_evidence/task_00_06/record_setup_initial.png) | Không tính là PASS. |
| T04-03 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | 1080p/60 FPS nếu hỗ trợ. | 1080p/60 không được app cho chọn ở cấu hình này; không có output 1080p60. | UNSUPPORTED | [record_setup_initial.xml](test_evidence/task_00_06/record_setup_initial.xml) | Không tính là PASS. |
| T04-04 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | 2K/4K capability. | Đã kiểm tra capability qua UI thật: 2K và 4K disabled. Đây là kiểm tra advertise/gating, không phải encode 2K/4K. | PASS | [record_setup_initial.xml](test_evidence/task_00_06/record_setup_initial.xml)<br>[record_setup_initial.png](test_evidence/task_00_06/record_setup_initial.png) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T04-05 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | H.264/AVC output. | MP4 sample entry avc1, có video frames giải mã thật. | PASS | [configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json)<br>[config_mute.mp4](test_evidence/task_00_06/config_mute.mp4) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T04-06 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | H.265/HEVC output nếu hỗ trợ. | H.265/HEVC disabled trong UI với 720p/30 hiện tại; không có HEVC output để nghiệm thu. | UNSUPPORTED | [advanced_initial.xml](test_evidence/task_00_06/advanced_initial.xml)<br>[advanced_scrolled1.xml](test_evidence/task_00_06/advanced_scrolled1.xml) | Không tính là PASS. |
| T04-07 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chưa thực hiện đầy đủ test case này. | Unsupported codec handling. | HEVC bị UI disable; chưa có native negative-path unsupported codec test có sẵn được chạy. Không chỉnh source/hook để inject codec lỗi. | NOT RUN | Không có runtime evidence đủ cho case này. | HEVC bị UI disable; chưa có native negative-path unsupported codec test có sẵn được chạy. Không chỉnh source/hook để inject codec lỗi. |
| T04-08 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chọn cấu hình bằng UIAutomator bounds (xem landscape_setup_actions/start_actions), chấp nhận consent mới, Tap Stop và kiểm journal/MediaStore. | Low vs High Bitrate. | Normal nhận 8 Mbps ở phiên dài và 24 Mbps ở phiên Landscape, cả hai tạo MP4 published. Đây là xác minh effective requested target, không cam kết bitrate thực CBR/so sánh chất lượng cảnh giống nhau. | PASS | [long_recording_started.json](test_evidence/task_00_06/long_recording_started.json)<br>[long_mediastore.txt](test_evidence/task_00_06/long_mediastore.txt)<br>[landscape_native_recording.json](test_evidence/task_00_06/landscape_native_recording.json)<br>[landscape_mediastore.txt](test_evidence/task_00_06/landscape_mediastore.txt) | Không suy rộng bitrate mục tiêu thành CBR, hoặc canvas landscape thành dynamic rotation. |
| T04-09 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Portrait output. | Portrait effective 720x1280, snapshot và MP4 metadata khớp. | PASS | [configuration_logcat.txt](test_evidence/task_00_06/configuration_logcat.txt)<br>[configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T04-10 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chọn cấu hình bằng UIAutomator bounds (xem landscape_setup_actions/start_actions), chấp nhận consent mới, Tap Stop và kiểm journal/MediaStore. | Landscape output. | Landscape native 1280x720, 24Mbps/Mute; MP4 MediaStore 1280x720, 250.526s published. Không copy/decode full clip này vì đã có notification shade; chưa nghiệm thu dynamic rotation. | PASS | [landscape_native_recording.json](test_evidence/task_00_06/landscape_native_recording.json)<br>[landscape_native_completed.json](test_evidence/task_00_06/landscape_native_completed.json)<br>[landscape_mediastore.txt](test_evidence/task_00_06/landscape_mediastore.txt) | Không suy rộng bitrate mục tiêu thành CBR, hoặc canvas landscape thành dynamic rotation. |
| T04-11 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Auto Orientation. | Auto orientation khi thiết bị portrait tạo 720x1280 và giữ orientation=automatic trong native snapshot. Dynamic rotation chưa được chứng nhận. | PASS | [controls_journal.xml](test_evidence/task_00_06/controls_journal.xml)<br>[controls_decode.json](test_evidence/task_00_06/controls_decode.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T04-12 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chọn Normal/Performance bằng UI; chấp nhận consent mới; xem native effective config và MediaStore sau Stop. | Normal/Performance mode. | Normal/24Mbps tạo MP4 250.526s; Performance cùng request bitrate bị clamp native về 8Mbps/30FPS/1280x720 và tạo output published. Không benchmark CPU/RAM/nhiệt hoặc chất lượng nghe/nhìn. | PASS | [landscape_native_recording.json](test_evidence/task_00_06/landscape_native_recording.json)<br>[landscape_mediastore.txt](test_evidence/task_00_06/landscape_mediastore.txt)<br>[performance_native_recording.json](test_evidence/task_00_06/performance_native_recording.json)<br>[performance_mediastore.txt](test_evidence/task_00_06/performance_mediastore.txt) | Chỉ policy/config/runtime save đã kiểm chứng; hiệu năng thực tế chưa được chứng nhận. |
| T04-13 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chưa thực hiện đầy đủ test case này. | Pause/Resume high FPS. | Có pause/resume 30 FPS; chưa thử high-FPS với motion scene. Không đồng nhất configured FPS và actual FPS. | NOT RUN | Không có runtime evidence đủ cho case này. | Có pause/resume 30 FPS; chưa thử high-FPS với motion scene. Không đồng nhất configured FPS và actual FPS. |
| T04-14 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chưa thực hiện đầy đủ test case này. | 5-minute recording high preset. | Đã có 5 phút 720p30/8Mbps; không có 5 phút high preset riêng. 1080p/2K/4K bị app disable ở cấu hình đã quan sát. | NOT RUN | Không có runtime evidence đủ cho case này. | Đã có 5 phút 720p30/8Mbps; không có 5 phút high preset riêng. 1080p/2K/4K bị app disable ở cấu hình đã quan sát. |
| T04-15 | Preset được app advertise; output thật và công cụ metadata/decode có sẵn. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | MP4 metadata verification. | Đã đọc MediaStore, MP4 atoms, tracks, duration, dimensions, AAC channels/rate, average FPS và decode frames. ffprobe không có; dùng OpenCV hệ thống/stdlib, chưa decode audio. | PASS | [configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json)<br>[output30_frame_analysis.json](test_evidence/task_00_06/output30_frame_analysis.json)<br>[controls_decode.json](test_evidence/task_00_06/controls_decode.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |

### Task 05

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T05-01 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Countdown 3s. | Hai screenshot có timeline countdown chứa 3,2,1 và khoảng native countdown >=2.8s (assertion qua trước marker VIDEO). | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_actions.json](test_evidence/task_00_06/screenshot_actions.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T05-02 | App settings countdown5s, auto-stop30s, mute. | Chọn5s bằng UI settings, Start/consent qua bounds thật; poll capture_journal bằng ADB serial từ sau consent đến recording. | Countdown 5s. | Native config countdown=5; countdown quan sát từ +0.10s, starting +4.57s, recording +5.23s sau mốc host (mốc được lấy sau tap consent 0.3s). Không recording trước countdown; MP4 bắt đầu riêng khi recording. | PASS | [full_settings_countdown_actions.json](test_evidence/task_00_06/full_settings_countdown_actions.json)<br>[full_settings_countdown5.xml](test_evidence/task_00_06/full_settings_countdown5.xml)<br>[timer30_actions.json](test_evidence/task_00_06/timer30_actions.json)<br>[timer30_timeline.json](test_evidence/task_00_06/timer30_timeline.json) | Polling journal không capture từng tick4/3/2/1; không khẳng định đã quan sát animation từng số. |
| T05-03 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Countdown Cancel. | Cancel countdown trong harness không tăng Saved/catalog; suite có lỗi teardown SemanticsHandle được tách riêng. | PASS | [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt)<br>[cancel_retry_actions.json](test_evidence/task_00_06/cancel_retry_actions.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T05-04 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chưa thực hiện đầy đủ test case này. | Double Start trong countdown. | Đã kiểm cancel countdown; chưa thực hiện duplicate native Start trong countdown bằng test có sẵn. Không double-tap mù sau khi nút đổi sang system dialog. | NOT RUN | Không có runtime evidence đủ cho case này. | Đã kiểm cancel countdown; chưa thực hiện duplicate native Start trong countdown bằng test có sẵn. Không double-tap mù sau khi nút đổi sang system dialog. |
| T05-05 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Permission Denied. | Video consent denied trở về idle, không output; không bắt đầu countdown. | PASS | [T02-03_native_after_deny.json](test_evidence/task_00_06/T02-03_native_after_deny.json)<br>[T02-03_action.json](test_evidence/task_00_06/T02-03_action.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T05-06 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Countdown disabled/0s. | Countdown=0 trong controls/output harness đi tới recording và tạo MP4 thật. | PASS | [controls_journal.xml](test_evidence/task_00_06/controls_journal.xml)<br>[output30_native_recording.json](test_evidence/task_00_06/output30_native_recording.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T05-07 | Custom duration30s được nhập qua Settings dialog; Mute/AVC720p30Performance. | UI chọn auto-stop30s; consent thật; không tapStop; poll native đến completed và query đúng output URI. | Auto-stop 30s. | Native active30003ms tự finalizing/completed; URI1000002326, MP4 duration30034ms,629149bytes1280×720,is_pending=0. Countdown5s không tính vào30s active. OpenCV mở hợp lệ và decode487/487frames. | PASS | [timer30_settings_actions.json](test_evidence/task_00_06/timer30_settings_actions.json)<br>[timer30_actions.json](test_evidence/task_00_06/timer30_actions.json)<br>[timer30_timeline.json](test_evidence/task_00_06/timer30_timeline.json)<br>[timer30_final_native.json](test_evidence/task_00_06/timer30_final_native.json)<br>[timer30_mediastore.txt](test_evidence/task_00_06/timer30_mediastore.txt)<br>[timer30_decode_validation.json](test_evidence/task_00_06/timer30_decode_validation.json)<br>[timer30_own_app.mp4](test_evidence/task_00_06/timer30_own_app.mp4) | PASS timer/finalize/output decode; FPS target không chứng nhận CFR. Ba sampleframes cho thấy portrait content fit trong landscape canvas với black pillarbox hai bên; không gọi đây là overlay rectangle. |
| T05-08 | Custom auto-stop60s, countdown5s, Mute/AVC/Performance landscape. | Settings dialog thay30 bằng60; Start/consent theo hierarchy; chờ native auto-stop không bấmStop; query URI và decode MP4 own-app. | Auto-stop 60s. | Native active60002ms tự finalizing/completed; URI1000002327, MP4 duration60027ms1098149bytes1280×720is_pending=0; decode877/877frames. | PASS | [timer60_actions.json](test_evidence/task_00_06/timer60_actions.json)<br>[timer60_timeline.json](test_evidence/task_00_06/timer60_timeline.json)<br>[timer60_final_native.json](test_evidence/task_00_06/timer60_final_native.json)<br>[timer60_mediastore.txt](test_evidence/task_00_06/timer60_mediastore.txt)<br>[timer60_decode_validation.json](test_evidence/task_00_06/timer60_decode_validation.json)<br>[timer60_own_app.mp4](test_evidence/task_00_06/timer60_own_app.mp4) | PASS auto-stop/outputdecode; không chứng nhận motion/CFR/A-V sync. Phiên giữ own-app foreground, không mở notification/private apps. |
| T05-09 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Pause → Resume → Auto-stop. | Pause giữ nguyên elapsed 77444ms; Resume cùng ID; native auto-stop tại active 300006ms, không tính khoảng paused. | PASS | [long_pause_resume_actions.json](test_evidence/task_00_06/long_pause_resume_actions.json)<br>[long_autostop_observations.json](test_evidence/task_00_06/long_autostop_observations.json) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T05-10 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chọn cấu hình bằng UIAutomator bounds (xem landscape_setup_actions/start_actions), chấp nhận consent mới, Tap Stop và kiểm journal/MediaStore. | Manual Stop trước deadline. | Tap Stop thật ở active 250441ms trước giới hạn 300000ms, completed và MP4 duration 250526ms. | PASS | [landscape_native_completed.json](test_evidence/task_00_06/landscape_native_completed.json)<br>[landscape_mediastore.txt](test_evidence/task_00_06/landscape_mediastore.txt)<br>[landscape_before_stop.xml](test_evidence/task_00_06/landscape_before_stop.xml) | Không suy rộng bitrate mục tiêu thành CBR, hoặc canvas landscape thành dynamic rotation. |
| T05-11 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Auto-stop khi app background. | Đã gửi Home lúc native recording trước deadline; không gửi Stop, native tự completed và MP4 300.312s. | PASS | [long_before_background_deadline.json](test_evidence/task_00_06/long_before_background_deadline.json)<br>[long_autostop_observations.json](test_evidence/task_00_06/long_autostop_observations.json)<br>[long_mediastore.txt](test_evidence/task_00_06/long_mediastore.txt) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T05-12 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chưa thực hiện đầy đủ test case này. | Activity recreation. | Chưa có Activity recreation thật trong countdown/auto-stop; foreground/background không thay thế recreation. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa có Activity recreation thật trong countdown/auto-stop; foreground/background không thay thế recreation. |
| T05-13 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chưa thực hiện đầy đủ test case này. | System Stop gần deadline. | Chưa gọi OS stop sharing gần deadline; các Stop đã thử là app/native controls. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa gọi OS stop sharing gần deadline; các Stop đã thử là app/native controls. |
| T05-14 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chưa thực hiện đầy đủ test case này. | Encoder error gần deadline (chỉ dùng test hook an toàn nếu đã có). | Không có safe encoder-error hook được chạy; không cố làm đầy storage hoặc gây fault mất dữ liệu. | NOT RUN | Không có runtime evidence đủ cho case này. | Không có safe encoder-error hook được chạy; không cố làm đầy storage hoặc gây fault mất dữ liệu. |
| T05-15 | Native countdown/active-duration; không dùng timer/controller test thứ hai. | Chọn cấu hình bằng UIAutomator bounds (xem landscape_setup_actions/start_actions), chấp nhận consent mới, Tap Stop và kiểm journal/MediaStore. | Session mới không bị timer cũ ảnh hưởng. | Sau phiên auto-stop 300s, phiên Landscape mới có ID/start clock mới và chạy 250.441s tới Stop thủ công, không bị timer phiên trước dừng ngay; tiếp tục tạo session Performance mới. | PASS | [long_autostop_observations.json](test_evidence/task_00_06/long_autostop_observations.json)<br>[landscape_native_recording.json](test_evidence/task_00_06/landscape_native_recording.json)<br>[landscape_native_completed.json](test_evidence/task_00_06/landscape_native_completed.json)<br>[performance_native_recording.json](test_evidence/task_00_06/performance_native_recording.json) | Không suy rộng bitrate mục tiêu thành CBR, hoặc canvas landscape thành dynamic rotation. |

### Task 06

| ID | Preconditions | Steps / ADB | Expected | Actual | Status | Evidence | Notes |
|---|---|---|---|---|---|---|---|
| T06-01 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Screenshot Idle. | Screenshot từ idle tạo PNG thật và published. | PASS | [screenshot_native_1_mediastore.txt](test_evidence/task_00_06/screenshot_native_1_mediastore.txt)<br>[screenshot_media_analysis.json](test_evidence/task_00_06/screenshot_media_analysis.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-02 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Screenshot Delay 3s. | Native delay 3s và timeline 3/2/1 đã qua assertion harness. | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_actions.json](test_evidence/task_00_06/screenshot_actions.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-03 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Cancel Delay. | Screenshot delay cố định 3s và chủ động minimize app; chưa có native cancel-screenshot harness/target UI an toàn trong cửa sổ này. Không suy từ video countdown cancel. | NOT RUN | Không có runtime evidence đủ cho case này. | Screenshot delay cố định 3s và chủ động minimize app; chưa có native cancel-screenshot harness/target UI an toàn trong cửa sổ này. Không suy từ video countdown cancel. |
| T06-04 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Permission Denied. | Screenshot DENY và BACK đều không tăng ảnh, không feedback Saved theo assertions trước CAPTURE_1. | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_DENY_consent.xml](test_evidence/task_00_06/screenshot_DENY_consent.xml)<br>[screenshot_BACK_consent.xml](test_evidence/task_00_06/screenshot_BACK_consent.xml) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-05 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Screenshot during Recording nếu hỗ trợ. | UI Screenshot disabled khi recording; kiến trúc hiện tại không cung cấp concurrent screenshot. | UNSUPPORTED | [long_ui_recording.xml](test_evidence/task_00_06/long_ui_recording.xml) | Không tính là PASS. |
| T06-06 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Screenshot during Paused Recording nếu hỗ trợ. | Screenshot disabled khi paused, đã quan sát trên hai hierarchy; implementation không cung cấp concurrent screenshot. | UNSUPPORTED | [long_paused_1.xml](test_evidence/task_00_06/long_paused_1.xml)<br>[long_paused_2.xml](test_evidence/task_00_06/long_paused_2.xml) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T06-07 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Tap Screenshot bằng bounds trong Photo Library; accept consent thật; đưa own app trở lại trong 3s delay; poll native completed; content query/read đúng URI; decode PNG. | Screenshot 5 lần liên tiếp. | 5 lần liên tiếp qua 5 consent mới, 5 session/URI khác nhau; mọi PNG signature đúng, decode 720x1456, nhiều màu, is_pending=0; giữ toàn bộ ảnh. | PASS | [T06-07_repeated_screenshots.json](test_evidence/task_00_06/T06-07_repeated_screenshots.json)<br>[T06-07_shot_1_mediastore.txt](test_evidence/task_00_06/T06-07_shot_1_mediastore.txt)<br>[T06-07_shot_2_mediastore.txt](test_evidence/task_00_06/T06-07_shot_2_mediastore.txt)<br>[T06-07_shot_3_mediastore.txt](test_evidence/task_00_06/T06-07_shot_3_mediastore.txt)<br>[T06-07_shot_4_mediastore.txt](test_evidence/task_00_06/T06-07_shot_4_mediastore.txt)<br>[T06-07_shot_5_mediastore.txt](test_evidence/task_00_06/T06-07_shot_5_mediastore.txt) | Không mở app nhạy cảm; ảnh test được giữ trên điện thoại. Chỉ chụp nội dung của app trong lượt này. |
| T06-08 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Rotate trước khi chụp. | Chưa xoay màn hình trước screenshot. Native 720x1456 đã decode, không thay rotation setting để giả kết quả. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa xoay màn hình trước screenshot. Native 720x1456 đã decode, không thay rotation setting để giả kết quả. |
| T06-09 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Screenshot nội dung ứng dụng khác được phép. | Native screenshot chụp launcher sau khi app chủ động minimize; không mở ứng dụng riêng tư khác. | PASS | [screenshot_native_1.png](test_evidence/task_00_06/screenshot_native_1.png)<br>[screenshot_media_analysis.json](test_evidence/task_00_06/screenshot_media_analysis.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-10 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | FLAG_SECURE/DRM limitations; chỉ kiểm tra giới hạn từ code/tài liệu hoặc trường hợp thử nghiệm hợp pháp, không vượt bảo vệ. | Chỉ xác minh giới hạn secure/DRM từ tài liệu Task 06 và báo cáo controls; không vượt bảo vệ hoặc nhận là runtime test DRM. | PASS | [document_audit.json](test_evidence/task_00_06/document_audit.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-11 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Storage error handling; chỉ kiểm tra bằng test an toàn, không cố làm đầy bộ nhớ điện thoại. | Không chạy I/O/storage fault injection; không cố làm đầy bộ nhớ thiết bị. | NOT RUN | Không có runtime evidence đủ cho case này. | Không chạy I/O/storage fault injection; không cố làm đầy bộ nhớ thiết bị. |
| T06-12 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Empty frame/timeout bằng test có sẵn nếu hỗ trợ. | Không có safe empty-frame/timeout hook đã chạy; không suy từ unit buffer tests sang runtime timeout. | NOT RUN | Không có runtime evidence đủ cho case này. | Không có safe empty-frame/timeout hook đã chạy; không suy từ unit buffer tests sang runtime timeout. |
| T06-13 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Cancel during capture. | Chưa cancel trong one-shot frame/finalizer; không đua Cancel quá muộn rồi báo đã hủy ảnh được lưu. | NOT RUN | Không có runtime evidence đủ cho case này. | Chưa cancel trong one-shot frame/finalizer; không đua Cancel quá muộn rồi báo đã hủy ảnh được lưu. |
| T06-14 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Save/View URI hợp lệ. | PNG content URI đọc được, decode và View Photo preview qua assertion trước capture 2. | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_media_analysis.json](test_evidence/task_00_06/screenshot_media_analysis.json)<br>[screenshot_native_1_mediastore.txt](test_evidence/task_00_06/screenshot_native_1_mediastore.txt) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-15 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chạy harness/UI thật; định vị bằng UIAutomator, tap/swipe theo bounds; đọc native state, query/read đúng test URI; xem action/log/metadata đính kèm. | Ảnh xuất hiện trong Photo Library. | Photo Library cập nhật hai ảnh, View và feedback expiration qua assertions; video visibility cuối suite fail được ghi riêng. | PASS | [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt)<br>[screenshot_actions.json](test_evidence/task_00_06/screenshot_actions.json) | PASS chỉ trong phạm vi actual result đã mô tả; không suy rộng mọi OEM/Android version. |
| T06-16 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Tap Pause/Resume theo UIAutomator bounds; KEYCODE_HOME và am start để quay lại; để native auto-stop ở Home không gửi Stop; đọc journal, MediaStore, decode MP4 và kiểm temp cache đúng session. | Screenshot during Recording → Stop → MP4 hợp lệ. | Screenshot trong Recording/Paused bị UI disable; không tuyên bố chụp đồng thời. Có regression quay sau screenshot và MP4 dài hợp lệ. | UNSUPPORTED | [long_ui_recording.xml](test_evidence/task_00_06/long_ui_recording.xml)<br>[long_paused_1.xml](test_evidence/task_00_06/long_paused_1.xml)<br>[screenshot_video_mediastore.txt](test_evidence/task_00_06/screenshot_video_mediastore.txt) | Kết quả chỉ cho phiên và thiết bị đã thử; không thay thế đánh giá âm thanh hoặc fault injection. |
| T06-17 | Native failed bởi microphone permission denied; không inject ImageReader fault. | Tap Screenshot theo fresh hierarchy; xác nhận dialog MediaProjection thật; đưa own app về foreground trong 3s delay; đọc completed URI và decode đúng PNG test. | Screenshot lại sau lỗi. | Sau failed do audio permission denied, phiên screenshot mới completed, URI1000002325; PNG720×1456 published/decode hợp lệ. | PASS | [mic_deny_actual_native.json](test_evidence/task_00_06/mic_deny_actual_native.json)<br>[error_recovery_actions.json](test_evidence/task_00_06/error_recovery_actions.json)<br>[error_recovery_native.json](test_evidence/task_00_06/error_recovery_native.json)<br>[error_recovery_mediastore.txt](test_evidence/task_00_06/error_recovery_mediastore.txt)<br>[error_recovery_png_validation.json](test_evidence/task_00_06/error_recovery_png_validation.json)<br>[error_recovery.png](test_evidence/task_00_06/error_recovery.png) | PASS recovery sau permission error; không chứng nhận recovery sau ImageReader/encoder/storage fault. |
| T06-18 | Screenshot từ idle; consent mới; giữ toàn bộ file test. | Chưa thực hiện đầy đủ test case này. | Không leak ImageReader/VirtualDisplay sau khi đóng app. | Sau Stop có projection null/service none; chưa có heap/FD/ImageReader stress leak measurement. Không dùng một snapshot cleanup để khẳng định không leak. | NOT RUN | Không có runtime evidence đủ cho case này. | Sau Stop có projection null/service none; chưa có heap/FD/ImageReader stress leak measurement. Không dùng một snapshot cleanup để khẳng định không leak. |
| T06-19 | Screenshot completed có native dimensions và URI thật; process restart tự nhiên sau đổi quyền micro bằng Settings UI. | So sánh snapshot T06-07 shot 5 trước restart với capture_journal.xml sau restart; query MediaStore đúng test URI. | Replay cùng session/URI vẫn giữ width=720,height=1456. | Cùng ID 0f70ab5a-e678-452e-ac47-068576ad26f0 và URI 1000002323 nhưng root dimensions từ 720×1456 thành 0×0. MediaStore vẫn 720×1456; không mất file. | FAIL | [replay_screenshot_dimensions_failure.json](test_evidence/task_00_06/replay_screenshot_dimensions_failure.json)<br>[replay_screenshot_mediastore.txt](test_evidence/task_00_06/replay_screenshot_mediastore.txt)<br>[T06-07_repeated_screenshots.json](test_evidence/task_00_06/T06-07_repeated_screenshots.json) | Case bổ sung ngoài 92 cases yêu cầu. Owner P1, Medium. CaptureJournal không phục hồi root dimensions; chưa sửa code. |

### Bổ sung F12/F14 — Floating Controls (không cộng vào danh mục cases)

| Check | Actual | Verdict | Evidence |
|---|---|---|---|
| Geometry | Expanded 400×96 px = 200×48 dp; bubble 96×96 px = 48×48 dp; wrap×wrap thật. | UI/native verified | [overlay_dragged_window.txt](test_evidence/task_00_06/overlay_dragged_window.txt); [overlay_bubble_window.txt](test_evidence/task_00_06/overlay_bubble_window.txt) |
| Flags | APPLICATION_OVERLAY, TRANSLUCENT, NOT_FOCUSABLE/NOT_TOUCH_MODAL/HARDWARE_ACCELERATED, không FLAG_SECURE. Input flags không loại overlay khỏi video. | Runtime flags verified | [overlay_dragged_window.txt](test_evidence/task_00_06/overlay_dragged_window.txt) |
| Drag/collapse/timer | HH:MM:SS, kéo/snap và collapse/expand; chỉ status/timer/nút. | UI verified | [overlay_dragged.png](test_evidence/task_00_06/overlay_dragged.png); [overlay_bubble.png](test_evidence/task_00_06/overlay_bubble.png); [overlay_expanded_photo_library.png](test_evidence/task_00_06/overlay_expanded_photo_library.png) |
| Touch ngoài | Tap Photo ngoài bubble đổi sang Photo Library trong khi native cùng ID vẫn recording. | PASS path này | [overlay_outside_touch_action.json](test_evidence/task_00_06/overlay_outside_touch_action.json); [overlay_outside_touch_native.json](test_evidence/task_00_06/overlay_outside_touch_native.json) |
| Pause/Resume/Stop | Native xác nhận state; Stop paused finalize/publish và gỡ window sau completed. | Controls runtime verified | [overlay_pause_stop_actions.json](test_evidence/task_00_06/overlay_pause_stop_actions.json); [performance_mediastore.txt](test_evidence/task_00_06/performance_mediastore.txt); [overlay_cleanup.json](test_evidence/task_00_06/overlay_cleanup.json) |
| Không vùng đen trong MP4 có overlay | Không copy/inspect full clip sau privacy rejection. Metadata/UI không chứng minh pixel output. Không crop/vẽ đen để che lỗi. | BLOCKED / NOT VERIFIED frame-level acceptance | [media_privacy_retention.json](test_evidence/task_00_06/media_privacy_retention.json) |

## 4. Evidence Index

File gốc trên điện thoại được giữ. Hash/metadata/full-decode results không thay thế audio listening hoặc kiểm nội dung mọi frame. Clip privacy-risk không được giữ full-copy trong bộ bằng chứng.

| Evidence | Test linkage |
|---|---|
| [T02-01_mixed_consent.png](test_evidence/task_00_06/T02-01_mixed_consent.png) | T02-01 |
| [T02-01_mixed_consent.xml](test_evidence/task_00_06/T02-01_mixed_consent.xml) | T02-01 |
| [T02-01_mixed_consent_action.json](test_evidence/task_00_06/T02-01_mixed_consent_action.json) | T02-01 |
| [T02-03_action.json](test_evidence/task_00_06/T02-03_action.json) | T02-03, T05-05 |
| [T02-03_native_after_deny.json](test_evidence/task_00_06/T02-03_native_after_deny.json) | T02-03, T02-15, T05-05 |
| [T02-03_video_consent_denied.png](test_evidence/task_00_06/T02-03_video_consent_denied.png) | T02-03, T05-05 |
| [T02-03_video_consent_denied.xml](test_evidence/task_00_06/T02-03_video_consent_denied.xml) | T02-01 |
| [T02-03_video_ids_after_deny.txt](test_evidence/task_00_06/T02-03_video_ids_after_deny.txt) | T02-03 |
| [T06-07_repeated_screenshots.json](test_evidence/task_00_06/T06-07_repeated_screenshots.json) | T06-07, T06-19 |
| [T06-07_shot_1.png](test_evidence/task_00_06/T06-07_shot_1.png) | T06-07 |
| [T06-07_shot_1_mediastore.txt](test_evidence/task_00_06/T06-07_shot_1_mediastore.txt) | T06-07 |
| [T06-07_shot_2.png](test_evidence/task_00_06/T06-07_shot_2.png) | T06-07 |
| [T06-07_shot_2_mediastore.txt](test_evidence/task_00_06/T06-07_shot_2_mediastore.txt) | T06-07 |
| [T06-07_shot_3.png](test_evidence/task_00_06/T06-07_shot_3.png) | T06-07 |
| [T06-07_shot_3_mediastore.txt](test_evidence/task_00_06/T06-07_shot_3_mediastore.txt) | T06-07 |
| [T06-07_shot_4.png](test_evidence/task_00_06/T06-07_shot_4.png) | T06-07 |
| [T06-07_shot_4_mediastore.txt](test_evidence/task_00_06/T06-07_shot_4_mediastore.txt) | T06-07 |
| [T06-07_shot_5.png](test_evidence/task_00_06/T06-07_shot_5.png) | T06-07 |
| [T06-07_shot_5_mediastore.txt](test_evidence/task_00_06/T06-07_shot_5_mediastore.txt) | T06-07 |
| [advanced_initial.png](test_evidence/task_00_06/advanced_initial.png) | T00-07, T04-02/03/04/06; UI observations |
| [advanced_initial.xml](test_evidence/task_00_06/advanced_initial.xml) | T04-06 |
| [advanced_initial_nodes.json](test_evidence/task_00_06/advanced_initial_nodes.json) | T00-07, T04-02/03/04/06; UI observations |
| [advanced_scrolled1.xml](test_evidence/task_00_06/advanced_scrolled1.xml) | T04-06 |
| [advanced_scrolled2.xml](test_evidence/task_00_06/advanced_scrolled2.xml) | T00-07, T04-02/03/04/06; UI observations |
| [all_media_analysis.json](test_evidence/task_00_06/all_media_analysis.json) | T02-16, T03-11 |
| [cancel_actions.json](test_evidence/task_00_06/cancel_actions.json) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_apk.json](test_evidence/task_00_06/cancel_apk.json) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_attempt1_result.json](test_evidence/task_00_06/cancel_attempt1_result.json) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_build.log](test_evidence/task_00_06/cancel_build.log) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_cleanup_projection.txt](test_evidence/task_00_06/cancel_cleanup_projection.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_cleanup_service.txt](test_evidence/task_00_06/cancel_cleanup_service.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_countdown_consent.xml](test_evidence/task_00_06/cancel_countdown_consent.xml) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_external_interruption.txt](test_evidence/task_00_06/cancel_external_interruption.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_install.txt](test_evidence/task_00_06/cancel_install.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_launch.txt](test_evidence/task_00_06/cancel_launch.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_launch_retry.txt](test_evidence/task_00_06/cancel_launch_retry.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_logcat.txt](test_evidence/task_00_06/cancel_logcat.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_native_final.xml](test_evidence/task_00_06/cancel_native_final.xml) | T00-04, T02-15 |
| [cancel_pid.txt](test_evidence/task_00_06/cancel_pid.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_recording_consent.xml](test_evidence/task_00_06/cancel_recording_consent.xml) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_retry_actions.json](test_evidence/task_00_06/cancel_retry_actions.json) | T00-04, T05-03 |
| [cancel_retry_countdown_consent.xml](test_evidence/task_00_06/cancel_retry_countdown_consent.xml) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_retry_launch.txt](test_evidence/task_00_06/cancel_retry_launch.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt) | T00-04, T02-15, T03-12, T05-03 |
| [cancel_retry_paused_consent.xml](test_evidence/task_00_06/cancel_retry_paused_consent.xml) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_retry_pid.txt](test_evidence/task_00_06/cancel_retry_pid.txt) | T00-04, T02-15, T05-03; xem attempt result |
| [cancel_retry_recording_consent.xml](test_evidence/task_00_06/cancel_retry_recording_consent.xml) | T00-04, T02-15, T05-03; xem attempt result |
| [config_internal.mp4](test_evidence/task_00_06/config_internal.mp4) | T03-01–04/14, T04-01/05/15 |
| [config_internal_mediastore.txt](test_evidence/task_00_06/config_internal_mediastore.txt) | T03-01–04/14, T04-01/05/15 |
| [config_microphone.mp4](test_evidence/task_00_06/config_microphone.mp4) | T03-01–04/14, T04-01/05/15 |
| [config_microphone_mediastore.txt](test_evidence/task_00_06/config_microphone_mediastore.txt) | T03-01–04/14, T04-01/05/15 |
| [config_mixed.mp4](test_evidence/task_00_06/config_mixed.mp4) | T03-01–04/14, T04-01/05/15 |
| [config_mixed_mediastore.txt](test_evidence/task_00_06/config_mixed_mediastore.txt) | T03-01–04/14, T04-01/05/15 |
| [config_mute.mp4](test_evidence/task_00_06/config_mute.mp4) | T03-01, T04-05 |
| [config_mute_mediastore.txt](test_evidence/task_00_06/config_mute_mediastore.txt) | T03-01 |
| [configuration_apk_sha256.txt](test_evidence/task_00_06/configuration_apk_sha256.txt) | T03-01–04/14, T04-01/05/15 |
| [configuration_build.log](test_evidence/task_00_06/configuration_build.log) | T03-01–04/14, T04-01/05/15 |
| [configuration_install.txt](test_evidence/task_00_06/configuration_install.txt) | T03-01–04/14, T04-01/05/15 |
| [configuration_launch.txt](test_evidence/task_00_06/configuration_launch.txt) | T03-01–04/14, T04-01/05/15 |
| [configuration_logcat.txt](test_evidence/task_00_06/configuration_logcat.txt) | T03-14, T04-01, T04-09 |
| [configuration_media_analysis.json](test_evidence/task_00_06/configuration_media_analysis.json) | T02-14, T03-01, T03-09, T03-14, T04-01, T04-05, T04-09, T04-15 |
| [configuration_signer.txt](test_evidence/task_00_06/configuration_signer.txt) | T03-01–04/14, T04-01/05/15 |
| [controls.mp4](test_evidence/task_00_06/controls.mp4) | T02-05 |
| [controls_apk.json](test_evidence/task_00_06/controls_apk.json) | T02-05/07 |
| [controls_build.log](test_evidence/task_00_06/controls_build.log) | T02-05/07 |
| [controls_cleanup.txt](test_evidence/task_00_06/controls_cleanup.txt) | T02-05/07 |
| [controls_consent.png](test_evidence/task_00_06/controls_consent.png) | T02-05/07 |
| [controls_consent.xml](test_evidence/task_00_06/controls_consent.xml) | T02-05/07 |
| [controls_consent_actions.json](test_evidence/task_00_06/controls_consent_actions.json) | T02-05/07 |
| [controls_decode.json](test_evidence/task_00_06/controls_decode.json) | T02-05, T04-11, T04-15 |
| [controls_install.txt](test_evidence/task_00_06/controls_install.txt) | T02-05/07 |
| [controls_journal.xml](test_evidence/task_00_06/controls_journal.xml) | T02-05, T04-11, T05-06 |
| [controls_launch.txt](test_evidence/task_00_06/controls_launch.txt) | T02-05/07 |
| [controls_logcat.txt](test_evidence/task_00_06/controls_logcat.txt) | T02-05, T02-07 |
| [controls_mediastore.txt](test_evidence/task_00_06/controls_mediastore.txt) | T02-05/07 |
| [controls_pid.txt](test_evidence/task_00_06/controls_pid.txt) | T02-05/07 |
| [current_permissions.txt](test_evidence/task_00_06/current_permissions.txt) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [current_projection.txt](test_evidence/task_00_06/current_projection.txt) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [current_services.txt](test_evidence/task_00_06/current_services.txt) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [document_audit.json](test_evidence/task_00_06/document_audit.json) | T01-01, T01-02, T01-03, T01-04, T01-05, T01-06, T06-10 |
| [environment.json](test_evidence/task_00_06/environment.json) | T02-13 |
| [error_recovery.png](test_evidence/task_00_06/error_recovery.png) | T06-17 |
| [error_recovery_actions.json](test_evidence/task_00_06/error_recovery_actions.json) | T06-17 |
| [error_recovery_before.xml](test_evidence/task_00_06/error_recovery_before.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [error_recovery_consent.xml](test_evidence/task_00_06/error_recovery_consent.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [error_recovery_mediastore.txt](test_evidence/task_00_06/error_recovery_mediastore.txt) | T06-17 |
| [error_recovery_native.json](test_evidence/task_00_06/error_recovery_native.json) | T06-17 |
| [error_recovery_png_validation.json](test_evidence/task_00_06/error_recovery_png_validation.json) | T06-17 |
| [final_device_state.json](test_evidence/task_00_06/final_device_state.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_countdown5.xml](test_evidence/task_00_06/full_settings_countdown5.xml) | T05-02 |
| [full_settings_countdown_actions.json](test_evidence/task_00_06/full_settings_countdown_actions.json) | T05-02 |
| [full_settings_initial.xml](test_evidence/task_00_06/full_settings_initial.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_mute.xml](test_evidence/task_00_06/full_settings_mute.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_open_action.json](test_evidence/task_00_06/full_settings_open_action.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_scroll0.xml](test_evidence/task_00_06/full_settings_scroll0.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_scroll1.xml](test_evidence/task_00_06/full_settings_scroll1.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_scroll2.xml](test_evidence/task_00_06/full_settings_scroll2.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [full_settings_timer_current.xml](test_evidence/task_00_06/full_settings_timer_current.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [git_diff_check_final.txt](test_evidence/task_00_06/git_diff_check_final.txt) | T00-01/02; source freeze lượt này |
| [git_identity.txt](test_evidence/task_00_06/git_identity.txt) | T00-01 |
| [git_status_before.txt](test_evidence/task_00_06/git_status_before.txt) | T00-01, T00-02 |
| [git_status_current.txt](test_evidence/task_00_06/git_status_current.txt) | T00-01/02; source freeze lượt này |
| [host_logcat_cleanup.json](test_evidence/task_00_06/host_logcat_cleanup.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [installed_main_build_verified.json](test_evidence/task_00_06/installed_main_build_verified.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [landscape_before_stop.xml](test_evidence/task_00_06/landscape_before_stop.xml) | T05-10 |
| [landscape_consent.xml](test_evidence/task_00_06/landscape_consent.xml) | T04-08/10, T05-10 |
| [landscape_mediastore.txt](test_evidence/task_00_06/landscape_mediastore.txt) | T04-08, T04-10, T04-12, T05-10 |
| [landscape_native_completed.json](test_evidence/task_00_06/landscape_native_completed.json) | T04-10, T05-10, T05-15 |
| [landscape_native_recording.json](test_evidence/task_00_06/landscape_native_recording.json) | T04-08, T04-10, T04-12, T05-15 |
| [landscape_setup_actions.json](test_evidence/task_00_06/landscape_setup_actions.json) | T04-08/10, T05-10 |
| [landscape_start_actions.json](test_evidence/task_00_06/landscape_start_actions.json) | T04-08/10, T05-10 |
| [long_advanced_codec_actions.json](test_evidence/task_00_06/long_advanced_codec_actions.json) | T02-16, T03-11, T05-09/11 |
| [long_after_background.png](test_evidence/task_00_06/long_after_background.png) | T02-16, T03-11, T05-09/11 |
| [long_autostop_actions.json](test_evidence/task_00_06/long_autostop_actions.json) | T02-16, T03-11, T05-09/11 |
| [long_autostop_observations.json](test_evidence/task_00_06/long_autostop_observations.json) | T02-16, T05-09, T05-11, T05-15 |
| [long_background_return.json](test_evidence/task_00_06/long_background_return.json) | T02-08 |
| [long_before_background_deadline.json](test_evidence/task_00_06/long_before_background_deadline.json) | T05-11 |
| [long_cleanup_projection.txt](test_evidence/task_00_06/long_cleanup_projection.txt) | T03-12 |
| [long_cleanup_service.txt](test_evidence/task_00_06/long_cleanup_service.txt) | T03-12 |
| [long_consent.xml](test_evidence/task_00_06/long_consent.xml) | T02-16, T03-11, T05-09/11 |
| [long_enable_autostop_action.json](test_evidence/task_00_06/long_enable_autostop_action.json) | T02-16, T03-11, T05-09/11 |
| [long_frame_0.png](test_evidence/task_00_06/long_frame_0.png) | T02-16, T03-11, T05-09/11 |
| [long_frame_2115.png](test_evidence/task_00_06/long_frame_2115.png) | T02-16, T03-11, T05-09/11 |
| [long_frame_4229.png](test_evidence/task_00_06/long_frame_4229.png) | T02-16, T03-11, T05-09/11 |
| [long_mediastore.txt](test_evidence/task_00_06/long_mediastore.txt) | T02-16, T03-11, T04-08, T05-11 |
| [long_pause_resume_actions.json](test_evidence/task_00_06/long_pause_resume_actions.json) | T05-09 |
| [long_paused.png](test_evidence/task_00_06/long_paused.png) | T02-16, T03-11, T05-09/11 |
| [long_paused_1.xml](test_evidence/task_00_06/long_paused_1.xml) | T06-06, T06-16 |
| [long_paused_2.xml](test_evidence/task_00_06/long_paused_2.xml) | T06-06 |
| [long_portrait_scroll_action.json](test_evidence/task_00_06/long_portrait_scroll_action.json) | T02-16, T03-11, T05-09/11 |
| [long_recording_setup_basic_actions.json](test_evidence/task_00_06/long_recording_setup_basic_actions.json) | T02-16, T03-11, T05-09/11 |
| [long_recording_started.json](test_evidence/task_00_06/long_recording_started.json) | T04-08 |
| [long_retry_start_actions.json](test_evidence/task_00_06/long_retry_start_actions.json) | T02-16, T03-11, T05-09/11 |
| [long_return_after_autostop.txt](test_evidence/task_00_06/long_return_after_autostop.txt) | T02-16, T03-11, T05-09/11 |
| [long_start_actions.json](test_evidence/task_00_06/long_start_actions.json) | T02-16, T03-11, T05-09/11 |
| [long_start_states.json](test_evidence/task_00_06/long_start_states.json) | T02-16, T03-11, T05-09/11 |
| [long_temp_cleanup.json](test_evidence/task_00_06/long_temp_cleanup.json) | T03-12 |
| [long_ui_after_background.xml](test_evidence/task_00_06/long_ui_after_background.xml) | T02-08 |
| [long_ui_recording.png](test_evidence/task_00_06/long_ui_recording.png) | T02-16, T03-11, T05-09/11 |
| [long_ui_recording.xml](test_evidence/task_00_06/long_ui_recording.xml) | T06-05, T06-16 |
| [main_apk.json](test_evidence/task_00_06/main_apk.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_build.log](test_evidence/task_00_06/main_build.log) | T00-07, T04-02/03/04/06; UI observations |
| [main_home.png](test_evidence/task_00_06/main_home.png) | T00-07, T04-02/03/04/06; UI observations |
| [main_home.xml](test_evidence/task_00_06/main_home.xml) | T00-07, T04-02/03/04/06; UI observations |
| [main_home_nodes.json](test_evidence/task_00_06/main_home_nodes.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_install.txt](test_evidence/task_00_06/main_install.txt) | T00-07, T04-02/03/04/06; UI observations |
| [main_launch.txt](test_evidence/task_00_06/main_launch.txt) | T00-07, T04-02/03/04/06; UI observations |
| [main_library_scroll_action.json](test_evidence/task_00_06/main_library_scroll_action.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_library_scrolled.png](test_evidence/task_00_06/main_library_scrolled.png) | T00-07 |
| [main_library_scrolled.xml](test_evidence/task_00_06/main_library_scrolled.xml) | T00-07 |
| [main_library_scrolled_nodes.json](test_evidence/task_00_06/main_library_scrolled_nodes.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_logcat.txt](test_evidence/task_00_06/main_logcat.txt) | T00-07, T04-02/03/04/06; UI observations |
| [main_open_record_setup_action.json](test_evidence/task_00_06/main_open_record_setup_action.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_pid.txt](test_evidence/task_00_06/main_pid.txt) | T00-07, T04-02/03/04/06; UI observations |
| [main_return_top_action.json](test_evidence/task_00_06/main_return_top_action.json) | T00-07, T04-02/03/04/06; UI observations |
| [main_scrollables.json](test_evidence/task_00_06/main_scrollables.json) | T00-07, T04-02/03/04/06; UI observations |
| [media_privacy_retention.json](test_evidence/task_00_06/media_privacy_retention.json) | T02-16 |
| [mic_denied_final_app_info.xml](test_evidence/task_00_06/mic_denied_final_app_info.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_denied_final_options.xml](test_evidence/task_00_06/mic_denied_final_options.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_actual_action.json](test_evidence/task_00_06/mic_deny_actual_action.json) | T03-05 |
| [mic_deny_actual_native.json](test_evidence/task_00_06/mic_deny_actual_native.json) | T00-05, T03-05, T06-17 |
| [mic_deny_actual_ui.xml](test_evidence/task_00_06/mic_deny_actual_ui.xml) | T00-05, T03-05 |
| [mic_deny_actual_video_ids_after.txt](test_evidence/task_00_06/mic_deny_actual_video_ids_after.txt) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_confirm_current.xml](test_evidence/task_00_06/mic_deny_confirm_current.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_robust_0.xml](test_evidence/task_00_06/mic_deny_robust_0.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_robust_1.xml](test_evidence/task_00_06/mic_deny_robust_1.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_robust_2.xml](test_evidence/task_00_06/mic_deny_robust_2.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_robust_Record_screen.xml](test_evidence/task_00_06/mic_deny_robust_Record_screen.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_robust_selected.xml](test_evidence/task_00_06/mic_deny_robust_selected.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_runtime_Record_screen0.xml](test_evidence/task_00_06/mic_deny_runtime_Record_screen0.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_runtime_Start_Recording0.xml](test_evidence/task_00_06/mic_deny_runtime_Start_Recording0.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_runtime_actions.json](test_evidence/task_00_06/mic_deny_runtime_actions.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_runtime_after.xml](test_evidence/task_00_06/mic_deny_runtime_after.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_runtime_dialog.xml](test_evidence/task_00_06/mic_deny_runtime_dialog.xml) | T03-05 |
| [mic_deny_runtime_native.json](test_evidence/task_00_06/mic_deny_runtime_native.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [mic_deny_video_catalog_valid_after.txt](test_evidence/task_00_06/mic_deny_video_catalog_valid_after.txt) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [microphone_after_unlock_ui.xml](test_evidence/task_00_06/microphone_after_unlock_ui.xml) | T03-05, T00-05 |
| [microphone_app_info.xml](test_evidence/task_00_06/microphone_app_info.xml) | T03-05, T00-05 |
| [microphone_app_info_launch.txt](test_evidence/task_00_06/microphone_app_info_launch.txt) | T03-05, T00-05 |
| [microphone_denied_retry_start_actions.json](test_evidence/task_00_06/microphone_denied_retry_start_actions.json) | T03-05, T00-05 |
| [microphone_denied_setup_actions.json](test_evidence/task_00_06/microphone_denied_setup_actions.json) | T03-05, T00-05 |
| [microphone_denied_video_ids_before.txt](test_evidence/task_00_06/microphone_denied_video_ids_before.txt) | T03-05, T00-05 |
| [microphone_deny_setting_action.json](test_evidence/task_00_06/microphone_deny_setting_action.json) | T03-05, T00-05 |
| [microphone_open_microphone_action.json](test_evidence/task_00_06/microphone_open_microphone_action.json) | T03-05, T00-05 |
| [microphone_open_permissions_action.json](test_evidence/task_00_06/microphone_open_permissions_action.json) | T03-05, T00-05 |
| [microphone_permission_after_setting.txt](test_evidence/task_00_06/microphone_permission_after_setting.txt) | T03-05, T00-05 |
| [microphone_permission_after_setting.xml](test_evidence/task_00_06/microphone_permission_after_setting.xml) | T03-05, T00-05 |
| [microphone_permission_after_unlock.txt](test_evidence/task_00_06/microphone_permission_after_unlock.txt) | T03-05, T00-05 |
| [microphone_permission_options.xml](test_evidence/task_00_06/microphone_permission_options.xml) | T03-05, T00-05 |
| [microphone_permissions_before.xml](test_evidence/task_00_06/microphone_permissions_before.xml) | T03-05, T00-05 |
| [microphone_retry_unexpected_recording.json](test_evidence/task_00_06/microphone_retry_unexpected_recording.json) | T03-05, T00-05 |
| [microphone_retry_unexpected_stopped.json](test_evidence/task_00_06/microphone_retry_unexpected_stopped.json) | T03-05, T00-05 |
| [microphone_return_app.txt](test_evidence/task_00_06/microphone_return_app.txt) | T03-05, T00-05 |
| [native_current_while_locked.json](test_evidence/task_00_06/native_current_while_locked.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [output30.mp4](test_evidence/task_00_06/output30.mp4) | T02-04 |
| [output30_apk.json](test_evidence/task_00_06/output30_apk.json) | T02-04; direct-launch visual limitation |
| [output30_build.log](test_evidence/task_00_06/output30_build.log) | T02-04; direct-launch visual limitation |
| [output30_cleanup_projection.txt](test_evidence/task_00_06/output30_cleanup_projection.txt) | T02-04; direct-launch visual limitation |
| [output30_cleanup_service.txt](test_evidence/task_00_06/output30_cleanup_service.txt) | T02-04; direct-launch visual limitation |
| [output30_consent.png](test_evidence/task_00_06/output30_consent.png) | T02-04; direct-launch visual limitation |
| [output30_consent.xml](test_evidence/task_00_06/output30_consent.xml) | T02-04; direct-launch visual limitation |
| [output30_consent_action.json](test_evidence/task_00_06/output30_consent_action.json) | T02-04; direct-launch visual limitation |
| [output30_decoded_0.png](test_evidence/task_00_06/output30_decoded_0.png) | T02-04; direct-launch visual limitation |
| [output30_decoded_1.png](test_evidence/task_00_06/output30_decoded_1.png) | T02-04; direct-launch visual limitation |
| [output30_decoded_10.png](test_evidence/task_00_06/output30_decoded_10.png) | T02-04; direct-launch visual limitation |
| [output30_decoded_20.png](test_evidence/task_00_06/output30_decoded_20.png) | T02-04; direct-launch visual limitation |
| [output30_decoded_30.png](test_evidence/task_00_06/output30_decoded_30.png) | T02-04; direct-launch visual limitation |
| [output30_frame_10s.png](test_evidence/task_00_06/output30_frame_10s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_20s.png](test_evidence/task_00_06/output30_frame_20s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_2s.png](test_evidence/task_00_06/output30_frame_2s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_analysis.json](test_evidence/task_00_06/output30_frame_analysis.json) | T02-04, T04-15 |
| [output30_frame_near_10s.png](test_evidence/task_00_06/output30_frame_near_10s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_near_20s.png](test_evidence/task_00_06/output30_frame_near_20s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_near_28s.png](test_evidence/task_00_06/output30_frame_near_28s.png) | T02-04; direct-launch visual limitation |
| [output30_frame_near_2s.png](test_evidence/task_00_06/output30_frame_near_2s.png) | T02-04; direct-launch visual limitation |
| [output30_install.txt](test_evidence/task_00_06/output30_install.txt) | T02-04; direct-launch visual limitation |
| [output30_launch.txt](test_evidence/task_00_06/output30_launch.txt) | T02-04; direct-launch visual limitation |
| [output30_logcat.txt](test_evidence/task_00_06/output30_logcat.txt) | T02-04 |
| [output30_mediastore.txt](test_evidence/task_00_06/output30_mediastore.txt) | T02-04, T02-14 |
| [output30_native_completed.xml](test_evidence/task_00_06/output30_native_completed.xml) | T02-14 |
| [output30_native_recording.json](test_evidence/task_00_06/output30_native_recording.json) | T02-02, T04-01, T05-06 |
| [output30_pid.txt](test_evidence/task_00_06/output30_pid.txt) | T02-04; direct-launch visual limitation |
| [output30_projection_active.txt](test_evidence/task_00_06/output30_projection_active.txt) | T02-02 |
| [output30_screen_recording.png](test_evidence/task_00_06/output30_screen_recording.png) | T02-04; direct-launch visual limitation |
| [output30_service_active.txt](test_evidence/task_00_06/output30_service_active.txt) | T02-02 |
| [overlay_bubble.png](test_evidence/task_00_06/overlay_bubble.png) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_bubble_window.txt](test_evidence/task_00_06/overlay_bubble_window.txt) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_cleanup.json](test_evidence/task_00_06/overlay_cleanup.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_collapse_action.json](test_evidence/task_00_06/overlay_collapse_action.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_dragged.png](test_evidence/task_00_06/overlay_dragged.png) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_dragged_window.txt](test_evidence/task_00_06/overlay_dragged_window.txt) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_expand_action.json](test_evidence/task_00_06/overlay_expand_action.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_expanded_photo_library.png](test_evidence/task_00_06/overlay_expanded_photo_library.png) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_nodes.json](test_evidence/task_00_06/overlay_nodes.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_notification_observation.json](test_evidence/task_00_06/overlay_notification_observation.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_notification_scroll_actions.json](test_evidence/task_00_06/overlay_notification_scroll_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_notification_structure.json](test_evidence/task_00_06/overlay_notification_structure.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_outside_touch_action.json](test_evidence/task_00_06/overlay_outside_touch_action.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_outside_touch_native.json](test_evidence/task_00_06/overlay_outside_touch_native.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_outside_touch_photo_library.png](test_evidence/task_00_06/overlay_outside_touch_photo_library.png) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_outside_touch_photo_library.xml](test_evidence/task_00_06/overlay_outside_touch_photo_library.xml) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_pause_stop_actions.json](test_evidence/task_00_06/overlay_pause_stop_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_paused.png](test_evidence/task_00_06/overlay_paused.png) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_paused.xml](test_evidence/task_00_06/overlay_paused.xml) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_paused_nodes.json](test_evidence/task_00_06/overlay_paused_nodes.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_screenshot_resume_drag_actions.json](test_evidence/task_00_06/overlay_screenshot_resume_drag_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_show_actions.json](test_evidence/task_00_06/overlay_show_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [overlay_window_bounds.txt](test_evidence/task_00_06/overlay_window_bounds.txt) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_cleanup_projection.txt](test_evidence/task_00_06/performance_cleanup_projection.txt) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_cleanup_service.txt](test_evidence/task_00_06/performance_cleanup_service.txt) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_consent.xml](test_evidence/task_00_06/performance_consent.xml) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_mediastore.txt](test_evidence/task_00_06/performance_mediastore.txt) | T04-12 |
| [performance_native_recording.json](test_evidence/task_00_06/performance_native_recording.json) | T04-12, T05-15 |
| [performance_overlay_notification_actions.json](test_evidence/task_00_06/performance_overlay_notification_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_paused_before_notification.json](test_evidence/task_00_06/performance_paused_before_notification.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [performance_start_actions.json](test_evidence/task_00_06/performance_start_actions.json) | F12/F14 bổ sung, T04-12; full MP4 copy blocked |
| [record_setup_initial.png](test_evidence/task_00_06/record_setup_initial.png) | T04-02, T04-04 |
| [record_setup_initial.xml](test_evidence/task_00_06/record_setup_initial.xml) | T04-02, T04-03, T04-04 |
| [record_setup_initial_nodes.json](test_evidence/task_00_06/record_setup_initial_nodes.json) | T00-07, T04-02/03/04/06; UI observations |
| [replay_screenshot_dimensions_failure.json](test_evidence/task_00_06/replay_screenshot_dimensions_failure.json) | T06-19 |
| [replay_screenshot_mediastore.txt](test_evidence/task_00_06/replay_screenshot_mediastore.txt) | T06-19 |
| [report_validation.json](test_evidence/task_00_06/report_validation.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [screenshot_BACK_consent.xml](test_evidence/task_00_06/screenshot_BACK_consent.xml) | T06-04 |
| [screenshot_CAPTURE_1_consent.xml](test_evidence/task_00_06/screenshot_CAPTURE_1_consent.xml) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_CAPTURE_2_consent.xml](test_evidence/task_00_06/screenshot_CAPTURE_2_consent.xml) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_DENY_consent.xml](test_evidence/task_00_06/screenshot_DENY_consent.xml) | T06-04 |
| [screenshot_actions.json](test_evidence/task_00_06/screenshot_actions.json) | T05-01, T06-02, T06-15 |
| [screenshot_apk.json](test_evidence/task_00_06/screenshot_apk.json) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_build.log](test_evidence/task_00_06/screenshot_build.log) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_cleanup_projection.txt](test_evidence/task_00_06/screenshot_cleanup_projection.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_cleanup_service.txt](test_evidence/task_00_06/screenshot_cleanup_service.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_final_journal.xml](test_evidence/task_00_06/screenshot_final_journal.xml) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_install.txt](test_evidence/task_00_06/screenshot_install.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_launch.txt](test_evidence/task_00_06/screenshot_launch.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt) | T00-03, T00-07, T05-01, T06-02, T06-04, T06-14, T06-15 |
| [screenshot_media_analysis.json](test_evidence/task_00_06/screenshot_media_analysis.json) | T00-03, T06-01, T06-09, T06-14 |
| [screenshot_native_1.png](test_evidence/task_00_06/screenshot_native_1.png) | T06-09 |
| [screenshot_native_1_analysis.json](test_evidence/task_00_06/screenshot_native_1_analysis.json) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_native_1_mediastore.txt](test_evidence/task_00_06/screenshot_native_1_mediastore.txt) | T00-03, T06-01, T06-14 |
| [screenshot_native_2.png](test_evidence/task_00_06/screenshot_native_2.png) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_native_2_mediastore.txt](test_evidence/task_00_06/screenshot_native_2_mediastore.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_native_2_state.json](test_evidence/task_00_06/screenshot_native_2_state.json) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_pid.txt](test_evidence/task_00_06/screenshot_pid.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_return1_launch.txt](test_evidence/task_00_06/screenshot_return1_launch.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_return2_launch.txt](test_evidence/task_00_06/screenshot_return2_launch.txt) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_ui_nodes.json](test_evidence/task_00_06/screenshot_ui_nodes.json) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_video.mp4](test_evidence/task_00_06/screenshot_video.mp4) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_video_actions.json](test_evidence/task_00_06/screenshot_video_actions.json) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_video_consent.xml](test_evidence/task_00_06/screenshot_video_consent.xml) | T06-01/02/04/14/15; harness cuối FAIL |
| [screenshot_video_mediastore.txt](test_evidence/task_00_06/screenshot_video_mediastore.txt) | T06-16 |
| [secure_keyguard_blocker.json](test_evidence/task_00_06/secure_keyguard_blocker.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [settings_nav_actions.json](test_evidence/task_00_06/settings_nav_actions.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [settings_nav_before.xml](test_evidence/task_00_06/settings_nav_before.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [settings_root.xml](test_evidence/task_00_06/settings_root.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [source_before_sha256.json](test_evidence/task_00_06/source_before_sha256.json) | T00-01/02; source freeze lượt này |
| [source_freeze_check.json](test_evidence/task_00_06/source_freeze_check.json) | T00-01/02; source freeze lượt này |
| [source_freeze_final.json](test_evidence/task_00_06/source_freeze_final.json) | T00-01/02; source freeze lượt này |
| [source_freeze_interim.json](test_evidence/task_00_06/source_freeze_interim.json) | T00-02 |
| [test_cases.json](test_evidence/task_00_06/test_cases.json) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_Record_screen.xml](test_evidence/task_00_06/timer30_Record_screen.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_Start_Recording.xml](test_evidence/task_00_06/timer30_Start_Recording.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_Video.xml](test_evidence/task_00_06/timer30_Video.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_actions.json](test_evidence/task_00_06/timer30_actions.json) | T05-02, T05-07 |
| [timer30_back1.xml](test_evidence/task_00_06/timer30_back1.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_consent.xml](test_evidence/task_00_06/timer30_consent.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_decode_validation.json](test_evidence/task_00_06/timer30_decode_validation.json) | T05-07 |
| [timer30_dialog.xml](test_evidence/task_00_06/timer30_dialog.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_edited.xml](test_evidence/task_00_06/timer30_edited.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_final_native.json](test_evidence/task_00_06/timer30_final_native.json) | T05-07 |
| [timer30_frame_0.png](test_evidence/task_00_06/timer30_frame_0.png) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_frame_100.png](test_evidence/task_00_06/timer30_frame_100.png) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_frame_200.png](test_evidence/task_00_06/timer30_frame_200.png) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_mediastore.txt](test_evidence/task_00_06/timer30_mediastore.txt) | T05-07 |
| [timer30_own_app.mp4](test_evidence/task_00_06/timer30_own_app.mp4) | T05-07 |
| [timer30_setting_before.xml](test_evidence/task_00_06/timer30_setting_before.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer30_settings_actions.json](test_evidence/task_00_06/timer30_settings_actions.json) | T05-07 |
| [timer30_timeline.json](test_evidence/task_00_06/timer30_timeline.json) | T05-02, T05-07 |
| [timer60_Audio.xml](test_evidence/task_00_06/timer60_Audio.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_Record_screen.xml](test_evidence/task_00_06/timer60_Record_screen.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_Settings.xml](test_evidence/task_00_06/timer60_Settings.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_Start_Recording.xml](test_evidence/task_00_06/timer60_Start_Recording.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_Video.xml](test_evidence/task_00_06/timer60_Video.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_actions.json](test_evidence/task_00_06/timer60_actions.json) | T05-08 |
| [timer60_consent.xml](test_evidence/task_00_06/timer60_consent.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_decode_validation.json](test_evidence/task_00_06/timer60_decode_validation.json) | T05-08 |
| [timer60_dialog.xml](test_evidence/task_00_06/timer60_dialog.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_edited.xml](test_evidence/task_00_06/timer60_edited.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_final_native.json](test_evidence/task_00_06/timer60_final_native.json) | T05-08 |
| [timer60_mediastore.txt](test_evidence/task_00_06/timer60_mediastore.txt) | T05-08 |
| [timer60_own_app.mp4](test_evidence/task_00_06/timer60_own_app.mp4) | T05-08 |
| [timer60_settings_scroll0.xml](test_evidence/task_00_06/timer60_settings_scroll0.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_settings_scroll1.xml](test_evidence/task_00_06/timer60_settings_scroll1.xml) | Supporting environment/report data, không phải runtime PASS độc lập. |
| [timer60_timeline.json](test_evidence/task_00_06/timer60_timeline.json) | T05-08 |
| [unsupported_after.png](test_evidence/task_00_06/unsupported_after.png) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_after.xml](test_evidence/task_00_06/unsupported_after.xml) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_after_journal.xml](test_evidence/task_00_06/unsupported_after_journal.xml) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_after_video_ids.txt](test_evidence/task_00_06/unsupported_after_video_ids.txt) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_before_journal.xml](test_evidence/task_00_06/unsupported_before_journal.xml) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_before_video_ids.txt](test_evidence/task_00_06/unsupported_before_video_ids.txt) | T00-07, T04-02/03/04/06; UI observations |
| [unsupported_start_action.json](test_evidence/task_00_06/unsupported_start_action.json) | T00-07, T04-02/03/04/06; UI observations |

## 5. Critical Bugs / Test Failures

Chưa quan sát recording crash hoặc mất media đã publish trong các phiên đã chạy; không suy thành không có lỗi trên mọi driver/fault path.

### QA-01 — Cancel suite FAIL do active SemanticsHandle

- Severity: Medium (test infrastructure); Owner: P1 QA/Flutter integration tests.
- Repro: chạy existing cancel harness trên OPPO; consent/UIAutomator và bốn trạng thái cancel.
- Expected: functional assertions và end-of-test verifications đều green.
- Actual: đi hết functional assertions, native idle/output null; cuối test framework báo A SemanticsHandle was active at the end of the test. Chưa isolate root cause engine hay tương tác UIAutomation/accessibility.
- Evidence: [cancel_retry_logcat.txt](test_evidence/task_00_06/cancel_retry_logcat.txt), [cancel_retry_actions.json](test_evidence/task_00_06/cancel_retry_actions.json), [cancel_native_final.xml](test_evidence/task_00_06/cancel_native_final.xml). Không sửa test/source.

### QA-02 — Screenshot regression suite timeout chờ video row

- Severity: Medium (test reliability / Capture→Library regression); Owner: P1 QA, phối hợp P2 Media Library nếu isolate thành product issue.
- Repro: screenshot_native_test.dart với preserve outputs; hai ảnh/View rồi video pause/resume/save.
- Expected: finder thấy video row sau save.
- Actual: timeout host resume or visible catalog update tại line 197. MP4 native completed/published. Main app scroll cho thấy đúng video dưới fold. Bằng chứng phù hợp với lazy viewport/visibility; không chứng minh mất Saved callback/catalog.
- Evidence: [screenshot_logcat.txt](test_evidence/task_00_06/screenshot_logcat.txt), [screenshot_video_mediastore.txt](test_evidence/task_00_06/screenshot_video_mediastore.txt), [main_library_scrolled.xml](test_evidence/task_00_06/main_library_scrolled.xml), [main_library_scrolled.png](test_evidence/task_00_06/main_library_scrolled.png).

### P1-01 — Screenshot replay mất kích thước sau process restart

- Severity: Medium; Owner: P1 native session/journal và Dart adapter.
- Repro: lưu screenshot, xác nhận native completed 720×1456; đổi quyền micro qua Settings khiến process restart, mở lại app và đọc journal cùng session/URI.
- Expected: replay giữ nguyên dimensions của ảnh đã lưu.
- Actual: cùng session/URI nhưng root width/height chuyển từ 720×1456 sang 0×0; MediaStore vẫn 720×1456, PNG không bị hỏng. Đây là lỗi metadata replay, không phải mất file.
- Source đọc để đối chiếu: CaptureJournal.kt:20–35 không phục hồi root width/height trước save; recording_service.dart:22,35–37 dùng root screenshot dimensions, giá trị 0 không kích hoạt null fallback. Không sửa source.
- Evidence: [replay_screenshot_dimensions_failure.json](test_evidence/task_00_06/replay_screenshot_dimensions_failure.json), [replay_screenshot_mediastore.txt](test_evidence/task_00_06/replay_screenshot_mediastore.txt). T06-19 là case bổ sung ngoài 92 cases yêu cầu.

### OBS-01 — Actual FPS khác target; cần motion benchmark

- Target 30; clip 5 phút average 14.085 samples/s, có decode delta lớn. Không chứng nhận CFR hoặc frame-drop rate trên cảnh chuyển động.
- Không đổi encoder/FPS/bitrate để che hiện tượng; cần cảnh chuyển động/timestamp chuẩn và thermal/performance measurement. Owner P1 capture.
- Evidence: [all_media_analysis.json](test_evidence/task_00_06/all_media_analysis.json).

### OBS-02 — Pillarbox trong mẫu Portrait screen → Landscape canvas

- Frame0/100/200 của timer30 own-app cho thấy nội dung màn hình dọc giữ trọn trong canvas1280×720, có hai dải đen ở hai bên. Đây là hình học fit-aspect quan sát được trong mẫu không có floating window; không phải bằng chứng xác định nguyên nhân rectangle của clip overlay.
- Evidence: [timer30_frame_0.png](test_evidence/task_00_06/timer30_frame_0.png), [timer30_frame_100.png](test_evidence/task_00_06/timer30_frame_100.png), [timer30_frame_200.png](test_evidence/task_00_06/timer30_frame_200.png). Không crop hoặc sửa pixel output.

## 6. UI Regression Findings

| Screen / component | Hiện trạng | Reference / Owner / đề xuất |
|---|---|---|
| Home/Recording Setup | Ban đầu 1080p/60/Mixed vẫn highlight dù chips unsupported bị disabled; Start enabled. Tap không thêm output; không chứng minh fake save. | [record_setup_initial.png](test_evidence/task_00_06/record_setup_initial.png); [unsupported_after.png](test_evidence/task_00_06/unsupported_after.png). P1 settings/capture + P2 khi cần shared UI: review normalize/validation/feedback. Không sửa. |
| Video Library | Video row dưới fold sau card/filters, thấy sau scroll. | [main_library_scrolled.png](test_evidence/task_00_06/main_library_scrolled.png). P1 QA dùng scroll-to-target; P2 chỉ khi cần đổi layout. |
| Floating controls | Compact/bubble/touch ngoài hoạt động; không window rỗng lớn khi collapse. | [overlay_dragged.png](test_evidence/task_00_06/overlay_dragged.png); [overlay_bubble.png](test_evidence/task_00_06/overlay_bubble.png). Không đổi icon/source. |
| Navigation | Video→Photo qua nút ngoài bubble thực sự đổi trang và session tiếp tục. | [overlay_outside_touch_photo_library.xml](test_evidence/task_00_06/overlay_outside_touch_photo_library.xml). Chỉ path đã thử. |
| UI/icon freeze | Không sửa file có sẵn; 536 hashes được đối chiếu. Không có baseline thiết kế lịch sử cho mọi screen/icon của các task trước. | Source-freeze evidence; không redesign/Stitch/icon mới. |

## 7. Completion Assessment

| Task | PASS | FAIL | BLOCKED | NOT RUN | UNSUPPORTED / N/A | Assessment |
|---|---|---|---|---|---|---|
| 00 | 5 | 0 | 0 | 2 | 0 / 0 | PARTIAL — contract/output/Library có evidence, event exactly-once và owner confirmation chưa đủ. |
| 01 | 6 | 0 | 0 | 1 | 0 / 0 | NEEDS VERIFICATION — đủ tài liệu/matrix/risk/next tasks; thiếu checksum lịch sử riêng cho freeze của Task 01. |
| 02 | 10 | 0 | 0 | 5 | 1 / 0 | PARTIAL — sessions/5 phút/Pause/Stop đã thử; lifecycle/revoke/rotation/recreation còn thiếu. |
| 03 | 5 | 0 | 0 | 8 | 1 / 0 | PARTIAL — Mute/AAC/runtime modes có evidence; đúng nguồn/gain/A-V/stereo chưa hoàn tất. |
| 04 | 9 | 0 | 0 | 3 | 3 / 0 | PARTIAL — 720p/AVC/canvas/policy đã thử; high res/HEVC không advertise, motion/performance còn thiếu. |
| 05 | 11 | 0 | 0 | 4 | 0 / 0 | PARTIAL — native countdown/active-duration/auto-stop có evidence; case chưa chạy xem bảng. |
| 06 | 9 | 1 | 0 | 6 | 3 / 0 | PARTIAL — PNG/View/Library/repeated shots có evidence; replay metadata 0×0 FAIL; concurrent shot không hỗ trợ; rotation/fault/leak còn thiếu. |

Không tính UNSUPPORTED/N/A/BLOCKED/NOT RUN là PASS, không đánh dấu DONE chỉ từ count. Case PASS và harness FAIL được báo riêng.

## 8. Recommended Fix / Verification Order

1. Sửa P1-01 metadata replay screenshot (0×0) trong task triển khai riêng; thêm kiểm tra replay qua process restart. Giữ crash/data loss là ưu tiên; chưa thấy trong sample. Chạy safe init/storage/lifecycle fault hooks khi có, không fill storage hoặc làm mất media.
2. Kiểm tiếp OS revoke, queued consent, rotation và Activity recreation thật trên API30; không suy Android14 app-window.
3. Dùng nguồn audio test được phép và nghe/đo waveform/clipping/A-V sync trước/sau pause/background. Stereo còn thiếu schema/implementation theo IR-03-01.
4. Benchmark motion/PTS/actual FPS/bitrate; phân biệt configured target với output thực, không tự đổi engine trong QA.
5. Chốt countdown/custom-duration/terminal-race còn NOT RUN bằng UI/hook có sẵn; không thêm timer/controller/framework.
6. Screenshot rotation/cancel-frame/timeout/leak/storage-safe hooks sau khi isolate QA-01/QA-02 để suite không báo xanh giả.
7. Review unsupported-selected settings và scroll finder. Chỉ sửa trong task triển khai riêng đúng owner P1/P2; không redesign.

### Các lượt xác minh tiếp theo còn cần thiết

- Audio source/listening: dùng nguồn tone/video test được phép, không phát nội dung riêng tư. Chạy từng mode rồi pause3s/resume, nghe headphone và so sánh waveform/marker hình-âm; hiện chưa có tín hiệu tham chiếu được kiểm soát hoặc AAC decoder nên không xác nhận đúng nguồn/gain/A-V sync.
- Overlay pixels: cần một phiên mới với màn hình test không có dữ liệu cá nhân; bật/tắt controls theo consent rõ ràng, ghi10–15s, kéo control, dừng; chỉ khi full output được phép truy cập mới trích nhiều frame và đối chiếu vị trí cũ/mới với baseline không overlay. Không dùng crop, FLAG_SECURE hoặc vẽ đen để loại control. Clip2318 hiện giữ metadata-only sau rejection.
- Lock/revoke/recreation/rotation: chuẩn bị màn hình và notification không có dữ liệu cá nhân; thực hiện từng thay đổi riêng, ghi session ID/elapsed trước-sau, dừng qua native path rồi kiểm MP4. Không tự thay system rotation/security settings hoặc suy API34+ từ máy API30.
- Fault/leak: chỉ dùng hook an toàn đã được cung cấp; chưa có hook phù hợp để inject storage/encoder/ImageReader faults. Không làm đầy bộ nhớ, xóa media hoặc sửa source để tạo test.

### Build và kiểm tra cuối

- Các APK debug/native Gradle đã build để chạy existing harness và main entrypoint; xem build logs. Không sửa Dart nên không chạy flutter analyze cho một diff Dart mới; các lỗi harness được báo nguyên trạng.
- git diff --check kết thúc exit0; 536 file baseline không đổi/không mất; report links và whitespace được kiểm bằng [report_validation.json](test_evidence/task_00_06/report_validation.json).
- Microphone cuối lượt bị denied/USER_FIXED do chọn đúng nút từ chối system dialog. Muốn dùng micro ở lượt triển khai sau phải bật lại bằng App Settings hoặc luồng quyền hợp lệ; test không dùng pm grant. Không thay hệ thống bảo mật hoặc xóa app data.

## 9. Final Conclusion

- Có kiểm thử trực tiếp Android thật, có native state, output MP4/PNG thật và media validation. Không dùng screenshot UI để thay chứng minh native engine.
- Recording/PNG và nhiều session flows đã có evidence; không đủ nghiệm thu toàn bộ engine/release hoặc đánh dấu Task 00–06 DONE. Hai harness FAIL vẫn được giữ nguyên.
- Không cập nhật Google Sheets. Task01 đủ nội dung audit, nhưng history freeze tách khỏi source freeze của lượt verification này.
- Không cần P2 sửa Manifest/MainActivity từ kết quả test này. Existing IR-00-01 ownership, IR-00-02 shared stop/cancel docs, IR-03-01 stereo vẫn theo bàn giao; P2 phối hợp Library chỉ nếu isolate QA-02 thành product issue.
- Đã khôi phục main APK và đối chiếu hash cài đặt: [installed_main_build_verified.json](test_evidence/task_00_06/installed_main_build_verified.json). Trạng thái thiết bị kết thúc và source freeze: [final_device_state.json](test_evidence/task_00_06/final_device_state.json), [source_freeze_final.json](test_evidence/task_00_06/source_freeze_final.json).

- Các thao tác thường/consent đã tự động hóa sau khi được phép. Audio source/listening và lockscreen/privacy setup mới cần người dùng. Case thiếu safe hook ghi NOT RUN.
- Trạng thái cuối: main APK đúng hash, native completed, CaptureService/projection/overlay không còn hoạt động. UI test preferences còn Performance720p30AVC8Mbps/Mute/Landscape/countdown5s/auto-stop60s; micro denied, camera không đổi. Xem final_device_state.json.

- Không reset Git, uninstall, clear data, xóa media thiết bị, sửa source/UI/icon, livestream, commit/push hoặc tích Sheets. Recording options và quyền micro được thao tác UI phục vụ test; xem trạng thái cuối và actions.
- Auto-review từ chối full MP4 overlay copy do nguy cơ notification/private screen content. Không bypass; clip giữ trên điện thoại, metadata-only. Frame-level kết luận overlay không gây rectangle đen trong MP4 vẫn BLOCKED / NOT VERIFIED.
