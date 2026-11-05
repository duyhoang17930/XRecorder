# TASK 02 — Typography, Lucide & Human-Centered UI

Ngày thực hiện: 2026-11-05. Android / Flutter 3.47.8, Dart 3.13.7.

Đã đọc [báo cáo Task 01](../task01/DESIGN_SYSTEM.md) và xem đủ 11 ảnh trước khi sửa. Giữ Dark Bento Studio, palette, layout, router, theme persistence và các component Studio. Đây là thay đổi presentation; không bổ sung engine, AI, livestream hay entitlement.

## 1. Font đã chọn

**Giữ Manrope**, bundle offline hiện có. So sánh trực tiếp với Inter và Be Vietnam Pro bằng Flutter renderer, cùng cỡ 12/14/16/28, weight 400/600/700, tiếng Anh/Việt, số và mẫu body phóng 200%: [ảnh so sánh](font_comparison.png), [nguồn/hash font](font_comparison.json).

| Font | Nhận xét khi xem mẫu thực tế | Quyết định |
|---|---|---|
| Manrope | Dấu tiếng Việt rõ, heading hợp nhận diện hiện tại, mẫu nội dung gọn | Giữ; chưa có cải thiện đủ rõ để đổi |
| Inter | Chữ đều, dễ đọc ở cỡ nhỏ; cần đánh giá lại line wrapping nếu chuyển cả app | Không bundle thêm |
| Be Vietnam Pro | Dấu tiếng Việt rõ; mẫu cùng cỡ chiếm chiều ngang lớn hơn Manrope | Không bundle thêm |

Đây là đánh giá thiết kế của task, không phải kết quả nghiên cứu usability với người dùng. Nguồn font: [Google Fonts Manrope](https://fonts.google.com/specimen/Manrope), [Inter](https://fonts.google.com/specimen/Inter), [Be Vietnam Pro](https://fonts.google.com/specimen/Be+Vietnam+Pro); đã đọc metadata/OFL trong [google/fonts](https://github.com/google/fonts/tree/main/ofl). Cả ba dùng SIL OFL 1.1. Chỉ font Manrope hiện có được đưa vào APK.

Đã so **pixel và độ rộng** chuỗi tiếng Việt tương đương NFC/NFD trong Flutter; cả ba font cho kết quả giống nhau giữa hai dạng: [font_shaping.json](font_shaping.json). Kiểm tra cmap riêng lẻ ban đầu thấy Manrope thiếu combining glyph rời; điều đó không chứng minh lỗi hiển thị vì shaper có thể ghép thành glyph có sẵn. Kiểm tra render thực tế đã xác nhận mẫu này.

Typography vẫn tập trung ở `AppTypography`/ThemeData. Display 28, headline 20, title 16, body/button 14, nội dung phụ và nhãn 12. Tăng micro/section/badge/navigation từ 11 lên 12; giảm tracking section xuống .8. Không chặn scale nội dung; giới hạn nhãn navigation 1.3× từ Task 01 được giữ. Monospace chỉ dành cho bộ đếm thời gian.

## 2. Lucide package

**`lucide_flutter: 1.66.0`**, pin trong pubspec và lockfile. Đã tải archive từ pub.dev, đối chiếu SHA256 và đọc API sinh sẵn, manifest, LICENSE trước khi dùng.

| Package đã khảo sát | Bản kiểm tra qua pub API | Kết quả |
|---|---|---|
| [lucide_flutter](https://pub.dev/packages/lucide_flutter/versions/1.66.0) | 1.66.0, phát hành 2026-11-02 | Một font icon, chỉ phụ thuộc Flutter, `IconData` phù hợp component sẵn có; chọn |
| [lucide_icons_flutter](https://pub.dev/packages/lucide_icons_flutter/versions/4.0.2) | 4.0.2, phát hành 2026-11-04 | Cũng đang được duy trì; manifest có font regular và sáu font weight, không cần cho scope này |

Trang HTML pub.dev của lucide_flutter từng trả metadata cache khác với API; version thực thi lấy từ API và archive đã xác minh. [Source package chọn](https://github.com/cliq-ssh/lucide_flutter), [package so sánh](https://github.com/vqh2602/lucide-flutter-main), [Lucide](https://lucide.dev/).

Archive SHA256 của package chọn: `be8bf4219d3ee3c4b6e648b3d53e98125348d62897a30e483086a2af223af600`.

Package Flutter dùng MIT; artwork Lucide dùng ISC và có phần Feather MIT. Bundle đầy đủ [license artwork](../../../assets/licenses/Lucide-LICENSE.txt), đăng ký trong About/Licenses; license package được Flutter thu thập. Không sử dụng SF Symbols hoặc thêm Cupertino dependency. Icon/font không tải mạng khi chạy.

## 3. Icon chính

[AppIcons](../../../lib/core/constants/app_icons.dart) là điểm duy nhất import package và chọn glyph. Tất cả tên đã được đối chiếu với source 1.66.0; compiler/analyzer kiểm tra tiếp khi build. Dùng const `IconData` và `@staticIconProvider` để hỗ trợ tree shaking.

| Chức năng | Lucide |
|---|---|
| Video / Photo / Edit / Settings | clapperboard / images / wandSparkles / slidersHorizontal |
| Create / Back / Close / More | plus / arrowLeft / x / ellipsisVertical |
| Record / Pause / Resume / Stop | circleDot / pause / play / square |
| Ready, Saved / Processing / Error | circleCheck / hourglass / circleAlert |
| Screenshot / Facecam / Countdown | scanLine / scanFace / timer |
| Region / Livestream / AI subtitles | scan / radio / captions |
| Export / Undo / Redo / Split | upload / undo2 / redo2 / scissors |
| Share / Rename / Trash / Restore | share2 / pencil / trash2 / archiveRestore |
| Storage / Folder / Search | hardDrive / folderOpen / search |

Không còn `Icons.*` của Material trong source `lib`. Back/Close dùng `ActionIconThemeData`; FAQ đổi cả chevron đóng/mở. Các control chuẩn bên trong Flutter SDK vẫn giữ cơ chế render/semantics của SDK. Không thay chúng bằng control tự viết chỉ để loại font Material.

Icon phụ 18–20, thông thường 24, Create 28; icon lớn của empty state là trang trí. Touch target tối thiểu 48 theo theme; không dùng kích thước glyph làm kích thước vùng chạm.

## 4. Màn hình đã cập nhật

- Home/Video Library, Photo Library: Lucide, metadata và typography chung; Home hiển thị thông số quay thay câu marketing.
- Create: giữ tám ô và điều hướng cũ, nhãn/mô tả ngắn hơn. Region/Livestream/AI subtitles vẫn disabled theo implementation thật.
- Recording setup/settings: icon chung; giữ giải thích quyền, giới hạn FPS, âm thanh, camera, countdown và auto-stop.
- Capture status: Ready/Recording/Paused/Processing/Saved/Error có icon + chữ. Giữ nhãn riêng `Screenshot saved`. Có Preparing/Starting/Stopping/permission/countdown khi native phát các trạng thái đó.
- Editing Studio/Video Editor: bỏ prose, toolbar Effects/Add clip/Split, Export có nhãn, Undo/Redo giữ tooltip. Preview/timeline/controller/commands không đổi.
- Media details/Trash/Photo tools: Share/Edit/Rename/Trash/Restore dùng Lucide; bảng chọn màu có tên màu và trạng thái selected thay tooltip mã hex.
- Settings/Help/Support: nhóm và luồng cũ; storage/privacy mở thông tin đầy đủ qua StudioDialog.

Xem [16 screenshots và ghi chú](SCREENSHOTS.md). Ảnh Task 01 không bị ghi đè.

## 5. Phần chữ đã rút gọn

| Trước | Sau |
|---|---|
| Make it worth watching + Your screen… | Screen recorder + resolution/FPS/audio thật |
| Your next idea starts here | Bỏ; giữ Create |
| Capture after a 3-second delay | 3-second delay |
| Configure your camera in recording setup | Set up before recording |
| Resolution & Video Quality | Video quality |
| Video & audio effects / Add clip / merge / Split at playhead | Effects / Add clip / Split |
| Shape your story… / Make every detail count | Bỏ; giữ thao tác và giải thích chỉnh bản sao |
| Storage/privacy nhiều dòng trong Settings | Nhãn ngắn; toàn văn trong dialog |

Giữ nguyên nội dung cần cho permission, âm thanh, giới hạn thiết bị, lỗi, xác nhận xóa/reset và nguồn media không bị sửa. Không thêm thao tác tự quay/xuất/xóa hay chức năng chỉ truy cập bằng gesture ẩn.

## 6. Human-Centered UX và component reuse

Giữ Create ở giữa navigation; Pause/Resume/Stop ở sát navigation, dễ tiếp cận hơn bằng một tay. Capture bar dùng Wrap để nút tăng dòng ở chữ lớn. Hero thu gọn thành trạng thái khi phiên đang bận. Thời gian có semantics riêng, tránh đưa bộ đếm thay đổi liên tục vào live region thông báo trạng thái.

Icon-only controls có tooltip/semantics; nút màu ink có tên Red/Yellow/Cyan/White/Black và selected state, nền tương phản cho màu đen/trắng. Record, lỗi và lựa chọn có hình dạng/chữ đi kèm màu. Giữ ripple/motion ngắn và reduced motion của Task 01; không thêm blur, shader hoặc animation lặp.

Tái sử dụng StudioCard/BentoCard/StudioDialog/StudioSheetHeader/SettingsRow/RecordingStatusIndicator, button theme và `showNotice`. BentoCard cho phép bỏ description; RecordingStatusIndicator nhận glyph/màu trạng thái. Không tạo thêm AppCard/AppDialog/AppNavigation/AppFeedback trùng chức năng. Chỉ thêm `AppIcons` và mapper presentation capture, không thêm tầng state manager.

Quyết định tham khảo [Android accessibility](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility) về nhãn, 48dp và khả năng đọc; [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [typography](https://developer.apple.com/design/human-interface-guidelines/typography) về nhận biết, khoảng cách và scaling. Đã đọc bản Markdown chính thức Apple vì HTML yêu cầu JavaScript. Đã truy cập [Material 3](https://m3.material.io/) và trang interaction states nhưng công cụ chỉ nhận trang yêu cầu JavaScript; không coi đó là bằng chứng đã đọc nội dung hướng dẫn chi tiết. App giữ state/ripple/accessibility của Material 3 SDK hiện có.

## 7. File thay đổi trong Task 02

Danh sách dưới đây tách khỏi diff Task 01 đã có sẵn khi bắt đầu.

- Mới: `lib/core/constants/app_icons.dart`, `lib/features/recording/capture_status_presentation.dart`, `assets/licenses/Lucide-LICENSE.txt`.
- Typography/theme: `lib/app/theme/app_theme.dart`, `lib/core/constants/design_tokens.dart`, `lib/main.dart`.
- Shared UI: `studio_widgets.dart`, `studio_fields.dart`, `studio_shell.dart`, `studio_create_sheet.dart` dưới `lib/core/widgets/`.
- Editor: `editing_hub_screen.dart`, `editor_screen.dart`, `editor_preview.dart`, `project_effects.dart`.
- Media: `media_library_screen.dart`, `video_details_screen.dart`, `photo_tools_screen.dart`, `trash_screen.dart`.
- Recording: phần widget `CaptureStatusBar` trong `recording_service.dart`, icon trong `recording_setup_sheet.dart`.
- Settings: `settings_hub_screen.dart`, `recording_settings_form.dart`, `help_screen.dart`, `support_screen.dart`.
- Dependency: `pubspec.yaml`, `pubspec.lock`; chỉ thêm một runtime package Lucide.
- Verification: `test/design_system_test.dart`, `test/widget_test.dart`, `test/recording_controller_test.dart`; mới `test/recorder_ui_test.dart`, fixture recorder/visual catalog. Visual catalog được tách từ integration test cũ để dùng lại.
- Integration/driver: `integration_test/design_system_test.dart`, mới `integration_test/recorder_ui_performance_test.dart`, `test_driver/design_system_driver.dart`.
- Tài liệu: README, thư mục báo cáo này và ghi chú workflow local Git-ignored.

Đối chiếu hash đầu task: 35 file source/resource Android giữ nguyên. Nội dung adapter/service/CaptureController từ đầu `AndroidRecordingService` đến trước widget `CaptureStatusBar` trùng source cũ. Không sửa native recording/encoder/preview/export, application ID, media paths, capture settings controller hay schema persistence. `android/local.properties` là file sinh cục bộ được Flutter cập nhật khi đổi build mode. Xem [scope verification](scope_verification.json).

## 8. Kết quả kiểm chứng

| Check | Kết quả |
|---|---|
| Format / analyzer | Format check 66 file Dart không cần đổi thêm; analyzer không có issue; git diff --check đạt |
| Host suite | **43/43** tests; gồm matrix 320/600/1024dp, Dark/Light, chữ 100/200%; lazy catalog, persistence, reset/dialog, lỗi và controller regression |
| Capture UI | Event-driven Pause/Resume/Processing/Saved, Screenshot saved; failed Stop giữ phiên thật và khả năng thao tác; 320dp/200%, touch/label guidelines |
| Font research check | Một test Flutter render ba font; NFC/NFD có pixel/width giống nhau cho chuỗi đã kiểm |
| Android visual/persistence | **2 scenarios PASS**, 16 PNG; appearance qua AndroidSettingsStore; restore nguyên document khi có, dùng document v2 rỗng nếu ban đầu absent. JSON phân biệt fallback, không gọi fallback là khôi phục nguyên byte |
| Native capture/profile | **1 scenario PASS**, native MediaProjection thật; Pause/Resume/Stop qua nút UI; thời gian paused ổn định; output 720×1280, 15.976s, 6,559,757 bytes, không audio; chỉ output của test được đưa qua trash và xóa |
| Android packaging | Release và debug build PASS; font Lucide tree shaking 98%; ZIP CRC và kiểm tra không đóng gói test fixture PASS; xem artifact bên dưới |
| Scope/self review | Không còn Material icon hardcode trong app; source native và logic capture không đổi; không có independent reviewer; không commit/push |

Profile cùng emulator 1080×2400, DPR 2.625, workload 30 video fixture và 12 timed swipes ×350ms, thu trước khi chuyển surface để screenshot:

| Quan sát | Frames | Build avg / P90 ms | Raster avg / P90 ms | Vượt budget build / raster |
|---|---:|---:|---:|---:|
| Task 01, không quay — lịch sử | 243 | 1.031 / 2.355 | 5.628 / 11.286 | 0 / 12 |
| Task 02, không quay — lần lưu cuối | 229 | 1.235 / 2.177 | 9.331 / 22.290 | 0 / 38 |
| Task 02, native đang quay | 212 | 2.083 / 4.877 | 11.642 / 26.945 | 1 / 52 |

[JSON visual](emulator_verification.json), [JSON native capture](native_capture/emulator_verification.json). Đây không phải A/B kiểm soát tải host và không chứng minh hồi quy hay cải thiện phần trăm. Số liệu giữa các lần chạy dao động; một lần Task 02 trước đó có raster avg 5.843ms/P90 10.685ms, 9 frame raster vượt budget. Bảng giữ lần chạy cuối, không chọn lần tốt nhất. Chưa có baseline Task 01 đang quay.

Các lần chưa đạt đã xử lý: compiler không chấp nhận const Map có key MaterialColor, đổi sang const list record; callback mock event channel dạng expression trả sink gây lỗi codec, đổi thành block void; bỏ import thừa sau refactor fixture. Automation OS prompt phải xử lý notification trước và dùng nhãn `Share screen` trên emulator này.

**Sự cố harness:** Flutter SDK này gọi uninstall khi `flutter drive` kết thúc nếu thiếu `--keep-app-running`. Các lần drive đã chạy thiếu flag, làm mất dữ liệu riêng của app trên emulator; không có backup để phục hồi. Không có thay đổi vào ảnh tham chiếu/source của người dùng trong workspace. Hướng dẫn tái chạy đã sửa dùng flag này; phải dùng emulator kiểm thử riêng và backup dữ liệu cần giữ. Lần visual cuối đã dùng flag, kết thúc với `Leaving the application running` và kiểm tra package còn cài. Cài lại app chính sau integration không phục hồi được private data đã mất trước đó.

Lệnh tái chạy tuần tự trên emulator kiểm thử:

```powershell
flutter analyze
flutter test
flutter drive --no-dds --profile --keep-app-running --driver=test_driver/design_system_driver.dart --target=integration_test/design_system_test.dart -d emulator-5554
$env:UI_ARTIFACT_DIRECTORY='docs/ui/task02/native_capture'
flutter drive --no-dds --profile --keep-app-running --driver=test_driver/design_system_driver.dart --target=integration_test/recorder_ui_performance_test.dart -d emulator-5554
Remove-Item Env:UI_ARTIFACT_DIRECTORY
flutter build apk --release
flutter build apk --debug
```

Native test cần chủ động chấp thuận screen-sharing. Test từ chối chạy nếu có phiên quay đang hoạt động. Nó tạo/xóa đúng một output mới, nhưng native session journal vẫn là dữ liệu kiểm thử: dùng thiết bị test riêng. Driver mặc định ghi `docs/ui/task02`; biến môi trường đổi thư mục, không ghi đè ảnh Task 01.

## 9. Giới hạn còn lại

- Chưa có điện thoại thật; không cam kết FPS encoder, nhiệt độ, pin, codec/hardware hay không drop frame. Emulator vẫn có frame quá budget khi quay.
- Chưa thực hiện TalkBack thủ công với người dùng, đánh giá một tay trên thiết bị thật hay nghiên cứu usability; widget semantics/touch tests không thay thế các kiểm tra này.
- Ảnh editor dùng dự án rỗng. Native playback/timeline có media thật, facecam, mixed audio và export dài chưa chạy lại acceptance trong task typography/icon; source engine giữ nguyên, controller regression đạt.
- Ảnh trạng thái 12–16 dùng event fixture chỉ trong test. Native capture được kiểm ở scenario riêng; không dùng ảnh fixture để chứng nhận engine chạy thật.
- Region/livestream/AI subtitle/Pro entitlement vẫn theo implementation trước task, không có backend hay thanh toán mới.
- Dữ liệu riêng của app trên emulator bị reset bởi harness như đã nêu. File nguồn/ảnh tham chiếu trong workspace được giữ.

### Android artifacts

- [APK debug](../../../build/app/outputs/flutter-apk/app-debug.apk): **165,350,852 bytes**, assembleDebug 22.8s; entry point `lib/main.dart`, ZIP CRC đạt, không có module/token visual fixture trong kernel. Dùng bản này để thử trên máy.
- [APK release](../../../build/app/outputs/flutter-apk/app-release.apk): **54,842,823 bytes**, assembleRelease 145.9s; chưa ký, `apksigner verify` báo thiếu signature/manifest. Build thành công không phải artifact đã sẵn sàng phát hành; không publish trong task này.
- Tree shaking thực tế: Lucide **976,936 → 19,856 bytes**, Material SDK **1,645,184 → 1,568 bytes**. Manrope giữ **164,700 bytes**. Font comparison Inter/Be Vietnam Pro không nằm trong APK.
- Release tree shaker có cảnh báo font Cupertino không có trong assets. App không khai báo glyph Cupertino và ưu tiên Android; không thêm dependency chỉ để che cảnh báo. iOS và các nhánh UI Cupertino của SDK chưa được xác minh.
- [Hash và kiểm tra APK](apk_verification.json). App chính được cài/mở lại qua `adb install -r` và explicit MainActivity, không uninstall. Đã xem Home production ở trạng thái Ready và catalog thật rỗng, không có fixture. Document Settings trước/sau lần thay APK này giữ nguyên byte; điều này không khôi phục dữ liệu mất trong các lần harness trước.
