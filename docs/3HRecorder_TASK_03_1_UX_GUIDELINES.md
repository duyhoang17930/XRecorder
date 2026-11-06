# 3HRecorder — Human-Centered UX & UI Consistency Contract

**Áp dụng cho:** TASK 03.1 và tất cả thay đổi UI/UX sau đó.  
**Trạng thái:** Quy chuẩn dự kiến; chưa phải báo cáo triển khai hoặc xác nhận kiểm thử.  
**Dự án:** Android-first Flutter + native Android, Dark Bento Studio, Manrope offline, Lucide Icons.

## 1. Nguyên tắc ưu tiên

Khi các yêu cầu mâu thuẫn nhau, ưu tiên theo thứ tự:

1. **An toàn, quyền riêng tư và tính đúng đắn của thao tác.** Không quay/chụp ngoài ý muốn; không che giấu trạng thái capture; không làm mất media.
2. **Trải nghiệm thực tế của con người.** Dễ hiểu, thuận tay, dễ chạm, ít thao tác, có phản hồi và có đường thoát rõ ràng.
3. **Accessibility và khả năng sử dụng trên nhiều thiết bị.** Tương phản, kích thước chạm, chữ lớn, TalkBack, tay trái/phải.
4. **Độ ổn định và hiệu năng.** Không jank, lag, ANR, race condition hoặc animation cản trở thao tác.
5. **Sự nhất quán và tái sử dụng hợp lý.** Reuse design tokens, behavior, widgets khi ngữ nghĩa và hành vi thật sự trùng khớp.
6. **Trang trí thị giác.** Glass, gradient, shadow, animation chỉ dùng khi tạo thêm giá trị.

**Quy tắc cốt lõi:** Reuse là ưu tiên, **không phải mục tiêu tuyệt đối**. Nếu hai tính năng có trạng thái, mức độ rủi ro hoặc ý nghĩa khác nhau, được phép có component riêng. Ví dụ: không dùng chung một `CaptureStatusBar` giả định rằng Screenshot cũng là Video Recording.

## 2. Interaction contract bắt buộc cho toàn app

- **Thumb reach / One-hand:** Đặt thao tác thường dùng tại vị trí thuận tay trên điện thoại thực tế; không tự suy ra một sơ đồ thumb zone là đúng cho mọi kích thước/tay thuận. Kiểm tra cả tay trái, tay phải, màn nhỏ và lớn.
- **Touch target:** Mỗi vùng tương tác tối thiểu **48 × 48 dp** trên Android; icon nhìn thấy có thể 20–24 dp, nhưng vùng chạm phải đủ lớn. Giữ khoảng cách đủ để giảm bấm nhầm.
- **Primary action:** Mỗi màn hình có hành động chính rõ ràng. Record, Screenshot, Pause/Resume, Stop và Undo dễ phân biệt và dễ tiếp cận.
- **Short paths:** Giảm số bước không cần thiết. Không ép người dùng mở All tools cho thao tác được dùng thường xuyên; settings nâng cao có thể nằm sâu hơn.
- **Feedback:** Mọi tap tạo phản hồi tức thì (pressed state; haptic nhẹ có chọn lọc); loading chỉ xuất hiện khi thực sự chờ. Thông báo kết quả đúng ngữ cảnh và không chồng nhiều lớp.
- **No accidental actions:** Debounce/guard cho double tap; hành động phá hủy hoặc khó đảo ngược phải được đặt xa vùng thao tác nhanh hoặc có bảo vệ phù hợp. Đừng lạm dụng dialog xác nhận.
- **State transparency:** Người dùng phải phân biệt rõ `idle`, `recording`, `paused`, `countdown`, `saving`, `saved`, `error`; không dùng tên `Processing` mơ hồ cho mọi trạng thái.
- **Exit and recovery:** Quay lại, thoát, hủy, Undo và Retry có thể tìm thấy. Không khóa người dùng trong sheet hay floating mode.
- **Gestures:** Swipe/drag/long press là tiện ích bổ sung; chức năng quan trọng phải có đường thao tác rõ ràng, không chỉ tồn tại qua gesture ẩn.
- **Navigation:** Trở lại đúng màn trước, giữ state khi hợp lý; nhấn lại tab đang chọn thì cuộn lên đầu trang. Back icon theo ngôn ngữ giao diện đã thống nhất (`chevron-left`), tránh lẫn loại icon.
- **Motion:** Animation giải thích chuyển trạng thái hoặc tạo cảm giác phản hồi; không làm chậm thao tác hoặc replay khi rebuild. Tôn trọng Reduce Motion. Thời lượng tham chiếu: tap 100–160 ms, micro 150–220 ms, chuyển trang 220–320 ms, nhưng ưu tiên kiểm tra cảm giác thật.

## 3. Visual/UI contract

- Sử dụng **Lucide Icons** làm thư viện icon ưu tiên; chọn glyph đúng ngữ nghĩa, thống nhất stroke/size. Không đổi icon chỉ vì đẹp nếu người dùng khó hiểu hơn.
- Dùng **Manrope offline** và các typography tokens thống nhất; hỗ trợ dynamic text scaling đến 200% mà không cắt chữ hoặc che nút.
- Giữ **Dark Bento Studio** với biến thể Light/Dark đồng nhất về semantic colors, hierarchy, component states. Không hardcode màu khiến màn editor bị dark trong Light Mode.
- Dùng token chung cho palette, spacing, radius, elevation, haptic, duration, border; tránh nhiều phiên bản Button/Card/Sheet không chủ đích.
- UI ít chữ nhất **mà vẫn hiểu ngay**: icon + nhãn 1–2 từ khi cần; chú thích chỉ khi người dùng cần đưa ra quyết định hoặc liên quan quyền riêng tư.
- Lỗi/permission bằng ngôn ngữ người dùng: nêu vấn đề ngắn gọn, một hành động tiếp theo; chi tiết kỹ thuật chuyển vào Help & Guides. Không hiển thị exception hay stack trace.
- Contrast phải đủ trên cả Light/Dark; không dùng chỉ màu sắc để phân biệt trạng thái, nhất là câu hỏi/đáp án, active/disabled và toast.
- Safe areas, cutouts, keyboard, bottom nav, floating controls không che nội dung hay đẩy nút ra ngoài màn hình.

## 4. Quy định theo tính năng

| Luồng | Ưu tiên UX | Những lỗi phải tránh |
| --- | --- | --- |
| Video Record | Hành động bắt đầu rõ; trạng thái ghi hình luôn nhận biết được; Pause/Resume/Stop nhanh | Nhấn Record mà không biết đang quay; Stop vô ý; timer sai |
| Screenshot | Một action chính; consent hệ thống đúng quy định; countdown đúng ngữ cảnh; saved/View rõ ràng | Dùng UI Stop/Processing của video; tự bật ghi video; permission giả |
| Floating Bubble | Kéo thả, bám cạnh, thuận tay trái/phải, không che app khác; expand/collapse rõ | Bubble khó kéo, che target, nhấn nhầm, không biết đang capture |
| Draw on Screen | Chế độ Draw vs Pass-through rõ; Undo, Erase, Exit dễ thấy | Không tương tác được với app bên dưới; không biết nét vẽ có được ghi |
| Facecam | Kéo/resize mượt; vị trí dễ quan sát; rõ trạng thái camera/quyền riêng tư | Che nội dung chính; chạy khi không được cho phép |
| Media Library | Tìm, lọc, sắp xếp, xem, chia sẻ dễ; tự cập nhật media mới | Refresh thủ công, trạng thái rỗng sai nguồn, filter tràn/xuống hàng xấu |
| Editor | Cắt, xem trước, Undo/Redo, xuất file rõ; bản gốc không đổi nếu không được chọn | Mất công việc, nhầm Save/Export, Light Mode bị dark |
| Settings/Help | Ít chữ trên trang chính; giải thích nâng cao trong Help & Guides | Tên kỹ thuật khó hiểu, hỏi quyền quá sớm, phải đoán chức năng |

**Quan trọng với hệ điều hành:** Không mô phỏng/che/hack hộp xin quyền MediaProjection của Android; không tìm cách giữ token để né consent của hệ thống. Đảm bảo thông tin ghi hình phản ánh đúng trạng thái thật của native service.

## 5. Quy tắc cho shared components và 3 thành viên

1. Mỗi feature module sở hữu UI, state và tests của mình; tránh chỉnh sửa trực tiếp feature của người khác nếu không cần.
2. Shared widgets chỉ chứa hành vi/cấu trúc có ngữ nghĩa giống nhau. Dùng composition, semantic variants rõ tên; tránh `isVideo ? ... : ...` ngày càng rối.
3. Thay đổi `design_tokens`, typography, app theme, navigation, notifications, shared components phải kiểm thử **tất cả consumer** và review hợp đồng hành vi trước khi merge.
4. Nếu reuse gây khó hiểu, nhiều flags hoặc tác động chéo, tách component. Chấp nhận lặp nhỏ để bảo toàn trải nghiệm và ranh giới module.
5. Không thay đổi native capture pipeline, data model, permission, storage format hoặc navigation contract như một "UI cleanup" không có test và lý do rõ ràng.
6. Mọi component mới phải có trạng thái: idle, pressed, disabled, loading (nếu có), success/error (nếu liên quan), Light/Dark, text scale và accessibility semantics.

## 6. Quy trình TASK 03.1

**Giai đoạn A — Audit trước:** Lập danh mục screens, user journeys, CTA, touch targets, navigation, feedback, permission flow, empty states, Dark/Light và haptic. Đánh dấu mức độ `P0` (nguy cơ), `P1` (vướng thao tác), `P2` (polish), kèm ảnh bằng chứng.

**Giai đoạn B — Thử với người thật:** Tối thiểu một nhóm nhỏ khoảng 5 người dùng đại diện, trên thiết bị thật nếu có. Quan sát tay trái/phải, màn nhỏ/lớn; yêu cầu Start Record, Pause/Resume/Stop, Screenshot→View, di chuyển Bubble, Draw→Undo→Exit, tìm một video. Không hướng dẫn thao tác trước. Ghi time-to-complete, số lỗi/bấm nhầm, vị trí khó chạm và câu người dùng phải hỏi.

**Giai đoạn C — Sửa theo ưu tiên:** Sửa các pain point xác thực trước. Reuse tokens/shared elements nếu bảo toàn UX; thay đổi riêng từng feature nếu cần. Không redesign rộng chỉ theo sở thích cá nhân.

**Giai đoạn D — Verify:** Widget/golden/integration tests trên Light/Dark, khoảng **320 dp và 411 dp**, text scale **200%**, kiểm tra TalkBack/semantics và Reduce Motion; AVD không thay thế kiểm tra máy thật. Xác nhận core flows, media preservation và visual hierarchy.

## 7. Definition of Done

- Mỗi tác vụ phổ biến tìm được CTA mà không cần hướng dẫn.
- Không còn vùng chạm nhỏ hơn 48 × 48 dp đối với nút tương tác Android thông thường, trừ ngoại lệ được giải thích và đã kiểm tra accessibility.
- Không thấy thông báo kỹ thuật thô; không có status sai luồng; không có feedback trùng lặp.
- Không có overflow/che nút ở màn 320 dp, 411 dp, Light/Dark và text scale 200%.
- Reuse không gây regression chéo các module; các ngoại lệ đều có lý do UX rõ ràng.
- Có bằng chứng trước/sau: ảnh, task flow, danh sách vấn đề, kết quả test. Không tự nhận "người dùng thấy thuận tay" khi chưa thử với người thật.

## 8. Tham khảo ưu tiên

- Android Accessibility: https://developer.android.com/guide/topics/ui/accessibility/apps
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Nielsen Norman Group — 10 Usability Heuristics: https://www.nngroup.com/articles/ten-usability-heuristics/
- Nielsen Norman Group — Fitts's Law: https://www.nngroup.com/articles/fitts-law/
- UXmatters — How Do Users Really Hold Mobile Devices?: https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
- Nielsen Norman Group — Mobile Usability Testing: https://www.nngroup.com/articles/mobile-usability-testing/

### Gợi ý tích hợp vào `AGENTS.md` của dự án

> **3HRecorder UX Policy:** Before making any UI/interaction change, read `3HRecorder_TASK_03_1_UX_GUIDELINES.md`. Preserve the project's existing contracts. Prioritize human usability and correctness over reuse and cosmetic polish. Prefer shared components only when semantics/behavior truly match; test all consumers after shared changes. Do not invent native permission flows or claim user testing that was not performed.

> File này được cung cấp độc lập; **chưa sửa `AGENTS.md` trong repository** vì repository không có trong workspace hiện tại.
