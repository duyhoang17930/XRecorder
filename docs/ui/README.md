# UI / UX — 3HRecorder

- [Design system](DESIGN_SYSTEM.md): giao diện và component đang dùng.
- [Kết quả UX](UX_REPORT_VI.md): thay đổi, kiểm chứng và giới hạn.
- [Thử trên máy thật](USABILITY_TEST_VI.md): 10 tác vụ để người dùng thử sau.
- [Verification tóm tắt](verification.json): kết quả lịch sử ngày 06/11/2026, không phải test tự động chạy lại mỗi lần sửa code.
- [Hiệu năng](../performance/README.md): bảng đo và điều kiện benchmark.

Giữ Dark Bento Studio, Manrope offline, Lucide qua `AppIcons`, Light/Dark/System. Điều hướng gồm Video / Photo / Create / Edit / Settings; Create mở menu, nhấn lại tab cuộn lên đầu. Save/Export của editor ở dưới, có SafeArea; Back bảo vệ chỉnh sửa chưa lưu, thao tác tạo output có chặn nhấn lặp.

Screenshot: consent Android mới → app thu nhỏ → đếm 3 giây → một PNG → Saved/View/close, tự ẩn sau 5 giây foreground. Video giữ Start/Pause/Resume/Stop/Save. Không thay permission, encoder/audio/muxer hoặc preset để chỉnh UX.

## Ảnh đại diện

| Trường hợp | Ảnh |
|---|---|
| Home Light / Screenshot saved Dark | [Home](screenshots/home_light.png), [Saved](screenshots/screenshot_saved_dark.png) |
| Editor trước / sau | [Trước](screenshots/editor_before.png), [Sau](screenshots/editor_light.png) |
| Photo Editor chữ 200% / cảnh báo Back | [Editor](screenshots/photo_editor_large_text.png), [Keep/Discard](screenshots/photo_discard_dialog.png) |
| Chọn video chữ 200%, 320dp trước / sau | [Trước](screenshots/video_picker_before.png), [Sau](screenshots/video_picker_large_text.png) |

Ảnh dùng fixture tổng hợp; vùng preview video fixture không chứng minh decoder có lỗi. Kiểm chứng native dùng media thật riêng. Bộ ảnh này chỉ giữ ví dụ cần thiết, không phải toàn bộ ma trận Light/Dark/width/text scale.

## Lịch sử đã gộp

| Task | Kết quả giữ lại |
|---|---|
| 01 | Dark Bento Studio, tokens, component Studio và theme |
| 02 | Giữ Manrope sau so sánh font; Lucide tập trung trong AppIcons |
| 02.1 | Navigation/theme editor, media events, search/sort/scroll và thông báo thân thiện |
| 02.2 | Screenshot one-shot, consent mới, View ảnh thật và feedback 5 giây |
| 03.1 | Save/Export dưới, chống lặp, bảo vệ công việc khi Back, Retry và semantics |

## Artifact kiểm thử

Output mới mặc định vào `build/verification/ui/`, không vào docs. `tool/verify_ui.ps1` kiểm đúng AVD `ThreeHRecorder_Task021` / `emulator-5560` và giữ `--keep-app-running`. Không chạy trên emulator người dùng. Build native screenshot với `PRESERVE_TEST_OUTPUTS=true` khi cần giữ media; sau integration cài lại APK `lib/main.dart` bằng install-r, không uninstall/clear-data.

Các báo cáo/ảnh/log/JSON chi tiết cũ đã gom vào một bản ZIP local, không commit: `.claude-local/scratchpad/docs_cleanup_20261106/original_evidence.zip`. Không xóa app media, ảnh tham chiếu hoặc source tests trong lần dọn docs này.
