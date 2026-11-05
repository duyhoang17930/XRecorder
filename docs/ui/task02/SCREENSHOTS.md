# TASK 02 — Screenshots

Đã xem lại 11 ảnh [Task 01](../task01/SCREENSHOTS.md) trước khi sửa. Các ảnh dưới đây chụp từ Flutter Android profile trên emulator API 36, 1080×2400, DPR 2.625. [Overview 16 ảnh](overview.png), [so sánh font](font_comparison.png), [báo cáo](REPORT_VI.md).

| Ảnh | Nội dung đã review |
|---|---|
| [01 Dark Home](screenshots/01_dark_home.png) | Manrope, Lucide, thông số quay thật thay marketing |
| [02 Library](screenshots/02_dark_library.png) | Lazy list, thumbnail, metadata và More |
| [03 Dark Create](screenshots/03_dark_create.png) | Tám công cụ, nhãn và mô tả ngắn |
| [04 Unavailable](screenshots/04_unavailable_tools.png) | Region/live/AI vẫn disabled |
| [05 Light Settings](screenshots/05_light_settings.png) | Nhóm cũ, Video quality, thông tin có disclosure |
| [06 Light Home](screenshots/06_light_home.png) | Palette/contrast light giữ từ Task 01 |
| [07 Light Create](screenshots/07_light_create.png) | Bộ icon và tool surfaces nhất quán |
| [08 Photos empty](screenshots/08_photo_empty.png) | Bỏ prose; giữ hướng dẫn chọn folder |
| [09 Editing Studio](screenshots/09_editing_hub.png) | New video project/Edit photo, nguồn không bị sửa |
| [10 Editor](screenshots/10_editor_dark_workspace.png) | Dark override, Export có nhãn, toolbar ngắn; dự án rỗng |
| [11 Large Settings](screenshots/11_large_text_settings.png) | Nội dung scale 200%, nav giữ giới hạn 1.3× hiện có |
| [12 Recording](screenshots/12_recording_dark.png) | Hero gọn, status + timer + Pause/Stop gần navigation |
| [13 Paused](screenshots/13_paused_dark.png) | Icon/nhãn Paused và Resume, không dựa riêng vào màu |
| [14 Processing](screenshots/14_processing_dark.png) | Native finalizing được trình bày thành Processing |
| [15 Saved](screenshots/15_saved_light.png) | Saved, View và Dismiss; Home sẵn sàng tạo phiên mới |
| [16 Error 200%](screenshots/16_error_large_text.png) | Giữ toàn văn lỗi và Dismiss, chữ lớn không overflow |

Catalog/thumbnail/project và sự kiện trạng thái trong bộ ảnh là **fixture chỉ trong test**. Không có dữ liệu demo hay giả lập thành công trong production. Capture/codec thật được kiểm riêng trong [native profile scenario](native_capture/emulator_verification.json); không suy hiệu năng từ PNG.

Đã review palette, glyph, nhãn, vị trí controls và scaling; không có phép so golden pixel tự động với Task 01. Empty editor không chứng minh playback có media hay export.
