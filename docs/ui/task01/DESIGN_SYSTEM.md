# TASK 01 — Global UI Design System

Ngày triển khai: 2026-11-05. Phạm vi: Flutter UI của 3HRecorder; Android trước.

## 1. Hướng thiết kế đã triển khai

**Dark Bento Studio**: nền slate tối, tầng surface rõ, card bo góc, bố cục công cụ theo mô-đun, màu cam/teal của repo được giữ và điều chỉnh độ tương phản cho light mode. Màu đỏ dành riêng cho hành động quay.

Glass accent dùng một lớp tint trong nhẹ và viền trên hero. Không dùng BackdropFilter, shader hoặc blur trên danh sách, preview hay nền editor. Editor video luôn tối; các màn còn lại theo Dark/Light/System. Header, About và nhãn launcher Android dùng 3HRecorder; application ID và đường dẫn media hiện có được giữ.

## 2. Repository đã đọc thực tế

Đã tải source chọn lọc, đọc LICENSE, pubspec và các file dưới đây trước khi triển khai. Link trỏ tới commit khảo sát; không vendor source hay chuyển branding của repo tham chiếu vào app.

| Repo / license | Source đã đọc | Quyết định áp dụng |
|---|---|---|
| [bento_layout — MIT](https://github.com/SiddharthJoshi1/bento_layout/blob/e28c2a2b4e6dc6648d8afa851741e6131250face/LICENSE) | [BentoGrid](https://github.com/SiddharthJoshi1/bento_layout/blob/e28c2a2b4e6dc6648d8afa851741e6131250face/lib/src/bento_grid.dart), BentoItem, BentoGridDelegate, sizing strategy | Đã xem SliverGrid + skyline, width fractions và unitHeight. Với 8 công cụ cố định, app dùng LayoutBuilder/Wrap, chiều cao theo nội dung và giảm cột khi chữ lớn; không cần thêm package/packing engine. |
| [flutter-fintech — MIT](https://github.com/danilo62x/flutter-fintech/blob/e4ca5dba80a9c3cda63ef042137ef8ac5621668b/LICENSE) | [theme.dart](https://github.com/danilo62x/flutter-fintech/blob/e4ca5dba80a9c3cda63ef042137ef8ac5621668b/lib/core/theme.dart), home_shell.dart, BalanceCard, QuickAction trong app_widgets.dart | Tham khảo ColorScheme cho hai brightness, card/action hierarchy và giữ tab bằng stack. Giữ go_router shell sẵn có, không thêm provider/http/intl/Cupertino icon package từ repo. |
| [Kite — MIT, gồm kite_ui](https://github.com/ColorlibHQ/kite-flutter-admin-dashboard/blob/395ce8083e6db9c7c68debaf311adcc246575bc8/LICENSE) | core/theme/app_theme.dart; [tokens.dart](https://github.com/ColorlibHQ/kite-flutter-admin-dashboard/blob/395ce8083e6db9c7c68debaf311adcc246575bc8/packages/kite_ui/lib/src/tokens.dart), card.dart, stat_grid.dart; package manifest/LICENSE | Tham khảo facade semantic color, tách tokens/components, lưu theme và breakpoint. Dùng ThemeExtension + notifier hiện có; không thêm Riverpod, shadcn_ui, fl_chart, trina_grid hay backend của Kite. |
| [glassmorphism — Apache-2.0](https://github.com/RitickSaha/glassmorphism/blob/890f2845e659e9b749e993dfb3fcec1974ac5f26/LICENSE) | [GlassmorphicContainer, _GlassBackground](https://github.com/RitickSaha/glassmorphism/blob/890f2845e659e9b749e993dfb3fcec1974ac5f26/lib/glassmorphism.dart) | Đã xem clip, gradient border và nhánh blur=0 bỏ BackdropFilter. App dùng surface tint đơn giản; không đưa blur vào cây render. |

## 3. File thay đổi

| Nhóm | File |
|---|---|
| Tokens / theme | [design_tokens.dart](../../../lib/core/constants/design_tokens.dart), [app_theme.dart](../../../lib/app/theme/app_theme.dart) |
| App / theme state | [app.dart](../../../lib/app/app.dart), [app_configuration.dart](../../../lib/app/app_configuration.dart), [main.dart](../../../lib/main.dart), [settings_controller.dart](../../../lib/features/settings/settings_controller.dart) |
| Navigation / workspace | [app_router.dart](../../../lib/app/router/app_router.dart), [studio_shell.dart](../../../lib/core/widgets/studio_shell.dart), **mới** [studio_create_sheet.dart](../../../lib/core/widgets/studio_create_sheet.dart) |
| Shared components | [studio_widgets.dart](../../../lib/core/widgets/studio_widgets.dart), [studio_fields.dart](../../../lib/core/widgets/studio_fields.dart), [studio_overlays.dart](../../../lib/core/widgets/studio_overlays.dart) |
| Screens | [media_library_screen.dart](../../../lib/features/media/media_library_screen.dart), [settings_hub_screen.dart](../../../lib/features/settings/settings_hub_screen.dart), [editing_hub_screen.dart](../../../lib/features/editor/editing_hub_screen.dart), [editor_screen.dart](../../../lib/features/editor/editor_screen.dart) |
| Branding copy | [AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml) chỉ đổi label; [recording_settings_form.dart](../../../lib/features/settings/recording_settings_form.dart) chỉ đổi tên app trong câu hướng dẫn |
| Verification | [widget_test.dart](../../../test/widget_test.dart), [fixture catalog](../../../test/fixtures/catalog.dart), **mới** [design_system_test.dart](../../../test/design_system_test.dart), [Android visual/persistence scenarios](../../../integration_test/design_system_test.dart), [screenshot driver](../../../test_driver/design_system_driver.dart) |
| Documentation / artifacts | [README](../../../README.md), báo cáo này, [SCREENSHOTS.md](SCREENSHOTS.md), overview.png, 11 PNG và emulator_verification.json |

Thay đổi wrapper Gradle 9.7.1 đã có từ task sửa build trước và được giữ. Không sửa Kotlin/Java/C++, service, channel contract, native preview/encoder, media processing, project controller hoặc export pipeline.

Ghi chú UI trong .claude-local/AGENTS.md cũng được đồng bộ với source hiện tại; đây là file local Git-ignored.

## 4. Components

Giữ tên Studio hiện hữu, không tạo thêm lớp AppCard/AppDialog trùng chức năng.

- StudioCard, StudioInset, StudioIconTile, StudioBadge: lấy semantic color theo theme.
- SectionTitle, StudioSectionLabel, SettingsRow: hierarchy, spacing và row height thống nhất.
- BentoCard, StudioBentoGrid, QuickActionTile: có consumer thật ở Create, Home và Editing Studio; ô tăng chiều cao theo chữ.
- StudioRecordHero, RecordActionButton, RecordingStatusIndicator: hành động quay nổi bật và trạng thái từ CaptureController thật.
- StudioBottomNavigation: Video / Photo / Create (+) / Edit / Settings. Create mở action sheet; không có branch/router destination mới.
- StudioDialog, StudioSheetHeader, showStudioBottomSheet/Dialog: theme-aware, motion theo accessibility; dialog có thể cuộn ở chữ lớn.
- StudioEmptyState, StudioLoadingState: dùng cho thư viện/draft/editor; loading dùng icon tĩnh khi giảm chuyển động.
- StudioSearchField, StudioDropdown, ChoiceGroup, StudioAnimatedSwitcher: theo theme, giữ controller/callback sẵn có.

Nhãn navigation giới hạn 1.3× như NavigationBar của Flutter SDK; tooltip/semantics giữ tên đầy đủ. Nội dung màn hình không bị giới hạn ở 1.3× và được kiểm ở 200%.

## 5. Design tokens

StudioColors là ThemeExtension có copyWith/lerp, không có biến màu toàn cục thay đổi theo runtime.

| Role | Dark | Light |
|---|---|---|
| Background | #0C1018 | #F3F5FA |
| Surface | #141A26 | #FFFFFF |
| Card | #181E2A | #FFFFFF |
| Elevated | #242D3E | #E7ECF5 |
| Primary | #FF7948 | #A83A12 |
| Secondary / teal | #55DCC5 | #006B5F |
| Recording | #FF6670 | #BB2335 |
| Text | #F5F7FC | #182033 |
| Muted text | #A6B0C3 | #526078 |
| Border / control outline | #303B50 / #64738F | #D5DDEA / #78869C |

Spacing: 4/8/12/16/24/32/48. Radius: 12 icon, 14 control, 20 card, 28 hero/sheet, pill. Elevation: 0/2/6. Touch target tối thiểu 48; button 52; create 52; settings row tối thiểu 72. Breakpoints: compact 340, tablet 600, wide 900, content max 1100.

Motion tokens: 120ms feedback, 180ms micro/theme, 280ms sheet. Page fade dùng thời lượng route Material. Dialog/sheet/page/switcher/theme tôn trọng reduced motion; status không có animation lặp.

Màu đen/trắng cố định chỉ dùng cho nội dung media/scrim; màu bút trong photo editor vẫn là màu được ghi vào ảnh. Manrope và Material icons hiện có được giữ cho TASK 02.

## 6. Dependencies và license

Không thêm/sửa pubspec hoặc lockfile. Runtime vẫn Flutter SDK + go_router ^18.1.2 (LICENSE của bản 18.1.2 là BSD-3-Clause, đã đọc trong pub cache). Test dùng flutter_test/integration_test đã có. Không đưa dependency của bốn repo vào app. Font Manrope giữ license OFL; các license native đã bundle giữ nguyên. Không thêm font/icon library hoặc production bitmap asset.

## 7. Screens đã áp dụng

- Video Home/Library: brand/header, record hero, quick actions, tìm kiếm/lọc, metadata và duration badge, menu chi tiết thống nhất.
- Photo Library: cùng system, trạng thái rỗng rõ.
- Create/Quick Tools: 8 công cụ. Screenshot, Screen recording, Facecam, Countdown, Editing tools nối tới luồng thật hiện có. Region, Livestream, AI subtitles disabled và ghi rõ chưa có trong build.
- Editing Studio: công cụ dạng Bento, draft/loading/empty state.
- Video Editor: workspace dark độc lập theme hệ thống, timeline/clip surfaces và action row thích ứng; native preview giữ nguyên.
- Settings: nhóm Capture/Appearance/Workspace/Help, Dark/Light/System có lưu, privacy/About/reset rõ ràng.
- Các màn phụ dùng ThemeData/fields/dialog/sheet chung nên nhận palette tương ứng.

## 8. Kết quả kiểm chứng

| Check | Kết quả đã chạy |
|---|---|
| dart format --output=none --set-exit-if-changed | PASS, 22 file Dart liên quan, 0 file cần format thêm |
| flutter analyze | PASS, không có issue |
| flutter test | PASS, **40/40** unit/widget tests (12 ma trận width/theme/text scale, 2 case dialog chữ 200% và kiểm tra hai tool phủ đủ hàng tablet) |
| Accessibility | PASS trong kiểm tra: semantic labels, Android touch-target guideline; màu chữ chính/muted/accent/error trên 4 surface đạt ít nhất 4.5:1, outline đạt ít nhất 3:1; reduced motion có test |
| Android integration profile | PASS, **2 kịch bản thực**: UI/navigation/screenshots và lưu/restore appearance qua AndroidSettingsStore. Không tính tearDownAll vào số test |
| Native preferences | Dark/Light/System sống qua controller mới; capture settings không đổi; document gốc được khôi phục và đọc lại xác nhận |
| Android screenshots | **11 PNG**, 1080×2400 / DPR 2.625; đã xem ảnh, gồm light/dark, Create, library, empty state, editor dark và chữ lớn |
| flutter build apk --debug | PASS với entry point lib/main.dart; lượt đóng gói archive sạch assembleDebug 20.5s; APK 164,698,773 bytes ở build/app/outputs/flutter-apk/app-debug.apk |
| flutter run -d emulator-5554 --no-resident | PASS, app chính cài và khởi chạy lại; fixture không nằm trong entry point production |
| Diff / scope | git diff --check PASS; pubspec/lockfile và native media/recording/editor engine không có diff; tự review scope, logic và diff, không có reviewer độc lập |

Sau integration test, app chính đã được mở lại bằng flutter run. Hai archive APK sinh trong build được xóa để loại khoảng trống zip incremental; APK đóng gói mới cài/mở lại qua adb thành công. Kiểm tra zip không thấy tên artifact fixture hoặc module visual integration/fixture trong kernel production.

Quan sát **profile trên emulator** trước khi đổi surface để chụp ảnh: 30 video fixture, thumbnail cache đã warm, 12 timed swipes × 350ms. Thu **243 frames**: build trung bình **1.031ms**, P90 **2.355ms**; raster trung bình **5.628ms**, P90 **11.286ms**. FrameTimingSummary ghi 0 lần vượt build budget và **12 lần vượt raster budget**. Số liệu đầy đủ trong JSON; không suy ra FPS điện thoại hoặc cam kết không drop frame khi đang quay.

Ảnh dùng catalog/thumbnail/draft fixture **chỉ trong test**. Không khởi động quay, screenshot media, livestream hoặc export để tạo ảnh minh họa. Xem [ảnh chụp](SCREENSHOTS.md) và [kết quả emulator dạng JSON](emulator_verification.json).

Reproduce tuần tự để tránh tranh chấp ghi cache Flutter SDK:

```powershell
flutter analyze
flutter test
flutter drive --no-dds --profile --driver=test_driver/design_system_driver.dart --target=integration_test/design_system_test.dart -d emulator-5554
flutter build apk --debug
flutter run -d emulator-5554 --no-resident
```

Các lần chưa đạt đã được xử lý: nhãn semantic Create thiếu; test cũ giả định hàng offscreen đã được dựng sau khi đổi sang sliver; thao tác test cần pump sau ensureVisible; test semantics cần dispose handle trước khi kết thúc; SDK cache race khi hai lệnh Flutter chạy đồng thời; DDS chặn VM Service khi đo profile. Ảnh đầu giúp phát hiện và sửa hero chưa giãn chiều ngang, navigation word-wrap ở chữ lớn. Log từng lần nằm trong .claude-local/scratchpad/task01 (Git-ignored).

## 9. Giới hạn và phần chưa kiểm

- Không có điện thoại vật lý kết nối. Số liệu emulator là quan sát trên workload fixture, không chứng minh hiệu năng máy yếu, lúc quay màn hình hoặc hồi quy so với bản trước; không có baseline trước/sau để kết luận phần trăm cải thiện.
- Native capture/facecam/preview/export không được chạy lại acceptance dài trong task UI. Controller/service/project regression hiện có được chạy; native source không đổi.
- Ảnh editor là workspace dự án rỗng. Timeline có clip nhận style mới nhưng native playback với media thật chưa được review hình ảnh trong task này.
- Region/livestream/AI subtitle vẫn chưa khả dụng theo implementation hiện tại; task này không tạo backend/engine giả.
- Font, hệ icon, launcher artwork và lựa chọn typography cuối cùng thuộc TASK 02. TASK 02 chưa bắt đầu.
