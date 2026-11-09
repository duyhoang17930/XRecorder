# Recording Settings — compact handle/header integration

## Hiện trạng đã kiểm chứng

- P1 đã bỏ 24dp top padding trong `recording_setup_sheet.dart`.
- Wrapper shared `lib/core/widgets/studio_overlays.dart` gọi `showModalBottomSheet` và lấy drag handle từ theme.
- Flutter SDK hiện tại dành 48dp cho handle, thanh 36×4dp đặt giữa vùng này. Nội dung bắt đầu ở 48dp: còn 22dp từ đáy thanh tới mép header, chưa tính phần căn giữa title trong header.
- Widget tests đo cùng khoảng cách 22dp ở 320/360/411dp. Không có Spacer, offset âm hoặc top SafeArea cộng thêm trong P1.

## Yêu cầu P2 nếu cần đạt chính xác mốc 12–20dp

- Cho phép riêng Recording Setup dùng bố cục handle/header gọn qua wrapper shared; không đổi theme hoặc các sheet khác.
- Thay đổi API tối thiểu đề xuất: thêm tham số tùy chọn `bool? showDragHandle` và chuyển tiếp sang `showModalBottomSheet`, giữ mặc định hiện tại. P1 sau đó có thể ghép handle/header trong nội dung của mình, giữ màu/kích thước thanh hiện tại và tính năng kéo/đóng sheet.
- Nghiệm thu: khoảng cách hiển thị handle–title 12–20dp, header/selector cố định, không mất kéo/đóng hoặc semantics, không overflow ở 320/360/411dp và khi có keyboard inset; sheet khác giữ nguyên.

P1 chưa sửa wrapper/theme shared và chưa thực hiện phần bố cục phụ thuộc API mới. Request này chỉ ghi bàn giao, chưa gửi cho người khác.
