# Design system hiện tại

Contract UX: [3HRecorder UX Guidelines](../3HRecorder_TASK_03_1_UX_GUIDELINES.md). Tài liệu này tóm tắt; source là nơi xác định giá trị thực tế.

| Phần | Nguồn chuẩn |
|---|---|
| Semantic palette, spacing, radius, kích thước, motion | [design_tokens.dart](../../lib/core/constants/design_tokens.dart) |
| Theme Light/Dark, typography, transitions | [app_theme.dart](../../lib/app/theme/app_theme.dart) |
| Icon Lucide, bao gồm Back chevron-left | [app_icons.dart](../../lib/core/constants/app_icons.dart) |
| Card/button/status/empty/loading | [studio_widgets.dart](../../lib/core/widgets/studio_widgets.dart) |
| Dialog/sheet và reduced motion | [studio_overlays.dart](../../lib/core/widgets/studio_overlays.dart) |
| Navigation, Create, tab reselect | [studio_shell.dart](../../lib/core/widgets/studio_shell.dart) |

- **Dark Bento Studio:** nền slate, card/surface phân tầng, cam/teal; đỏ dành cho trạng thái quay. Light/System theo semantic colors, kể cả editor. Preview media giữ nền đen.
- **Typography:** Manrope bundle offline, không tải font qua API. Giữ thay vì đổi sang Inter/Be Vietnam Pro sau so sánh render; không có nghiên cứu người dùng chứng minh font nào tốt hơn. Icon dùng package Lucide qua AppIcons.
- **Touch/accessibility:** hit area Android tối thiểu 48×48dp cho control thông thường; glyph thường 20–24dp. Nội dung hỗ trợ scale200%; navigation label giữ giới hạn1.3× đã thống nhất và scaleDown để không wrap trong ô nhỏ. Nhãn/action semantics vẫn đầy đủ.
- **Motion:** dùng token hiện có, tôn trọng Reduce Motion; không thêm blur/shader hoặc animation lặp vào library/capture/preview.
- **Reuse:** dùng StudioCard, BentoCard, StudioSheetHeader, StudioDialog, fields và Material controls khi semantics/behavior khớp. Photo dirty-exit và video autosave-exit có logic riêng; không ép dùng một component với nhiều flags.
- **Status:** phân biệt recording/paused/countdown/saving/saved/error, không chỉ dùng màu. Busy guard chạy trước await; không giả completion hoặc bỏ consent.
- **Dữ liệu:** chỉnh/export tạo copy; không đổi schema, storage path, encoder/audio/muxer hay preset như một bước UI cleanup.

Kiểm chứng và giới hạn được ghi tại [UX report](UX_REPORT_VI.md), không suy từ design tokens rằng toàn app đã đạt accessibility trên máy thật.
