# TASK UI/UX 03 — Visual polish, HCI và orientation

**Kết quả: PARTIAL. TASK10: NOT STARTED.** Các thay đổi UI trong phạm vi đã triển khai, build và kiểm tra trên Android. Chưa đóng các vấn đề startup performance, xác nhận người dùng/TalkBack và phối hợp P1 được liệt kê bên dưới.

## 1. Phạm vi và baseline

- Branch `main`, HEAD `64e84ec0f952c4e28063488812933010f05bfa7d`; không commit, push, reset, restore hoặc clean.
- Đã đọc instructions, UX Guidelines, báo cáo UI/UX 02C và source hiện hành. Đã mở đủ bốn screenshot mới `201526`, `201603`, `201617`, `201732`, cùng reference onboarding/navigation.
- Chỉ dùng AVD **ThreeHRecorder_TASK09B_API36**, user 0, serial được xác minh `emulator-5570`. Không dùng 5554/QA5560; không tạo AVD/snapshot, uninstall, clear data hoặc chạy capture.
- [Baseline và trạng thái dirty trước sửa](baseline.json). Những thay đổi có sẵn trong MainActivity, SupportBridge và các file khác không được coi là thay đổi của UI03.

## 2. Thay đổi đã triển khai

| Hạng mục | Thay đổi | Kết quả |
|---|---|---|
| CTA onboarding | Bỏ icon và Back arrow; pill text-only 220dp, cao ít nhất 52dp, chữ 17sp semibold, căn giữa; footer cố định ngoài vùng cuộn | PASS |
| Nội dung onboarding | Mô tả đầy đủ hơn, font 16sp, giới hạn chiều rộng; cập nhật 14 ARB cho 12 locale và biến thể | PASS host; Android EN/AR đã thử |
| Landscape onboarding | Artwork và nội dung cạnh nhau, tỷ lệ 2:3; giảm chiều cao artwork ở viewport thấp; nội dung vẫn cuộn khi chữ lớn | PASS trong matrix đã chạy |
| Điều hướng onboarding | Giữ swipe, Skip, Next/Get Started, persistence/replay; sửa dispatch Android Back cho Navigator first-run riêng | PASS host; replay đã thử Android |
| Startup | Bỏ StartupSplash và chuyển cảnh logo khỏi đường khởi động; chỉ nền khởi tạo trung tính, không timer bắt buộc; Android 12+ không còn icon/wordmark 3H tùy chỉnh | PASS loại bỏ branding; performance PARTIAL |
| Bottom navigation | Tăng capsule thêm khoảng 12dp bằng giảm padding/gap; không tăng chiều cao; giữ glass/indicator, bốn tab và Create riêng | PASS trong kích thước đã kiểm |
| Settings | Bỏ entry gallery ở mọi build mode; giữ source, tests và route nội bộ chỉ trong `kDebugMode` | PASS source/debug UI; chưa release smoke |
| Library | Search và Sort không biến mất khi thư viện rỗng; giữ App media/Choose folder và backend hiện hành | PASS |
| Media Details | Nhóm Preview/Share, Edit ảnh, File management; Preview nổi bật; Trash tách riêng; giới hạn chiều cao thumbnail | PASS bố cục đã thử; không thực hiện thao tác file phá hủy |
| Ngôn ngữ | Highlight cả hàng được chọn, dấu chọn và tương phản semantic; dialog thích ứng chiều cao/IME | PASS |

Không thêm dependency, backend, schema, migration hoặc thay đổi semantics recording. Không thêm filter giả; các lựa chọn nguồn và Sort hiện có được giữ.

## 3. File thay đổi của UI03

- `lib/app/app.dart`: bỏ startup branding; xử lý Back cho first-run Navigator.
- `lib/features/onboarding/onboarding_screen.dart`: CTA, copy layout, bố cục ngang, tách helper primary action; artwork/store giữ nguyên.
- `lib/core/widgets/studio_shell.dart`: padding ngang và khoảng cách Create.
- `lib/features/media/media_library_screen.dart`, `video_details_screen.dart`: discoverability và nhóm action.
- `lib/features/settings/settings_hub_screen.dart`, `app_language_dialog.dart`: bỏ gallery; selected row và dialog thích ứng.
- `android/app/src/main/res/values-v31/styles.xml`, `values-night-v31/styles.xml`: bỏ icon/branding splash tùy chỉnh; thêm `drawable-night/launch_background.xml` tối giản.
- `lib/l10n/app_*.arb`: ba mô tả onboarding và `fileManagement`, đủ 14 file.
- Tests: `onboarding_test.dart`, `ui_startup_navigation_test.dart`, `refinement_test.dart`, mới `ui_ux_03_test.dart`.

Đây là danh sách delta của UI03, không phải toàn bộ `git diff` vốn chứa công việc chưa commit trước đó. Source gallery và startup painter cũ được giữ để bảo toàn dirty work; startup painter không còn được gọi từ ứng dụng. Không xóa evidence/source có sẵn như một phần dọn dẹp.

## 4. Lỗi thật phát hiện và sửa trong QA

1. **Android Back ở first-run:** onboarding dùng Navigator nằm ngoài GoRouter, nên Back không đến PopScope hiện có. App observer nay chuyển Back vào đúng Navigator khi nó đang được mount; không thay đổi Back của các route khác. Test first-run và interrupted/resume vẫn đạt.
2. **Mô tả dưới fold ở onboarding ngang:** bố cục dọc và artwork tối thiểu quá cao, nhất là 800×320. Chuyển sang hàng ngang, dành thêm chiều rộng cho chữ, giảm art minimum theo orientation; CTA vẫn cố định. Assertion mới kiểm tra mô tả nằm trên CTA ở scale 1.0, không hạ kỳ vọng để đạt xanh.
3. **Dialog ngôn ngữ mất nội dung khi keyboard + landscape:** AlertDialog dành gần hết vùng còn lại cho padding/actions, chỉ hiện Close. Thêm bố cục gọn cho vùng hữu dụng dưới 300dp; giữ controller, FocusNode và key khi đổi nhánh layout. Android cuối xác nhận `mInputShown=true` cả hai orientation, từ khóa `ar` và kết quả vẫn hiện.
4. **Test Sort cảnh báo hit-test:** đổi tap từ Text con sang ActionChip thực và assert sheet đã mở trước khi chọn Oldest; không tắt cảnh báo.

[Ảnh lỗi dialog trước sửa](Language_search_IME_landscape_1.png) → [Android sau sửa với keyboard còn mở](language_keyboard_landscape_final.png). [Log trạng thái IME, viewport và tap targets](final_runtime_run12.json).

Các lần script thất bại do chọn heading Preview thay button, label khác chữ hoa/thường, prefix ngày tháng, assumption Back/scroll hoặc console encoding được giữ trong evidence; không tính chúng thành lỗi sản phẩm đã sửa hay PASS. Lỗi layout/assertion thật được phân biệt ở trên.

## 5. So sánh trước/sau đã xem ảnh Android

| Màn | Trước do người dùng cung cấp | Sau trên Android | Nhận xét |
|---|---|---|---|
| Record Anything | [Ảnh trước](<../../implementation/UI/Screenshot 2026-11-10 201526.png>) | [Ảnh sau](final_build_onboarding_1.png) | Pill nhỏ, text-only; copy dài hơn, bỏ Back dưới |
| Edit Your Way | [Ảnh trước](<../../implementation/UI/Screenshot 2026-11-10 201603.png>) | [Ảnh sau](final_build_onboarding_2.png) | Giữ artwork; typography và CTA đồng nhất |
| Smart Subtitles | [Ảnh trước](<../../implementation/UI/Screenshot 2026-11-10 201617.png>) | [Ảnh sau](final_build_onboarding_3.png) | Get Started text-only; mô tả đúng ASR on-device |
| Settings | [Ảnh trước](<../../implementation/UI/Screenshot 2026-11-10 201732.png>) | [Ảnh sau](settings_help_about_clean.png) | Không còn gallery; giữ legal, feedback, introduction, licenses |
| Navigation | [Reference DocumentApp](../../implementation/UI/bottom_navigation.png) | [Light](final_build_home_light.png), [Dark](final_nav_dark.png) | Capsule rộng hơn, Create riêng, vùng ngoài trong suốt; không tuyên bố pixel parity |

[Onboarding ngang Light sau ổn định](light_onboarding_landscape_settled.png), [Dark](onboarding_dark_landscape_final.png), [Arabic 320dp/chữ 200%](onboarding_rtl_320_200_settled.png), [Settings 320dp/chữ 200%](settings_320_text200_dark_settled.png).

Một ảnh chụp ngay sau đổi wm/font bị chồng frame cũ/mới: [giữ nguyên ảnh chưa ổn định](onboarding_ar_320_text200_reduce_motion.png). Chụp lại sau ổn định cho kết quả sạch ở link Arabic phía trên. Không kết luận đây là root cause của lỗi kéo méo Settings lịch sử, và không tính ảnh chuyển tiếp đó là PASS visual.

## 6. Orientation thực, không thay bằng width test

Đổi `user_rotation` trên AVD, tắt auto tạm thời, xác minh screencap **411×920 → 920×411 → 411×920**, rồi khôi phục cấu hình gốc. Các lần dùng wm size chỉ phục vụ matrix responsive riêng.

| Màn/flow | P→L→P thực | State/giới hạn |
|---|---|---|
| Videos, Photos, Edit, Settings | PASS | Bốn branch còn truy cập được; navigation/scroll được kiểm tra cùng focused regression |
| Onboarding | PASS EN Light/Dark | Giữ trang, swipe, CTA; bố cục ngang mới đã xem ảnh; AR 320dp/200% đi hết ba trang |
| Media Details | PASS | Giữ media fixture; action có thể cuộn tới, không kích hoạt Move/Trash |
| Photo Preview | PASS | Đúng ảnh, Back về Details |
| Photo Editor | PASS | Tool Rectangle còn selected sau rotation; Save và controls truy cập bằng cuộn; không Save lên media |
| Video Editor/native preview | PASS phạm vi fixture | Clip 2 giây còn trong timeline sau rotation; draft còn sau install-replace |
| Video Preview Activity | PASS màn/media | Activity và hình video tồn tại cả hai orientation; chưa chứng minh clock continuity bằng clip dài |
| Help & guides, About dialog | PASS | Nội dung và Back/dismiss còn hoạt động |
| Sort sheet | PASS màn/layer | Scrim nằm trên shell; navigation không nhận tương tác dưới modal; các option thấp hơn cần cuộn ngang màn thấp |
| Language dialog + keyboard | PASS sau sửa | Query/focus và IME giữ được, search/result/Close nhìn thấy |
| Recording rotation | NOT RUN | Không capture; thuộc P1 |

Raw evidence: [main screens](orientation_main_run1.json), [Media Details](orientation_media_run2.json), [Photo Preview](orientation_media_run3.json), [Photo Editor/Sort](orientation_editor_run4.json), [Video Editor/Language](orientation_video_run5.json), [Video Preview](orientation_preview_run8.json), [draft sau install](final_restore_run13.json).

Các JSON có thể kết thúc bằng lỗi harness ở bước tiếp theo; chỉ các bước đã có evidence hợp lệ trong từng file được tính. Màn Photo Preview ở run2 chưa được mở do harness bấm heading; run3 đã mở đúng và đủ vòng xoay. Video Preview run8 đã đủ vòng trước khi script gặp bước Back/reselect.

## 7. Static và regression

| Kiểm tra | Kết quả | Evidence |
|---|---|---|
| `dart format --output=none --set-exit-if-changed` trên 11 Dart liên quan | PASS, 0 thay đổi | [Log](format_check_a3a38753fb194079915edb98c47c1b33.txt) |
| `flutter analyze --no-pub` | PASS, no issues | [Log cuối](final_analyzer_d2c1df7e84d74fcea2474ccefa94c465.txt) |
| Focused + relevant regression, 11 test files | **147/147 PASS**, không skip, không cảnh báo hit-test trong lượt cuối | [Log cuối](final_regression_a158dc4b1b7944ccb4cfd4048f95f195.txt) |
| `flutter build apk --debug --no-pub --target-platform android-x64` | PASS, Gradle 16.6s | [Log cuối](final_build_13170dab750a454cb3765a0e7766808b.txt) |
| `git diff --check` | PASS, exit 0; chỉ cảnh báo chuyển LF/CRLF cấu hình Git | [Manifest](preservation_and_storage_final.json) |
| Android install-replace | PASS; SHA256 APK host = installed base.apk | [Manifest](preservation_and_storage_final.json) |
| Log runtime cuối, PID app hiện tại, tối đa 3000 dòng | Không thấy RenderFlex overflow / Flutter exception / FATAL EXCEPTION trong mẫu này | [Log](final_runtime_log.txt) |

Test files: `ui_ux_03`, `onboarding`, `ui_startup_navigation`, `refinement`, `ui_ux_02c`, `global_layout`, `settings_persistence`, `settings_accessibility`, `support`, `photo_tools`, `ux_interaction` (đuôi `_test.dart`). Có test persistence, interrupted onboarding, settings nguyên vẹn, tab reselect/state, Create/modal, layout RTL/chữ lớn và Slider boundary cũ.

[Script lệnh chính xác](verify_final.ps1). SDK thực thi qua `D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe` + `flutter_tools.snapshot`. Không kill process lạ hoặc xóa SDK lock/cache. Không chạy lại toàn bộ TASK09B hay full host suite ngoài phạm vi liên quan.

Các lượt đỏ thật trước sửa được giữ: [mô tả 320dp chưa fit](focused_tests_1951de1566a047748a4c514993ccf63f.txt). Lượt 147 PASS trước chỉnh test tap còn warning cũng được giữ; log cuối phía trên đã sạch warning, không che lịch sử lỗi.

## 8. Startup và video

- [Cold-start video](final_cold_start.mp4), [contact sheet kiểm tra toàn đoạn](final_cold_contact_sheet.png): nền native tối giản rồi home; không còn 3H drawing, wordmark hoặc Flutter branded splash thứ hai.
- `am start -W`: một lượt COLD **TotalTime 10,902ms**, WaitTime 10,955ms ([raw](final_cold_start.txt)); lượt cài APK cuối COLD **11,602ms**, WaitTime 11,626ms. Một lượt khác còn timeout WaitTime 12,997ms. Đây là số đo debug/AVD first-display của Android, không phải cam kết time-to-interactive hoặc mọi thiết bị.
- Không thêm timer giữ logo và không thay initialization settings/onboarding. Bỏ splash **không sửa** nguyên nhân startup chậm/ANR lịch sử. Cần trace engine/init và phối hợp P1 nếu phải sửa shared native startup.
- [Video rotation ngắn](rotation_main_tabs.mp4). Chỉ là UI evidence; không chứng minh FPS/thermal hay capture encoder. Không quay bằng tính năng recording của app.

## 9. Accessibility, localization và giới hạn

- Host matrix onboarding: 320/360/393/411dp, hai orientation, scale 1.0/1.5/2.0, các nhánh EN/VI/AR/JA, Light/Dark và Reduce Motion; đi đủ ba trang. Có kiểm tra CTA/hình học và Android Back.
- Global-layout regression chạy 12 locale. 14 ARB đều có đủ các key mới; không hardcode mô tả trong widget.
- Android thực: bốn chiều rộng, font 150%/200% tại các case chọn; cả năm vùng chạm navigation ≥48dp. Arabic 320dp/200% đi hết ba trang với animation scale 0: [raw](rtl_settled_run14.json).
- Đây không phải toàn bộ tích Descartes của locale × theme × size × IME. TalkBack người thật, thiết bị vật lý, landscape IME của mọi bàn phím và FPS chưa được chứng nhận. First-run Android không reset QA data để diễn lại; logic first-run/resume được kiểm tra bằng fixture host độc lập.

## 10. P1 và bảo toàn dữ liệu

[Manifest đối chiếu](preservation_and_storage_final.json):

- Bốn hash baseline của MainActivity, recording_service, settings_controller và recording_settings_form **không đổi**. Không sửa MediaProjection, encoder, native permissions, recording defaults hay method-channel contracts.
- `app_settings.xml`, `onboarding_state.xml`, `p2_locale.xml`, `media_catalog.xml` **trùng byte** với tar trước QA; theme Dark, locale Follow system và folder UI02C đã trở lại ban đầu bằng UI.
- Hai fixture PNG khớp SHA256 với manifest UI02C trước đó. QA draft mới `project_1794319906023720.json` được giữ, mở lại thành công sau install-replace; không xóa draft để dọn test.
- Hai SAF tree UI02C và Task09B vẫn có persisted grants: [kết quả](saf_grants_final.json), [Android permissions](activity_permissions_final.txt). `dumpsys uri_grants` đầu tiên trả rỗng nên không dùng file rỗng đó làm bằng chứng.
- Size/density/rotation auto/user rotation/font/animator đều trở lại cấu hình baseline. APK installed có cùng SHA256 `fd98f091cfcc2800a1dcb8d971e2e86bde0f5d713d98495947a2a02e4b764258` với [APK debug](../../../build/app/outputs/flutter-apk/app-debug.apk).

DATA PRESERVATION: PASS trong phạm vi kiểm chứng trên và không có thao tác xóa dữ liệu. Không tuyên bố kiểm chứng byte toàn bộ user media hoặc khôi phục sự cố TASK08; không thao tác thiết bị lịch sử đó.

## 11. Storage

Đơn vị GB/MB thập phân; logical size không phải allocated size của sparse/AVD disks.

| Số đo | Trước | Sau |
|---|---:|---:|
| `build/` logical bytes | 140,688,905,131 | 139,444,929,428 |
| D: free bytes | 31,345,229,824 | 30,722,703,360 |
| Evidence UI03 mới, trước report cuối | 0 | 5,215,676 (~5.22 MB) |
| APK debug hiện tại | Output build có sẵn được cập nhật | 120,022,074 bytes |

Build logical giảm **1.244 GB** trong các lần build bình thường; không chạy cleanup và không diễn giải đây là dung lượng đã dọn thủ công. D: free giảm **622,526,464 bytes (~0.623 GB)**; không thể quy toàn bộ delta cho evidence vì toolchain/AVD/tiến trình khác và allocated sparse storage cũng hoạt động. Không tạo snapshot, nhân bản fixture lớn hay AVD mới. Evidence sau thêm report chỉ tăng vài KB. Không xóa file/evidence cũ để bù dung lượng.

## 12. Handoff và phần chưa đóng

| Mức | Việc còn lại | Owner / trạng thái |
|---|---|---|
| HIGH | Startup debug chậm/timeout, ANR lịch sử cần trace phân pha | P2 performance phối hợp P1 tại native boundary; PARTIAL |
| P1 coordination | Follow System làm default first-install và native đọc persisted theme | **WAITING FOR P1 APPROVAL**; settings default hiện hữu không bị sửa |
| P1 coordination | Hai recording Settings destination, capability chips/region/floating ball và giải thích unavailable | Bàn giao P1; không bật backend chưa sẵn sàng |
| QA | TalkBack/human usability, physical performance, release smoke, đầy đủ mọi locale/theme/IME | NOT RUN / PARTIAL |
| FOLLOW-UP | Video effects còn dày; Photo Editor cần cuộn ở landscape; preview hiển thị 2.2/2.0s ở cuối clip fixture | P3/editor UX; ngoài delta visual này, không sửa playback/export business logic |
| QA lịch sử | Settings kéo méo do người dùng: chưa có reproduction gesture bền vững; có frame chồng tạm khi thay display, ảnh ổn định đã kiểm lại | Chưa kết luận root cause; không tuyên bố đã sửa triệt để |

**UI/UX 03: PARTIAL** — UI refinements và các case Android đã nêu PASS; các gate/giới hạn trên vẫn mở.

**ONBOARDING: PASS trong matrix đã chạy · CUSTOM SPLASH REMOVAL: PASS · NAVIGATION: PASS trong phạm vi kiểm · SETTINGS/HCI: PASS phần đã sửa · ORIENTATION: PASS các màn đã liệt kê, exhaustive QA PARTIAL · TESTS: 147/147 PASS · P1 BOUNDARY: PRESERVED · DATA PRESERVATION: PASS phạm vi kiểm chứng · TASK10: NOT STARTED.**