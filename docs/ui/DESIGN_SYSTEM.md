# Design system hiện tại

## Shared component treatment

The shared controls use the compact, soft-surface treatment applied across the
app: 14dp action corners, 16dp menus, 20dp dialogs and cards, and 28dp sheets.
Search fields use an 18dp radius, a subtle border and accent-tinted shadow, with
at least a 48dp touch target. Form fields use filled surfaces without a resting
outline and a 1.5dp accent outline on focus. Buttons keep 48dp minimum targets
(52dp for filled primary actions). These shape and interaction rules use the
app's semantic colors and Manrope typography in both light and dark themes.

Contract UX: [3HRecorder UX Guidelines](../3HRecorder_TASK_03_1_UX_GUIDELINES.md). Tài liệu này tóm tắt; source là nơi xác định giá trị thực tế.

| Phần | Nguồn chuẩn |
|---|---|
| Semantic palette, spacing, radius, kích thước, motion | [core/ui/theme](../../lib/core/ui/theme/) |
| Theme Light/Dark, typography, transitions | [app_theme.dart](../../lib/core/ui/theme/app_theme.dart) |
| Icon Lucide, bao gồm Back chevron-left | [app_icons.dart](../../lib/core/constants/app_icons.dart) |
| Card/button/status/empty/loading | [core/ui/components](../../lib/core/ui/components/) |
| Dialog/sheet và reduced motion | [dialogs](../../lib/core/ui/components/dialogs/), [bottom_sheets](../../lib/core/ui/components/bottom_sheets/) |
| Navigation, Create, tab reselect | [studio_shell.dart](../../lib/core/widgets/studio_shell.dart) |

The shared UI is moving into `lib/core/ui/` by category. `lib/core/widgets/`
and `lib/core/constants/design_tokens.dart` currently remain compatibility
barrels while feature screens migrate. The component preview is available at
`/showcase/components` and from Settings → UI component gallery.

- **Dark Bento Studio:** nền slate, card/surface phân tầng, cam/teal; đỏ dành cho trạng thái quay. Light/System theo semantic colors, kể cả editor. Preview media giữ nền đen.
- **Typography:** Manrope bundle offline, không tải font qua API. Giữ thay vì đổi sang Inter/Be Vietnam Pro sau so sánh render; không có nghiên cứu người dùng chứng minh font nào tốt hơn. Icon dùng package Lucide qua AppIcons.
- **Touch/accessibility:** hit area Android tối thiểu 48×48dp cho control thông thường; glyph thường 20–24dp. Nội dung hỗ trợ scale200%; navigation label giữ giới hạn1.3× đã thống nhất và scaleDown để không wrap trong ô nhỏ. Nhãn/action semantics vẫn đầy đủ.
- **Motion:** dùng token hiện có, tôn trọng Reduce Motion; không thêm blur/shader hoặc animation lặp vào library/capture/preview.
- **Reuse:** dùng StudioCard, BentoCard, StudioSheetHeader, StudioDialog, fields và Material controls khi semantics/behavior khớp. Photo dirty-exit và video autosave-exit có logic riêng; không ép dùng một component với nhiều flags.
- **Status:** phân biệt recording/paused/countdown/saving/saved/error, không chỉ dùng màu. Busy guard chạy trước await; không giả completion hoặc bỏ consent.
- **Dữ liệu:** chỉnh/export tạo copy; không đổi schema, storage path, encoder/audio/muxer hay preset như một bước UI cleanup.

Kiểm chứng và giới hạn được ghi tại [UX report](UX_REPORT_VI.md), không suy từ design tokens rằng toàn app đã đạt accessibility trên máy thật.
