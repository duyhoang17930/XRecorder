# TASK UI/UX 02 - Consolidated historical report

Merged on 2026-11-11 from the four original reports. Historical statuses and limitations are preserved; these are not validation results for the current source. Device-private backups remain local and Git-ignored.

[Summary](#summary) | [Visual QA](#visual-qa) | [Tests](#tests) | [Storage](#storage)

<a id="summary"></a>

﻿# TASK UI/UX 02 — Báo cáo cuối

**Kết quả: PARTIAL.** Onboarding đã được triển khai và kiểm tra trực tiếp trên AVD. Các lỗi UI phát hiện trong lúc chạy thật đã được sửa. Splash và navigation đã được quan sát trên Android, nhưng còn một sai khác theme ở splash cần tích hợp riêng.

### Đã triển khai

- Ba màn onboarding với hình minh họa `CustomPainter`, chuyển trang ngang, Skip/Back/Next/Get Started, chỉ báo tiến độ và chuyển động có giới hạn.
- Lưu trạng thái hoàn thành bằng Android preferences riêng cho onboarding; không thêm trường vào tài liệu Settings phiên bản 2 và không đổi mặc định/thao tác ghi hình.
- Người dùng hiện hữu được bỏ qua onboarding trong thử nghiệm migration; người dùng mới có thể tiếp tục lại trang chưa hoàn tất sau khi mở lại app.
- Thêm chuỗi bản địa hóa vào 14 ARB hiện có, hỗ trợ RTL, cỡ chữ lớn và Reduce Motion trong kiểm thử widget.
- Tạo splash Android vector 3H vẽ số 3 trước H. Không thêm thời gian chờ bắt buộc; Android tự chuyển khi Flutter vẽ frame đầu.
- Kiểm tra trực tiếp Video, Photo, Edit, Settings và Create trên AVD `ThreeHRecorder_TASK09B_API36` (`emulator-5570`).

### Kiểm tra và bảo toàn

- Analyzer và 14 focused onboarding/startup/navigation tests đã PASS ở lượt cuối sau khi sửa Dart. Build Android x64 debug và cài cập nhật lên AVD QA cũng PASS.
- Lần cold start cuối trên AVD mất khoảng **7,908 ms** tới Flutter first frame; đây là phép đo emulator, không phải delay được cài trong app. Warm resume đo **95 ms** và mở lại thẳng Video Library, không lặp onboarding.
- `p2_locale.xml` giữ nguyên SHA-256 `87bf0345b0fdb43f7551ff7b4224828423b9c18b99e18950de9c54b41166a481`. Trạng thái onboarding riêng được xác nhận `completed=true`, `page=2`.
- Giữ lại 5 snapshot dữ liệu ứng dụng QA trước các lần cài cập nhật. Không xóa dữ liệu, không chạy capture, không thao tác QA5560 hoặc emulator 5554.
- `MainActivity.kt` chỉ được bổ sung đăng ký/dọn method channel onboarding; phần capture, recording, permission và request code không đổi. Không commit/push; các thay đổi ban đầu của TASK UI/UX 01 được giữ nguyên.

### Còn hạn chế

Native Android splash lấy sáng/tối từ chế độ giao diện hệ thống, trong khi app lưu lựa chọn theme riêng. AVD đang ở system Light nhưng app Dark nên splash sáng chuyển sang app tối. Sửa để splash đọc theme riêng cần thay đổi đường khởi tạo native dùng chung; phần đó chưa được sửa để giữ ranh giới P1. Reduce Motion được kiểm tra tự động, chưa xác nhận bằng thao tác TalkBack hoặc cài đặt hệ thống trên AVD. Light mode, RTL và scale 2.0 được kiểm tra bằng widget/layout tests, chưa được xác nhận trực tiếp trên thiết bị.

### Trạng thái chấp nhận

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Onboarding | PASS | Ba trang, tương tác, persistence, resume, migration và kiểm tra giao diện Android |
| Splash visual QA | PARTIAL | Đã thấy 3 rồi H; cold first frame chậm trên AVD và có lệch theme system/app |
| Navigation visual QA | PARTIAL | Bốn tab và Create đã kiểm tra trên Android Dark; Light/keyboard chưa kiểm tra trực tiếp |
| Global UX | PARTIAL | 14 locale và layout đặc biệt có automated coverage; chưa có human TalkBack acceptance |
| Tests | PASS | Analyzer và focused suite 14/14 trước thay đổi chỉ gồm tài nguyên Android; native build PASS |
| P1 boundary | PRESERVED | Không sửa capture/recording/settings semantics |
| Data preservation | PASS | Snapshot trước cài, onboarding tách biệt, hash locale không đổi |
| TASK10 | NOT STARTED | Không triển khai tích hợp TASK10 |

Chi tiết ảnh và phép đo nằm trong [Visual QA](#visual-qa), [Test Evidence](#tests), [Storage](#storage) và thư mục [evidence](TASK_UI_UX_02_EVIDENCE_20261110_121400/).

---

<a id="visual-qa"></a>

﻿# TASK UI/UX 02 — Visual QA

### Thiết bị và giới hạn

- AVD: `ThreeHRecorder_TASK09B_API36`, serial `emulator-5570`, độ phân giải ảnh 410×916. Đã xác nhận đây không phải QA5560 hoặc emulator cá nhân 5554.
- App đang dùng theme Dark; system theme của AVD là Light. Không cài thêm AVD và không xóa app/data.
- Ảnh dưới đây được mở xem trực tiếp. Video ngắn được ghi để lưu trace thao tác; không dùng video để khẳng định FPS.

### Onboarding

| Màn | Quan sát thực tế | Kết quả |
|---|---|---|
| Record Anything | Khung điện thoại/REC rõ, Coral vừa phải, CTA đủ rộng; bố cục sau khi sửa cân đối safe area. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/onboarding_01_record_final_after_init.png) |
| Edit Your Way | Preview, clip timeline và playhead hiển thị rõ; Back/Next đúng trang. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/onboarding_02_edit_final_after_flutter_init.png) |
| Smart Subtitles | Preview, waveform, cue và Get Started hiển thị ổn; nội dung nói rõ xử lý trên thiết bị. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/onboarding_03_subtitles_final.png) |
| Skip/hoàn thành | Legacy user vào thẳng thư viện; Get Started ghi `completed=true,page=2`; restart không hiện lại onboarding. | PASS — [legacy](TASK_UI_UX_02_EVIDENCE_20261110_121400/legacy_migration_main_dark.png), [restart](TASK_UI_UX_02_EVIDENCE_20261110_121400/restart_after_animated_splash_home.png) |

Các ảnh lỗi ban đầu được giữ làm evidence. Overlay lỗi được khắc phục bằng Navigator riêng cho onboarding; khoảng trống dọc ở trang đầu được cân lại; Next được bật lại sau mỗi chuyển trang. Không dùng các ảnh lỗi đó làm kết quả cuối.

### Splash

- Cold launch cho thấy nét số 3 trước, sau đó hình hoàn chỉnh có nét H. Đây là native vector animation; resource đặt 430 ms cho nét 3, 380 ms cho H và 90 ms cho accent. Các ảnh chụp là điểm quan sát rời rạc, không phải phép đo frame-time: [đầu](TASK_UI_UX_02_EVIDENCE_20261110_121400/animated_splash_v2_150ms.png), [sau](TASK_UI_UX_02_EVIDENCE_20261110_121400/animated_splash_v2_450ms.png).
- Android log ghi `Displayed MainActivity ... +7s908ms` ở cold launch AVD. Native splash tồn tại tới first frame, rồi app vào thẳng Video Library; không có timer chặn thêm. Độ trễ này chỉ đại diện cho AVD/lần chạy đo được.
- Warm resume qua `am start -W`: 95 ms, task được đưa lên foreground, onboarding không lặp. [Ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/warm_resume_home.png).
- Sai khác còn lại: splash nền sáng theo system Light, sau đó app nền tối theo theme Dark đã lưu. Chưa sửa vì cần đồng bộ theme app với lựa chọn theme native lúc khởi động. Trạng thái splash: **PARTIAL**.

### Bottom navigation và màn hình

| Màn/tương tác | Quan sát | Kết quả |
|---|---|---|
| Videos | Capsule cân với nút Create, nội dung thư viện không bị bar che. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_videos_dark_after_onboarding.png) |
| Photos | Icon/nhãn selected rõ, empty state và SafeArea cân. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_photos_dark.png) |
| Edit | Editing Studio mở được, selected state cập nhật. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_edit_dark.png) |
| Settings/cuộn | Settings mở được. Ở vị trí cuộn cuối, các hàng cuối và Reset preferences nằm phía trên navigation; bar không chắn nội dung tại max scroll. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_settings_scroll_end.png) |
| Create | Mở sheet Create hiện có; không bấm Screen recording hay khởi động capture. | PASS — [ảnh](TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_create_sheet_dark.png) |
| Tab/sheet interaction | Đã ghi clip ngắn các thao tác chuyển tab và mở sheet. | Ghi nhận — [video](TASK_UI_UX_02_EVIDENCE_20261110_121400/navigation_interaction.mp4) |

Thử nghiệm chỉ xác nhận visual navigation trong Dark theme. Keyboard avoidance được kiểm tra bằng code/widget path (bar ẩn khi keyboard có inset), chưa thao tác bàn phím trực tiếp trên AVD. Không có xác nhận TalkBack bởi người dùng.

### Ma trận tổng hợp

- **PASS:** Ba trang onboarding trên AVD; thao tác Skip/Get Started và restart; bốn tab; Create sheet; cuộn Settings tới cuối; warm resume.
- **PARTIAL:** Splash theme không theo app preference; cold first frame khoảng 7.9 giây trên AVD; chỉ quan sát theme Dark của app.
- **Chưa kiểm trực tiếp:** app Light theme, RTL trên thiết bị, scale 2.0 trên thiết bị, Reduce Motion trong Android settings, TalkBack/human usability, bàn phím mở trên AVD.

---

<a id="tests"></a>

﻿# TASK UI/UX 02 — Test Evidence

### Host checks

| Lệnh/hoạt động | Kết quả |
|---|---|
| `dart format` trên Dart đã sửa | PASS |
| `flutter gen-l10n` | PASS; ARB hiện có được cập nhật, localization được sinh lại |
| `flutter analyze --no-pub` | PASS ở lượt kiểm tra sau thay đổi Dart |
| `flutter test --no-pub test/onboarding_test.dart test/ui_startup_navigation_test.dart` | PASS, 14/14 |
| `flutter build apk --debug --target-platform android-x64 --no-pub` | PASS; APK debug trong workspace riêng `build/uiux02/workspace`, 89,467,873 bytes |
| `git diff --check` | PASS; chỉ cảnh báo line-ending có sẵn ở `studio_shell.dart` (LF sẽ đổi sang CRLF nếu Git ghi lại file) |

Focused tests bao gồm first-run, Skip/Get Started persistence, resume/restart, lỗi ghi và retry, settings không đổi, chặn double tap, swipe/Back, RTL Arabic cỡ chữ lớn/narrow layout, Reduce Motion, startup integration và method-channel contract. Các lỗi test trung gian về kích thước swipe fixture, thiếu Overlay và trạng thái nút Next đã được sửa; lượt focused cuối đạt 14/14.

Sau khi chỉ bổ sung Android splash resources, một lượt `flutter analyze --no-pub` lặp lại không xuất output trong khoảng 90 giây và được dừng. Không có Dart source thay đổi sau lần analyzer/focused suite PASS nói trên; lần dừng này được ghi là **không kết luận**, không tính là lỗi hoặc một lượt PASS mới.

### Android runtime

- AVD duy nhất được dùng: `emulator-5570` / `ThreeHRecorder_TASK09B_API36`. Không có lệnh gửi tới `emulator-5554` hoặc QA5560.
- APK được build trong workspace task riêng rồi cập nhật bằng install `-r`; không uninstall, clear data, wipe hoặc cài lại sạch.
- Onboarding đã kiểm tra thực tế: trang 1→2→3, Get Started và vào thư viện; trạng thái lưu `completed=true,page=2`, lần mở sau không lặp.
- Cold-start log: `Displayed MainActivity ... +7s908ms`. Warm resume: `am start -W` báo `WaitTime: 95` ms. Đo này không đại diện cho FPS hoặc thiết bị vật lý.
- Các ảnh và video nhỏ được lưu tại [evidence directory](TASK_UI_UX_02_EVIDENCE_20261110_121400/); screenshots splash chứng minh trạng thái vẽ 3 rồi H, không suy diễn tốc độ khung hình.

### Bảo toàn dữ liệu

`p2_locale.xml` trước/sau giữ hash `87bf0345b0fdb43f7551ff7b4224828423b9c18b99e18950de9c54b41166a481`. Onboarding dùng preferences riêng. Năm archive private-data trước các lần cài cập nhật vẫn được giữ trong evidence:

| Archive | Byte | SHA-256 |
|---|---:|---|
| `qa5570_private_data_preinstall.tar` | 90,854,400 | `232dccb3e4dddee63b8ce4e49866be6261cdf5f1b9517804466dd186c3bf3709` |
| `qa5570_private_data_before_final_update.tar` | 90,975,232 | `e76570ba88a653df9812a32fdfa5dcc87ff4ec5707309528969781ffc76532dd` |
| `qa5570_private_data_before_final_ux_update.tar` | 90,968,064 | `d4bebbd94f06957d6fc5067d1daf88caa011012daf0dcd44737dc9b995958b4d` |
| `qa5570_private_data_before_splash_update.tar` | 90,969,088 | `bda08b905c6dd9e0e6a82e7a35e31a3f3376a3329b6cbc0023ffcfe8bded7952` |
| `qa5570_private_data_before_animated_splash.tar` | 90,969,088 | `23876b0c9e799c3047a098efd231e68e5574cc5184fa185b258b6b3acb63a9a8` |

Không có capture/recording nào được khởi động từ Create sheet. Không có file người dùng hay source P1 nào bị xóa/ghi đè; không có commit/push.

---

<a id="storage"></a>

﻿# TASK UI/UX 02 — Storage Report

### Đo trước/sau

Build được đo theo tổng logical byte của file trong `build/`, không tính dung lượng block đã cấp phát.

| Hạng mục | Trước | Sau | Chênh lệch |
|---|---:|---:|---:|
| `build/` logical size | 138,729,451,665 B | 140,033,768,082 B | +1,304,316,417 B (~1.304 GB / 1.215 GiB) |
| Isolated build `build/uiux02/` | 0 B cho task này | 1,295,682,808 B | +1,295,682,808 B |
| Evidence folder UI/UX 02 | 0 B cho task này | 456,841,312 B | +456,841,312 B |
| Tổng phần tăng được quy trực tiếp cho task | — | — | **1,761,157,729 B (~1.761 GB / 1.640 GiB)** |

`build/uiux02/` có 1,863 file và APK `app-debug.apk` dài 89,467,873 B. Flutter build chạy trong workspace riêng để không ghi đè build output mặc định đang có. Năm bản snapshot private data QA chiếm tổng cộng 454,735,872 B; giữ nguyên vì là bằng chứng bảo toàn dữ liệu.

Evidence folder có 42 file, gồm snapshots, 3 ảnh onboarding cuối, ảnh splash/navigation và clip ngắn. Có một file `completed_restart_home.png` 0 byte do một lệnh truyền screenshot lỗi; file được giữ nguyên, không dùng làm bằng chứng kết quả.

### Dung lượng ổ đĩa

- Baseline trước công việc được ghi xấp xỉ **34.84 GB trống** (giá trị làm tròn).
- Cuối task ổ D còn **32,418,328,576 B** (~32.418 GB / 30.19 GiB).
- Chênh lệch free space xấp xỉ 2.42 GB; lớn hơn phần artifact UI/UX đã đo. Phần còn lại không quy kết được chắc chắn cho task vì có thể gồm cache/tool/system hoạt động khác.
- Tổng project không được quét lại để tránh lặp traversal trên workspace khoảng 146 GB. Con số build/evidence ở trên là phép đo trực tiếp; không tuyên bố tổng project đã được xác minh lại.

### Bảo vệ và tác động

- Không chạy `flutter clean`/`gradle clean`; không xóa hoặc nén artifact cũ.
- Không tạo AVD, không xóa snapshot, không sửa QA5560 hoặc emulator 5554.
- APK và intermediate mới ở `build/uiux02/`; năm backup QA, screenshot và video nằm ngoài build cache trong evidence folder.
- Dung lượng mới được đo dưới ngưỡng 2 GB; không có cleanup nào được thực hiện.
