# TASK 02.1 — screenshots

[Báo cáo và kết quả kiểm chứng](REPORT_VI.md) · [Ảnh ghép before/after](comparison.png)

Before: source đầu Task 02.1. After: UI sau sửa. Cả hai dùng visual fixture sinh riêng, debug assertions bật, trên AVD test API36. Capture native và production smoke là ảnh thật từ các lượt riêng, không dùng fixture catalog.

| Nội dung | Before ~411dp | After ~411dp | After320dp |
|---|---|---|---|
| Home Light | [Ảnh](before/screenshots/01_home.png) | [Ảnh](after/screenshots/01_home.png) | [Ảnh](compact/screenshots/01_home.png) |
| Editor Light | [Ảnh](before/screenshots/02_editor_light.png) | [Ảnh](after/screenshots/02_editor_light.png) | [Ảnh](compact/screenshots/02_editor_light.png) |
| Editing Studio sau Back | [Ảnh](before/screenshots/03_editing_return.png) | [Ảnh](after/screenshots/03_editing_return.png) | [Ảnh](compact/screenshots/03_editing_return.png) |
| FAQ mở | [Ảnh](before/screenshots/04_help.png) | [Ảnh](after/screenshots/04_help.png) | [Ảnh](compact/screenshots/04_help.png) |
| FAQ200% | [Ảnh](before/screenshots/05_help_large_text.png) | [Ảnh](after/screenshots/05_help_large_text.png) | [Ảnh](compact/screenshots/05_help_large_text.png) |
| Home Dark | [Ảnh](before/screenshots/06_home_dark.png) | [Ảnh](after/screenshots/06_home_dark.png) | [Ảnh](compact/screenshots/06_home_dark.png) |
| Editor chuyển Dark khi đang mở | — | [Ảnh](after/screenshots/07_editor_dark.png) | [Ảnh](compact/screenshots/07_editor_dark.png) |
| Editor chuyển System/Light khi đang mở | — | [Ảnh](after/screenshots/08_editor_system_light.png) | [Ảnh](compact/screenshots/08_editor_system_light.png) |
| Thông báo lỗi thân thiện, trên nav | — | [Ảnh](after/screenshots/09_friendly_notice.png) | [Ảnh](compact/screenshots/09_friendly_notice.png) |

- [PNG chụp màn hình thật qua Screenshot action](native/captured-screen.png): 1080×2400; Android screen-sharing indicator có thể xuất hiện trong ảnh.
- [Media Library sau native record/export/restore](native/screenshots/01_real_media_library.png).
- [Production debug smoke, entry point lib/main.dart](production_smoke.png).
- Kết quả máy đọc được: [native](native/emulator_verification.json), [after](after/emulator_verification.json), [320dp](compact/emulator_verification.json), [production](production_smoke.json).

Kích thước bình thường:1080×2400 px ở420dpi, khoảng411dp. Compact:840×2400 px ở420dpi,320dp; đã reset độ phân giải sau lượt test. FAQ200% có nội dung dài hơn viewport, cuộn được; không ép cắt nội dung để vừa một ảnh.
