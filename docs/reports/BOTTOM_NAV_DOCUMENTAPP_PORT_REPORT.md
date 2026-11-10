# DocumentApp Bottom Navigation Port — XRecorder

**Kết quả:** PARTIAL. Đã tinh chỉnh phần bottom navigation của XRecorder theo reference; chưa build, test hoặc xác minh Android sau patch vì Flutter SDK đang bị chiếm bởi tiến trình Dart không xác định chủ sở hữu. Source tree DocumentApp được yêu cầu cũng không có tại đường dẫn đã nêu.

## Source reuse và giới hạn

Đã thử đọc `D:\FAU_App\DocumentApp\document_app`; đường dẫn không tồn tại. Liệt kê chỉ đọc `D:\FAU_App` thấy XRecorder và artifacts, không có DocumentApp. Vì vậy không thể audit hoặc copy source implementation thật. Không sửa DocumentApp. Phần port dưới đây là adaptation theo screenshot [bottom_navigation.png](../implementation/UI/bottom_navigation.png) và contract của XRecorder; không tuyên bố đã reuse code gốc.

## Files XRecorder đã sửa

- `lib/core/widgets/studio_shell.dart`
- `lib/core/ui/theme/spacing.dart`
- `test/ui_startup_navigation_test.dart`

Không thêm dependency, không sửa router, business logic, media, settings, recording hay P1. Đã thu hẹp imports của StudioShell về đúng tokens/widgets đang dùng, giảm chiều cao capsule và bỏ phần Create label thừa dưới nút tròn. Không xóa file: chưa có file trong scope này được chứng minh là không còn consumer; QA evidence/report cũ được giữ nguyên.

## Source reference và target

| Thuộc tính | Screenshot DocumentApp | XRecorder trước patch | XRecorder sau patch — source inspection |
|---|---|---|---|
| Hình dạng | Capsule nổi, selected pill nhỏ, phần ngoài trong suốt | Capsule và action riêng; thanh nhìn cao, Create có label dưới nút | Capsule thấp hơn; Create riêng ở bên phải, không tạo tab thứ năm |
| Selected state | Pill sáng nằm trong capsule | Indicator theo segment, nhưng bar dày | Pill trượt trong Stack đã clip; 4 dp inset, rộng theo 1/4 capsule |
| Motion | Chuyển động nhẹ | 180 ms cho indicator và màu | Pill 260 ms ease-in-out; icon/label 180 ms; Reduce Motion = 0 |
| Glass | Blur nhẹ, nền sáng mờ, shadow thấp | Blur sigma 10 nhưng nền/border đậm và bar cao | Blur vẫn bounded sigma 10; surface alpha 0.76 Light / 0.74 Dark, border alpha 0.58, shadow nhẹ hơn |
| Tabs/Create | 5 vị trí, action tròn ở giữa | 4 tab và Create riêng bên phải | Giữ 4 tab Videos/Photos/Edit/Settings và Create tròn riêng bên phải theo contract XRecorder |
| Safe area | Capsule nằm trên gesture area | SafeArea và keyboard hiding đã có | Giữ SafeArea/keyboard hiding; giảm vertical padding xuống 4 dp |

Các kích thước/cảm nhận của DocumentApp trong bảng được ước lượng từ screenshot đã cung cấp, không phải đo từ source hoặc runtime DocumentApp.

## Reuse/adaptation

- Dùng BackdropFilter/ImageFilter.blur hiện hữu; không thêm glass renderer, shader hoặc package mới.
- Dùng StudioColors, AppSpacing, AppRadius, AppMotion, AppIcons/Lucide và existing AppTypography.
- Dùng StatefulNavigationShell.goBranch hiện có; không thay route index hoặc rebuild branch bằng router mới.
- Nút Create tiếp tục gọi callback `openStudioCreate`; tooltip và semantic label giữ nguyên. Nút có hit target 52 dp, bốn tab tối thiểu 48×56 dp.
- Reselect-to-scroll-top, scroll controllers từng branch, branch state, Android Back, nested routes, playback/editor state và media logic không bị sửa.
- Capsule vẫn clipped quanh BackdropFilter; ngoài capsule không có DecoratedBox nền opaque. Không thêm RepaintBoundary vì chưa có profile chứng minh lợi ích.

## Test và performance

Đã thêm widget coverage cho selected-pill bounds, Create tách khỏi capsule, touch targets và các width 320/360/393/411 dp trong RTL Arabic, Light/Dark và text scale 2.0; thêm assertion Reduce Motion tắt animation. Existing `test/refinement_test.dart` có test reselect-to-scroll-top cho cả bốn tab và đảm bảo URL không đổi.

**Chưa chạy** dart format, analyzer, tests, build, frame timings hoặc Android integration vì process Dart lâu giờ còn tồn tại và owner/parent không đọc được trong quyền hiện tại. Không có kết quả PASS/FAIL mới. Không thể đánh giá rebuild count hoặc frame/raster cost; blur được giới hạn trong capsule nhưng chưa profile.

## Android visual QA

Ảnh AVD thực trước patch: [Videos Dark baseline](../implementation/TASK_UI_UX_02_EVIDENCE_20261110_121400/nav_videos_dark_after_onboarding.png). Reference: [DocumentApp screenshot](../implementation/UI/bottom_navigation.png). Ảnh `nav_videos_dark_final.png` không dùng vì nội dung thực của file là onboarding subtitle, không phải navigation.

Không có screenshot/video sau patch. Chưa build APK mới nên không cài lên AVD và không quay chuyển tab. AVD QA đã xác nhận trước đó là `ThreeHRecorder_TASK09B_API36`, serial `emulator-5570`; trong lượt này chỉ đọc tên AVD/user list, không cài app, không sửa theme/user, không chụp screenshot. `emulator-5554` và QA5560 không được thao tác.

### Những gì hiện khớp hơn

- Capsule thấp hơn và tạo khoảng thở ít hơn; Create không còn label phụ làm bar cao.
- Pill nằm gọn trong capsule; motion có thời lượng phù hợp và không có overshoot.
- 4 tab và Create tách riêng được giữ theo app XRecorder, thay vì ép layout 5 slot của DocumentApp.

### Còn khác/chưa xác minh

- Không có source DocumentApp nên chưa so được radius, tokens, easing hoặc implementation chính xác.
- Không có ảnh Android sau patch; opacity, màu trong suốt trên từng nền Light/Dark và khoảng cách gesture bar chưa được quan sát.
- Reference dùng blue selection/action; XRecorder giữ Coral và action bên phải theo yêu cầu target, nên không pixel-identical có chủ đích.
- State preservation, keyboard, bottom sheets, active reselect, nested route và actual hit targets chưa chạy lại sau patch.

## Kết luận

**PORT STATUS: PARTIAL.** Equivalent target adaptation đã sửa source; direct source reuse và Android acceptance còn blocked. Chỉ chuyển sang DONE khi source DocumentApp được cung cấp hoặc chấp nhận adaptation, Flutter toolchain được giải phóng, focused tests/build pass, và screenshot/video mới trên đúng QA AVD được xem lại. Không commit/push; không có cleanup hoặc data operation.
