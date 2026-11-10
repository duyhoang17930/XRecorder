# TASK UI/UX 02B — Recovery & Final Visual QA Follow-up

**Trạng thái: PARTIAL / BLOCKED cho runtime QA.** Bottom navigation đã được làm gọn theo screenshot reference; không có APK mới, test PASS mới, screenshot/video sau patch hoặc visual parity claim.

## Toolchain recovery audit — chỉ đọc

- Repo HEAD: `64e84ec0f952c4e28063488812933010f05bfa7d`, branch `main`. Giữ nguyên dirty/untracked work từ UI/UX 01/02/02B và các sửa đổi người dùng; không commit/push/restore/reset/clean.
- Flutter cache metadata nhận diện Flutter **3.47.8 stable**, Dart **3.13.7**. Flutter SDK files và `flutter_tools.snapshot` tồn tại; không có dấu hiệu file SDK thiếu qua metadata.
- Dart processes: PID 12444 có path `D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe`, system StartTime `09:33`, SessionId 1, cumulative CPU khoảng 93 giây, working set khoảng 283 MB; thread query cho thấy các luồng đang Wait. PIDs 12092, 29788, 30580 cũng là Dart cùng session với working set nhỏ.
- Owner query bằng Get-Process -IncludeUserName yêu cầu quyền elevated. Win32_Process query bị Access denied nên không biết parent PID, command line, owner hay file handle. Không thể xác định chắc tiến trình nào thuộc workstream khác; không dừng process và không restart Windows.
- Flutter cache có hai marker rỗng: `flutter.bat.lock` (last write 13:49:21) và `lockfile` (13:49:22). Không chứng minh được chúng đang bị lock bởi PID nào; không mở khóa/xóa marker. Không thấy log flutter-*.txt trong Temp khi tìm theo tên. `dart-sdk.old1` có timestamp cũ từ 2026-04; không đủ bằng chứng là nguyên nhân.
- Kết luận root cause: **chưa xác định**. Bằng chứng phù hợp với Flutter/Dart process hoặc SDK cache contention, nhưng owner/parent/lock handle bị giới hạn quyền; không suy đoán thành kết luận.
- Required action để recovery: chủ process hoặc quản trị viên xác định parent/owner/lock handle và chỉ giải phóng process sau khi xác nhận không thuộc tác vụ đang chạy. Sau đó chạy Flutter CLI tuần tự. Không yêu cầu xóa cache/build hoặc khởi động lại Windows.

## Source DocumentApp

Đã thử path `D:\FAU_App\DocumentApp\document_app`; không tồn tại. Read-only directory listing của `D:\FAU_App` chỉ thấy XRecorder và artifacts. Vì vậy không kiểm tra source widget, tokens, animations, renderer, route state hoặc license trong DocumentApp. Đã triển khai adaptation dựa trên ảnh người dùng gửi và target code; chi tiết ở [BOTTOM_NAV_DOCUMENTAPP_PORT_REPORT.md](BOTTOM_NAV_DOCUMENTAPP_PORT_REPORT.md). Không sửa DocumentApp.

## Thay đổi UI sau checkpoint trước

- Navigation height token giảm 76→56 dp; vùng tab vẫn tối thiểu 48×56 dp.
- Create button vẫn 52 dp, nằm ngoài capsule; bỏ nhãn hiển thị phụ bên dưới nhưng giữ Tooltip và semantic label.
- Glass surface/border/shadow nhẹ hơn; blur sigma 10 vẫn giới hạn bởi ClipRRect, không có nền strip bên ngoài.
- Pill selection 260 ms; icon/label 180 ms; cả hai duration bằng zero khi Reduce Motion.
- StudioShell import trực tiếp các tokens/icons/colors/typography đang dùng. Không thay router, 4 indices, `goBranch`, Create callback, branch state, scroll-to-top hay app business logic.
- Thêm layout widget coverage 320/360/393/411 dp, RTL, Light/Dark, text scale 2, pill bounds/hit targets/Create và Reduce Motion. Chưa chạy.

## Kết quả kiểm tra

| Kiểm tra | Kết quả lượt follow-up |
|---|---|
| `dart format ...` | Không hoàn tất. Phiên không trả output sau 60 giây; Ctrl+C kết thúc shell với exit 1. Dart PID 12444 vẫn còn. |
| `flutter analyze --no-pub` | Chưa chạy lại; lượt trước đó không trả output trong 30.9 giây. |
| Focused widget/navigation tests | Chưa chạy sau patch. Existing reselect tests vẫn có trong source. |
| Android APK build | Chưa chạy; không cài APK cũ thay cho code mới. |
| Android AVD screenshot/video | Chưa chụp/quay sau patch. Không thay đổi app/user data. |
| `git diff --check` | PASS ở lượt trước; chỉ có cảnh báo line-ending đã có ở `studio_shell.dart`. Cần chạy lại sau patch khi toolchain/environment được giải phóng. |

### Visual evidence

- [Reference DocumentApp](../implementation/UI/bottom_navigation.png)
- [Target AVD Dark trước patch](../implementation/TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_videos_dark_after_onboarding.png)
- Không có ảnh/video sau patch. `nav_videos_dark_final.png` được loại khỏi so sánh vì file chứa màn Smart Subtitles thay vì Videos.
- Splash recording và onboarding screenshot hiện có là evidence lịch sử UI/UX 02, không phải APK follow-up này. Không tạo ảnh/video giả lập.

## Theme/data/P1 handoff

- Default theme mới vẫn **WAITING FOR P1 APPROVAL**: SettingsController default Dark; Android splash resources theo system theme nên có thể lệch với preference Light/Dark. Không đổi settings semantics/default hoặc shared native initialization.
- P1 boundary: PRESERVED. Không sửa MainActivity trong follow-up, recording/capture/settings/permissions, media/export, editor hay TASK10. MainActivity vẫn có dirty changes cũ từ UI/UX 01/02.
- Data: PASS. Chỉ read-only query AVD `emulator-5570` để xác nhận AVD `ThreeHRecorder_TASK09B_API36` và Owner user. Không gửi lệnh tới 5554/QA5560, không cài, clear data, reboot hay đổi system theme.
- Files: không xóa. Refactor imports/metrics là trong scope; không có file nào được chứng minh unused mà an toàn xóa. Existing QA evidence và dirty files được giữ nguyên.
- Storage: không tạo build, screenshot, video hoặc fixture mới trong follow-up. Report mới là text nhỏ; build folder và dung lượng ổ không được quét lại.

## Việc cần thiết để đóng task

1. Chủ sở hữu/admin giải phóng hoặc xác minh Dart process/cache lock an toàn.
2. Người dùng cung cấp DocumentApp project ở path đọc được hoặc xác nhận adaptation theo screenshot là đủ.
3. Chạy format, analyzer, nav/onboarding focused tests, build APK; kiểm thử trên emulator-5570 đã được xác nhận mà không xóa data.
4. Chụp Light/Dark screenshots, kiểm tra 4 tabs/Create/keyboard/reselect/layout/Reduce Motion, và quay trọn splash từ first frame đến complete 3H Recorder.

Không commit/push. Không bắt đầu UI/UX 03 hoặc TASK10.
