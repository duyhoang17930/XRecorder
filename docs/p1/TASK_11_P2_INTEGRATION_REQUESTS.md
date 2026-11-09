# Task 11 — P2 Integration Requests: Drawing Overlay (F15)

Ngày: 2026-11-08  
Người yêu cầu: P1 (Capture, Realtime & Livestream)  
Đối tượng tiếp nhận: P2 (Platform, Media Library, Shared Integration / Architecture / UI)  

---

## 1. Bối cảnh & Mục đích
- Nhóm P1 đã xây dựng hoàn chỉnh hạ tầng native cho tính năng **F15 Drawing Overlay (Vẽ / Chú thích màn hình thời gian thực khi đang quay)**:
  - Lớp Engine vector nét vẽ [`DrawingStrokeEngine.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingStrokeEngine.kt): Quản lý danh sách stroke, clamp độ rộng nét `[2.0 .. 64.0]`, clamp mã màu ARGB, Undo (LIFO), Clear, và tự động chuyển đổi tỷ lệ tọa độ chuẩn hóa khi thiết bị xoay màn hình (orientation change giữa portrait và landscape).
  - Lớp Cửa sổ vẽ [`DrawingOverlay.kt`](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/DrawingOverlay.kt): Quản lý view trong suốt `TYPE_APPLICATION_OVERLAY`. Khi drawing mode tắt, overlay áp dụng cờ `FLAG_NOT_TOUCHABLE` để toàn bộ thao tác chạm của người dùng lọt thẳng xuống ứng dụng bên dưới. Khi drawing mode bật, overlay nhận touch và vẽ mượt nét vẽ bằng `Canvas.drawPath`.
  - Không sử dụng `FLAG_SECURE`, không gây ra vùng đen che khuất video.
  - Vòng đời: Tự động dọn sạch window, bộ nhớ và danh sách stroke khi kết thúc phiên quay (`Stop`, `Cancel`, `Error`, hoặc service destroy).
  - MethodChannel: Cung cấp các lệnh `setDrawingEnabled`, `clearDrawing`, `undoDrawing`, `setDrawingStyle`, `getDrawingState` qua channel `com.xrecorder/capture`.
- Do tuân thủ quy tắc **STRICT UI FREEZE** và **OWNERSHIP**, P1 không tự ý thêm các nút Brush/Pen/Eraser/Undo/Clear vào thanh điều khiển hoặc màn hình Flutter của P2.

---

## 2. Các yêu cầu tích hợp đối với P2

### 2.1. Cung cấp UI Tool Palette cho Drawing khi đang quay (Khi P2 dỡ bỏ UI Freeze)
- **Tệp liên quan:** `lib/features/recording/` hoặc menu công cụ nổi của P2.
- **Mục tiêu:** Cung cấp thanh công cụ nổi nhỏ gồm các nút:
  1. **Bật/Tắt chế độ vẽ (Brush Toggle):** Gọi `recordingService.setDrawingEnabled(true/false)`. Khi bật, người dùng có thể vẽ trực tiếp lên màn hình; khi tắt, người dùng tương tác bình thường với các app khác.
  2. **Hoàn tác (Undo):** Gọi `recordingService.undoDrawing()`.
  3. **Xóa tất cả (Clear):** Gọi `recordingService.clearDrawing()`.
  4. **Chọn màu & Kích thước nét (Color / Size):** Gọi `recordingService.setDrawingStyle(color: int, width: double)`.

---

## 3. Tiêu chí nghiệm thu (Acceptance Criteria)
1. Khi kích hoạt chế độ vẽ qua `setDrawingEnabled(true)`, người dùng có thể vẽ nét liên tục trên màn hình.
2. Khi tắt chế độ vẽ qua `setDrawingEnabled(false)`, toàn bộ màn hình cho phép chạm xuyên qua (touch passthrough) tới các ứng dụng bên dưới bình thường.
3. Các nét vẽ không làm crash app khi xoay màn hình; tọa độ được co dãn tỷ lệ chính xác.
4. Nét vẽ tự động biến mất và giải phóng tài nguyên WindowManager khi phiên quay kết thúc.
