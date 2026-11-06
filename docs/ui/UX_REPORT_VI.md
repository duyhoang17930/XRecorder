# UI / UX — kết quả triển khai

Tổng hợp Task01–03.1 ngày 06/11/2026. Kết quả dưới đây là evidence lịch sử của source được kiểm tại thời điểm đó; thay đổi code sau này cần chạy checks phù hợp.

| Ưu tiên / vấn đề trước | Đã xử lý | Bằng chứng giữ lại |
|---|---|---|
| P0: Back làm mất chỉnh sửa ảnh chưa lưu; draft có thể rời khi lưu lỗi | Photo Keep editing/Discard; video chờ autosave và cho Retry/Leave khi thất bại | [Cảnh báo](screenshots/photo_discard_dialog.png), widget tests |
| P1: double callback Export tạo2 request | Guard trước await, disable/Starting…; New project/Add clip/open draft cũng chặn lặp | BEFORE2 → AFTER1 ở 320/411dp |
| P1: Save/Export/Undo/Redo ở trên, title chật | Footer có SafeArea/Wrap; ảnh Save copy full-width | [Trước](screenshots/editor_before.png), [Sau](screenshots/editor_light.png) |
| P1: lỗi tải ảnh/draft thiếu Retry | Retry ngay màn; Future tạo ngoài setState, copy lỗi qua UserMessages | Tests load/save failure và recovery |
| P1/P2: picker không biểu thị source, tạo toàn bộ rows | ChoiceChip selected, lazy SliverList, responsive theo keyboard; Cancel tách khỏi list | [Trước](screenshots/video_picker_before.png), [Sau](screenshots/video_picker_large_text.png) |
| P1/P2: slider thiếu nhãn, navigation wrap, modal mở lặp | Semantics giây/%, navigation một dòng, shared modal bỏ request từ route không current | Semantics/touch tests, Create→Recording setup handoff |
| P2: Export finalizing dùng Processing | Saving…; giữ polling và không cho Cancel khi đang lưu file | Widget test finalizing |

## Kết quả đã chạy

- **107 unit/widget tests PASS**, analyze sạch, format và git diff check đạt. Native Kotlin/dependency/recording pipeline giữ nguyên so với lúc bắt đầu Task03.1, bao gồm các thay đổi Task03 có sẵn.
- Route matrix 320/600/1024dp × Light/Dark × text1/2; sort320/411. Photo Editor320/411 × Light/Dark ×200% đạt Android touch-target/labeled-action checks; picker có keyboard inset. Có test repeated create/save, dirty Back, autosave/save failure và Retry.
- UX BEFORE/AFTER trên AVD: Export2→1, dirty-photo protection false→true. 411dp được xác minh bằng header PNG1080×2400; 320dp là840×2400, density420. Lượt gắn nhãn411 nhưng ra840px đã loại khỏi so sánh và chạy lại.
- Native regression PASS: Cancel/Back không tạo file, consent mới×2, repeated taps, countdown321/minimize, auto Photo, View ảnh thật, timeout5s; video microphone Pause/Resume/Stop/Save4714ms và có audio metadata. CaptureService dừng, MediaProjection giải phóng.
- Screenshot visual Light/Dark/320/411/Photo200% PASS. Profile3 vòng PASS;9 output giữ lại,6 MP4 decode không lỗi. Xem [hiệu năng](../performance/README.md).
- APK `lib/main.dart` debug đa ABI build/cài lại bằng install-r; smoke idle resume/rotation/lock/trim-memory đạt. Không uninstall/clear-data/xóa media, không commit/push. [Verification tóm tắt](verification.json).

Finalizing→Saving… được thêm sau APK profile/UX screenshot; có widget regression và build vào APK production cuối, không tuyên bố đã benchmark riêng đổi chữ này. Các lượt test không thành công ban đầu chủ yếu do binding/semantics/finder lazy/pan threshold; test cũng bắt lỗi Future trong setState của Retry mới, đã sửa và chạy lại suite. Không có independent reviewer.

## Giới hạn và phần còn lại

Người dùng sẽ thử trên máy thật sau với [10 kịch bản](USABILITY_TEST_VI.md). Chưa đo mis-tap, thời gian tìm CTA, tầm với tay trái/phải, comfort hoặc TalkBack thật. Canvas ảnh vẫn cần gesture; chưa có trải nghiệm thay thế tương đương cho switch/keyboard.

Không xác nhận OEM/API khác, battery/thermal/FPS chính xác, protected content hoặc A/V sync. Rotation/lock chỉ smoke khi idle, low-memory là callback/trim signal; chưa ép cạn RAM hay quay nhiều giờ. Một số p95 tăng trong profile, không khẳng định toàn bộ performance không regression trên máy thật.

Tham chiếu áp dụng: [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps), [Nielsen heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/), [Fitts](https://www.nngroup.com/articles/fitts-law/), [Hick–Hyman/MacKenzie](https://www.yorku.ca/mack/mackenzie_chapter.html), [quan sát cách cầm điện thoại](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php). Đây là cơ sở thiết kế, không thay thế nghiên cứu người dùng của 3HRecorder.
