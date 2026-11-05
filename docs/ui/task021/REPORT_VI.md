# TASK 02.1 — UI/UX refinement & bug fixes

Ngày kiểm chứng: 05/11/2026. Đã sửa trực tiếp trên nền Task 01/02: giữ Dark Bento Studio, Manrope offline, Lucide, StatefulShellRoute và pipeline native hiện có. Không thêm dependency, không commit/push.

## 1. Nguyên nhân và cách sửa

| Vấn đề | Nguyên nhân | Thay đổi |
|---|---|---|
| Screenshot giống Scan | `AppIcons.screenshot` trỏ tới scanLine | Đổi duy nhất mapping sang `LucideIcons.camera`, tên đã kiểm tra trong package đang cài; giữ nhãn và action |
| Thư viện cần Refresh | Chỉ có event nội bộ/manual refresh; chưa quan sát thay đổi MediaStore/SAF. Reload cũ thay toàn bộ nội dung bằng loading | Thêm native ContentObserver và event channel; gộp event; tải nền, bỏ kết quả lỗi thời và giữ thumbnail/state khi dữ liệu không đổi |
| Sort xuống hàng trên màn hình thường | Nhãn dài và có thêm Refresh/selected-folder control | Chỉ giữ App media / Choose folder / Newest–Oldest; Wrap cho màn hình hẹp hoặc chữ lớn |
| Editing Studio báo Future trong setState | `setState(() => projects = repository.list())` trả về chính Future của phép gán, dù không viết `async` | Tạo Future ngoài setState, chỉ gán đồng bộ trong block; guard mounted. Sửa pattern tương tự ở picker, details và Trash |
| Lộ lỗi kỹ thuật | Dùng `e.toString()` trực tiếp ở snackbar/inline errors | `UserMessages` ánh xạ theo thao tác/mã lỗi sang copy đã duyệt. Các raw values còn lưu nội bộ được làm sạch ở ranh giới UI; FlutterError vẫn được chuyển tới diagnostic handler |
| Reselect tab không cuộn | Shell chỉ chuyển branch | Mỗi branch giữ một ScrollController; reselect cuộn về minScrollExtent, không goBranch/reload; chuyển tab giữ vị trí |
| Back có thân mũi tên | Mapping chung dùng arrowLeft | `AppIcons.back = LucideIcons.chevronLeft`, đi qua ActionIconTheme hiện có, giữ Navigator/go_router và vùng chạm mặc định tối thiểu 48dp |
| Editor Light vẫn tối | Router bọc toàn Editor bằng Theme dark | Bỏ wrapper ép dark; dùng theme đang có, cập nhật được cả khi Editor đang mở. Vùng preview media vẫn đen |
| FAQ khó phân biệt câu hỏi/trả lời | Style và độ nhấn gần nhau | Câu hỏi weight700/high-emphasis, trả lời weight400/secondary/line-height1.6, padding rõ; giữ accordion, nội dung và search |

Thông báo dùng chung có success/error/warning/info/loading, icon + chữ, nút đóng và thời lượng tương ứng 3/10/7/4/30 giây. Thông báo mới thay hàng đợi cũ; snackbar nằm trên bottom navigation. Chỉ lỗi capture cần giải thích thêm mới có Help dẫn tới đúng FAQ đã mở. Lỗi chọn nhạc hiển thị copy thân thiện ngay trong dialog để không bị modal che.

FAQ dùng token hiện có, không đổi palette. Tỷ lệ tương phản tính từ màu chữ/nền: câu trả lời Light **5.83:1**, Dark **8.72:1**; câu hỏi Light **14.89:1**, Dark **17.76:1**. Test palette kiểm tra ngưỡng 4.5:1.

## 2. Screenshot đang hoạt động thực tế thế nào?

Đây là chức năng **chụp màn hình thật**, không phải nút mở màn hình setup hay photo editor.

1. `StudioQuickTools` dùng action của Screenshot trong `studio_create_sheet.dart`, gọi `CaptureController.screenshot()`; nút khóa khi capture đang bận.
2. `AndroidRecordingService.screenshot()` gửi method `screenshot` qua `com.xrecorder/capture` tới CaptureBridge hiện có.
3. Native tạo session screenshot với countdown **3 giây**. Android có thể hỏi quyền notification trước; luôn cần đồng ý MediaProjection. Screenshot không yêu cầu microphone/facecam.
4. Sau consent/countdown, CaptureService tạo VirtualDisplay + ImageReader RGBA, crop phần padding theo row stride, nén **PNG** trên worker riêng.
5. MediaOutput ghi file tạm/pending rồi commit. API29+ lưu `Pictures/XRecorder/Screenshot_<timestamp>.png` qua MediaStore; API24–28 dùng `<external-files>/media`. Không đổi đường dẫn hay engine.
6. Session completed cập nhật Photo Library qua onSaved và observer đã gộp. Status bar hiển thị **Screenshot saved**, có View/Dismiss. Lỗi được hiển thị bằng thông báo thân thiện; nguyên nhân kỹ thuật không đưa trực tiếp lên UI.
7. Nếu người dùng hủy consent, native hiện có trở về idle, không lưu ảnh và không báo thành công. Hành vi này được giữ nguyên; chưa chạy riêng ca hủy consent trên emulator trong Task 02.1.

Đã thực thi trên API36: nhấn chính tile Screenshot, chấp nhận consent, đọc file thật, kiểm tra PNG signature, decode bitmap và kiểm tra ảnh có nhiều màu thay vì bitmap rỗng. Kết quả: **1080×2400, 173,704 bytes**; router vẫn ở `/videos`; chuyển Photo Library thấy ảnh. [PNG được app chụp thật](native/captured-screen.png), [kết quả native](native/emulator_verification.json).

## 3. Cơ chế automatic refresh

MediaCatalog quan sát hai collection video/image, cùng tree/children URI của thư mục SAF đã chọn. API24–28 có FileObserver cho thư mục media của app. Event được gộp bằng timer một lần 150ms; serial worker đọc metadata và so fingerprint. Chỉ khi dữ liệu thay đổi mới phát qua `com.xrecorder/media/events`. API30+ có thêm GENERATION_MODIFIED để nhận thay đổi cùng tên/kích thước/thời gian.

AndroidMediaRepository gộp event native với `refresh()` hiện có trong 250ms; trì hoãn UI invalidation lúc app ra background. Khi resume, chạy một lần `checkForChanges`; dữ liệu không đổi không phát thêm event. Không dùng timer lặp hoặc polling thư viện. Một số document provider không hỗ trợ observer vẫn có đường kiểm tra khi resume. Thiết kế dựa trên [ContentObserver](https://developer.android.com/reference/android/database/ContentObserver) và [hướng dẫn shared media/generation](https://developer.android.com/training/data-storage/shared/media) của Android.

MediaLibrary chỉ có một request đang chạy và tối đa một lượt tiếp theo được gộp từ burst event. Kết quả của folder/repository cũ bị bỏ. Tải nền giữ rows; dữ liệu giống nhau không setState lại; thumbnail chỉ đổi key khi metadata/revision thay đổi. Search, sort, folder và controller cuộn không bị reset bởi event. Pull-to-refresh hiện có được giữ như thao tác tùy chọn, nút Refresh đã bỏ.

App media vẫn giới hạn media do app sở hữu và `is_pending=0`. SAF giữ quyền đọc/thư mục trực tiếp như trước; bỏ file `.pending`, document `FLAG_PARTIAL` và pending output của app. Không thêm quyền đọc toàn bộ thiết bị, không sửa schema hay viết lại media database. Tham khảo [IS_PENDING](https://developer.android.com/reference/android/provider/MediaStore.MediaColumns#IS_PENDING) và [FLAG_PARTIAL](https://developer.android.com/reference/android/provider/DocumentsContract.Document#FLAG_PARTIAL).

Native scenario đã chứng minh: ảnh save trực tiếp không gọi refresh từ Dart; recording pending chưa xuất hiện, chỉ hiện sau commit; export mới xuất hiện dù không mở queue; chọn Movies/XRecorder; app ra Home, copy một video thử vào folder rồi resume, file import xuất hiện và vẫn read-only; App media loại file import; trash/restore tự cập nhật. Không nhấn Refresh trong scenario.

## 4. Files thay đổi trong Task 02.1

Danh sách này so với snapshot đầu Task 02.1, không coi toàn bộ worktree Task 01/02 đang có là thay đổi mới.

- Core/navigation: `lib/app/router/app_router.dart`, `lib/core/constants/app_icons.dart`, `lib/core/domain/models.dart` (revision metadata tùy chọn), `lib/core/widgets/{studio_shell,studio_widgets,studio_create_sheet,studio_tab_scroll}.dart`, `lib/core/presentation/user_messages.dart`.
- Media: `lib/features/media/{media_repository,media_library_screen,video_details_screen,trash_screen,photo_tools_screen}.dart`.
- Editor: `lib/features/editor/{editing_hub_screen,media_picker,editor_screen,editor_preview,export_screen,project_effects}.dart` — lifecycle và presentation; không đổi command xử lý media.
- Capture/settings: `lib/features/recording/{recording_service,recording_setup_sheet}.dart`, `lib/features/settings/{settings_hub_screen,help_screen,support_screen}.dart`. CaptureController thêm guard cho completion đến sau dispose.
- Android: `MainActivity.kt` chỉ nối/dispose media event channel; `media/MediaCatalog.kt` thêm observation, change checks và pending filtering.
- Tests: mới `test/refinement_test.dart`, `integration_test/{refinement_native_test,refinement_visual_test}.dart`; cập nhật kỳ vọng hợp lệ ở `test/{design_system_test,recorder_ui_test,recording_controller_test,widget_test}.dart`, `integration_test/design_system_test.dart`; driver xuất PNG native riêng.
- Tool/docs: `tool/verify_ui.ps1`, README, báo cáo/ảnh Task 02.1; cập nhật local conventions bị cũ/lỗi dấu trong `.claude-local/AGENTS.md` (Git-ignored).

Đã đối chiếu hash snapshot: 18 file Kotlin ngoài MainActivity/MediaCatalog giữ nguyên, gồm native recording/encoding, MediaOutput, MediaActions và native editor/export/preview; Dart ProjectController cũng giữ nguyên. Không đổi app ID, dependency, font, theme palette hay schema lưu dữ liệu. Tự review scope và diff; không có independent reviewer. [Tổng hợp verification và APK hash](verification.json).

## 5. Kết quả đã chạy

| Check | Kết quả thực thi |
|---|---|
| `dart format lib test integration_test test_driver` | Đã chạy; các file sửa đã format |
| `flutter analyze` | **No issues found** |
| `flutter test --reporter expanded` | **69/69 passed** |
| Build debug `--target=lib/main.dart` | **Thành công**, ARM32/ARM64/x86_64 |
| Native integration debug | **1 scenario passed** (runner còn báo thêm teardown); PNG/quay/export/SAF/import/trash/restore thực thi thật |
| Visual debug ~411dp | **1 scenario passed**, 9 ảnh, Light/Dark/System và FAQ200% |
| Visual debug320dp | **1 scenario passed**, 9 ảnh, gồm FAQ200%, không có Flutter layout exception |
| Production smoke | `install -r` APK main trên AVD test; home hiện, không có fixture media; [JSON](production_smoke.json), [ảnh](production_smoke.png) |
| APK integrity | ZIP CRC hợp lệ, kernel không chứa entry point/marker integration fixture |
| `git diff --check` | Không có whitespace error; có cảnh báo CRLF của file Task 01/02 có sẵn |

69 tests gồm cả suite cũ và regression mới: create→Back, retry/delete drafts, dispose giữa async, screenshot action/busy guard, event burst/coalescing/resume, giữ search/sort/scroll/thumbnail, đổi folder khi đang tải, sort320/411dp ở100/200%, reselect cả bốn tab, global chevron Back, Editor mở/chuyển theme tại chỗ, FAQ/search/hierarchy, copy lỗi không lộ nội bộ, năm trạng thái notice/thay hàng đợi/vị trí trên nav, Help mở đúng guide, FlutterError vẫn được báo diagnostic, lỗi music picker trong dialog.

APK production: `build/app/outputs/flutter-apk/app-debug.apk`, **165,369,592 bytes**. SHA256: `4b2e5f114df20b3ef58bd0d79b13034c43914573aa38c662c625289467236dea`. Đây là debug APK nhiều ABI, không phải số đo dung lượng release hay hiệu năng.

Logs chi tiết ở `.claude-local/scratchpad/task021/` (Git-ignored): `analyze-final.log`, `tests-final.log`, `build-main-final.log`, `native-run.log`, `visual-run.log`, `visual-compact-run.log`, `source-scope.json`, `apk-verification.json`. Kết quả tổng hợp có thể kiểm tra trực tiếp bằng JSON/ảnh được lưu trong thư mục báo cáo.

## 6. Before/after

[Ảnh ghép so sánh](comparison.png) · [Danh mục đầy đủ](SCREENSHOTS.md)

| Màn hình | Before | After |
|---|---|---|
| Video Library/icon/controls | [Before](before/screenshots/01_home.png) | [After](after/screenshots/01_home.png) |
| Editor khi chọn Light | [Before](before/screenshots/02_editor_light.png) | [After](after/screenshots/02_editor_light.png) |
| Editing Studio sau Back | [Lỗi Future](before/screenshots/03_editing_return.png) | [Đã sửa](after/screenshots/03_editing_return.png) |
| FAQ | [Before](before/screenshots/04_help.png) | [After](after/screenshots/04_help.png) |
| FAQ200% | [Before](before/screenshots/05_help_large_text.png) | [After](after/screenshots/05_help_large_text.png) |

Before được chụp bằng source snapshot đầu task, debug assertions bật; visual dùng dữ liệu sinh riêng, không dùng ảnh/media của người dùng. Đã xem ảnh ghép, ảnh chụp native và các ảnh after trọng điểm gồm snackbar/320dp/FAQ200%.

## 7. Các lần thất bại và giới hạn

- Regression đầu tiên tái hiện đúng lỗi thật `setState() callback argument returned a Future` ở Editing Studio; ảnh before ghi lại lỗi. Fix xử lý nguyên nhân, không chỉ che exception.
- Các lượt harness ban đầu lỗi vì đọc log PowerShell UTF-16 bằng UTF-8, chữ ALLOW viết hoa, kiểm tra row chưa được lazy sliver build, và chọn folder trước khi picker thực sự trả về. Đã sửa automation và giữ các assertion dữ liệu native; lượt cuối pass.
- AVD ban đầu bị System UI ANR khi host thiếu RAM. Chuyển cấu hình phần cứng AVD test và build trước khi chạy emulator; đây không phải bằng chứng lỗi recording engine. Lượt native cuối chạy ~62 giây, visual ~14–15 giây mỗi lượt; không suy ra FPS từ thời gian test.
- Test Help ban đầu đọc URI provider thay vì route được push; oracle chuyển sang kiểm tra HelpScreen nhận đúng topic/đáp án mở. Smoke ban đầu chỉ đọc XML `text` trong khi Flutter xuất nhãn vào `content-desc`; đã sửa oracle. Test repository event dùng FakeAsync cần cleanup qua runAsync; assertions event vẫn được giữ.
- Chưa xác minh trên máy thật/OEM khác, API24–28, cloud/USB document provider hoặc phiên quay dài. Chưa đo pin, nhiệt, encoder FPS, frame drop hay release performance. Không tuyên bố các mục đó PASS.
- Không có tính năng AI/livestream/Pro mới trong scope này. Các giới hạn sản phẩm trước đó vẫn nằm trong tài liệu sản phẩm/release validation.

## 8. Bảo toàn dữ liệu và chạy lại

Mọi install, automation, grant và cleanup Task 02.1 đều chỉ thực hiện trên **emulator-5560 / ThreeHRecorder_Task021 / API36**, AVD và data directory riêng. Emulator người dùng **emulator-5554 / Pixel_7** không bị cài, chạy harness, force-stop, uninstall, clear-data hay wipe. Không dùng ảnh/reference hoặc dữ liệu riêng làm fixture. Cleanup chỉ xóa các URI do scenario tạo cùng đúng file import thử và dump tạm của task. APK main đã được cài lại bằng `install -r` trên AVD test.

`tool/verify_ui.ps1` kiểm tra serial/tên AVD trước khi động tới app, luôn bật `--keep-app-running`, force-stop riêng process test để tránh dùng isolate cũ, không uninstall/clear-data. Chạy Flutter tuần tự; native scenario cần xử lý consent và copy fixture import đúng marker. Ví dụ visual khi AVD test đã khởi động:

```powershell
.\tool\verify_ui.ps1 -Mode visual
# Nếu có APK visual đã build với --dart-define=TASK021_AFTER=true:
.\tool\verify_ui.ps1 -Mode visual -ApplicationBinary build/task021/visual-test.apk
```

Runner không tự chọn thiết bị người dùng và không tự tạo AVD. Chưa có AVD test thì cần tạo riêng trước. Sau integration luôn build entry point `lib/main.dart` và cài lại APK đó trên đúng thiết bị test bằng `install -r`.
