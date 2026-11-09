# TASK 15 — P2 Integration Requests (Recording Reliability & Recovery)

**Project:** 3HRecorder / XRecorder  
**Branch:** `feature/capture-live`  
**From:** P1 — Capture, Realtime & Livestream  
**To:** P2 — Settings, Media Library & Output Presentation  

---

## 1. Background
Trong Task 15, P1 đã hoàn thành cơ chế bảo vệ độ tin cậy ghi hình (F52) và kiểm tra container ISO-BMFF / phục hồi có điều kiện (F53). Để trải nghiệm người dùng trong Media Library và Settings được nhất quán, P1 đề xuất các điểm tích hợp sau cho P2.

---

## 2. Integration Requests

### 2.1 Hiển thị trạng thái khôi phục file dở dang trong Media Library
- **Mô tả:** Nếu một phiên ghi hình trước đó bị hệ điều hành tắt đột ngột (kernel kill, hết pin, crash hệ thống), `CaptureJournal` sẽ lưu thông tin session và phát hiện file pending.
- **Yêu cầu đối với P2:**
  - Khi người dùng mở Media Library, nếu phát hiện session journal có trạng thái `failed` do bị gián đoạn, P2 có thể hiển thị banner thông báo thân thiện: *"Bản ghi trước đó bị gián đoạn bởi hệ thống. Bản ghi mới cần được cấp lại quyền quay màn hình."*
  - Nếu file bị mất `moov` hoặc 0 bytes, không cố gắng tạo thumbnail hoặc thêm vào danh sách phát như một video bình thường (tránh gây crash video player của P2).

### 2.2 Không tự động xóa các file tạm có đuôi `.recovery_*.tmp`
- **Mô tả:** Trong quá trình phục hồi có điều kiện, `Mp4RecoveryEngine` ghi ra file tạm thời dạng `.recovery_<timestamp>.tmp` trong thư mục cache/media trước khi đổi tên chính thức.
- **Yêu cầu đối với P2:**
  - Bộ quét Media Scanner / Library Scanner của P2 nên bỏ qua (filter out) tất cả các file có đuôi `.tmp` hoặc `.pending` để tránh hiển thị các item rác chưa hoàn tất.

### 2.3 Thông báo dung lượng lưu trữ thấp (Storage Warning)
- **Mô tả:** `CaptureService` định kỳ kiểm tra dung lượng ổ đĩa. Nếu dung lượng khả dụng dưới 64MB, session sẽ tự động kích hoạt `stopCapture()` an toàn để bảo vệ phần video đã quay không bị lỗi ghi đĩa.
- **Yêu cầu đối với P2:**
  - Trong màn hình Recording Setup Sheet hoặc Settings, nếu dung lượng máy còn dưới 200MB, P2 có thể hiển thị cảnh báo bộ nhớ thấp để người dùng chủ động dọn dẹp trước khi bắt đầu quay.
