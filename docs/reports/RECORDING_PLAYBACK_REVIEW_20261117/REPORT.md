# Kiểm tra recording/playback — 2026-11-17

Trạng thái: CHƯA HOÀN THÀNH acceptance. Không sửa production code khi chưa xác minh nguyên nhân theo yêu cầu.

## Phạm vi và baseline

- Branch `main`, HEAD `9f5dcc9`; working tree sạch trước khi thực hiện.
- Không có AGENTS.md trong cây repository. Không commit/push.
- Không nhận được hai ảnh được nhắc trong task. Chưa có file được người dùng xác nhận là lỗi và file đối chứng bình thường.
- Thiết bị kết nối: model `2602DPT53G`, kích thước vật lý 1268×2756. App cài trên thiết bị versionName 0.1.0, lastUpdateTime 2026-11-17 14:55:33. Chưa chứng minh APK này khớp HEAD.
- Chỉ đọc thiết bị và sao chép hai video Recording vào /tmp; không cài APK, không thay settings, không bắt đầu/dừng recording hoặc camera.

## 1. Video bị thu nhỏ — xử lý trước

Hai mẫu được chọn theo thời gian, KHÔNG phải cặp lỗi/bình thường đã xác nhận:

| Mẫu | MediaStore ID / tên | Codec | Kích thước | FPS trung bình | Duration video |
|---|---|---|---|---|---|
| Mới | 1495 / Recording_1794902158072.mp4 | H.264 + AAC | 1080×1920 | 3105000/80921 (~38.37) | 3.596489s |
| Cũ | 1380 / Recording_1794139690317.mp4 | H.264 + AAC | 720×1280 | 4518000/134117 (~33.69) | 14.901889s |

- ffprobe không xuất SAR/DAR hoặc rotation/display-matrix side data cho hai mẫu; không tự gán chúng bằng 1 hay coi đó là bằng chứng metadata hỏng. Tỷ lệ kích thước pixel là 9:16.
- Frame gốc tại giây 1 được trích bằng ffmpeg và kiểm tra trực tiếp, lưu `/tmp/recording-review/recent.png`, `/tmp/recording-review/older.png`.
- Cả hai frame có dải đen dọc hai bên ngay trong dữ liệu encode. Cropdetect trên đoạn 0.3–2.3s cho vùng nội dung cuối cùng tương ứng `882:1920:98:0` và `588:1280:66:0`. Chỉ dùng để đo, KHÔNG crop sản phẩm.
- Tỷ lệ vùng nội dung gần tỷ lệ màn hình vật lý, khác canvas 9:16. Có thể là fit không crop vào preset; chưa xác định settings/nguồn tại lúc quay. Không kết luận đây chính là lỗi người dùng báo hoặc Player không có lỗi riêng.
- CaptureService.kt:180–192 resize VirtualDisplay theo kích thước nguồn, trong khi VideoEncoder dùng config.width/config.height cố định (:239, :258). Đây là điểm cần tái hiện với nguồn/preset/rotation, chưa phải nguyên nhân đã được xác minh. Không thay đổi chính sách orientation/preset theo phỏng đoán.
- VideoPreviewActivity.kt:28–29 dùng VideoView trong FrameLayout MATCH_PARENT và căn giữa. Không phát hiện Flutter widget hay width/height cố định theo dp gây thu nhỏ từ source này; chưa đo surface thực tế.

## 2. Facecam giật

- FacecamOverlay.kt dùng TextureView/SurfaceTexture và camera HandlerThread riêng. Repeating request không chọn CONTROL_AE_TARGET_FPS_RANGE, không gắn CaptureCallback (:208–215).
- Surface available gọi truy vấn characteristics/openSelectedCamera từ main thread; callbacks mở camera/session chạy trên cameraHandler. Camera switch và close cũng được gửi sang worker. Chưa có trace chứng minh main-thread blocking, CPU/GPU/encoder contention hoặc lifecycle gây giật.
- Transform được gọi khi display/configuration/size thay đổi; không có bằng chứng phải đổi geometry, orientation hoặc kích thước overlay.
- dumpsys media.camera tại thời điểm kiểm tra không có active camera client. Lịch sử có connect/disconnect ứng dụng; không cung cấp sensor timestamps/frame counters cho phiên lỗi.
- Frame intervals screen MP4 ghi trong media_checks.json: mới median ~16.667ms, max ~643.511ms; cũ median ~33.100ms, max ~66.155ms. Đây KHÔNG phải FPS camera và không dùng để kết luận dropped camera frames; mẫu mới cũng không có facecam ở frame giây 1.
- Sensor FPS thực tế, dropped frames, preview so với MP4: NOT VERIFIED. Không ép 30 FPS hoặc đổi stream size khi chưa đo vì có thể ảnh hưởng exposure và tải camera.

## 3. Integration request P2 — Player và Back/Close

Owner: P2. Không sửa file P2 khi chưa có quyền.

File: `android/app/src/main/kotlin/com/xrecorder/xrecorder/media/VideoPreviewActivity.kt`.

### Back/Close

Source đã có nút `p2_player_back`, icon `p2_chevron_back`, contentDescription bản địa hóa, touch target 48dp, góc trên trái, nền bán trong suốt, margin theo system bars/display cutout (:30–64). Click gọi finish(); releasePlayback chỉ dừng decoder. Không thấy gọi kết thúc CaptureService hay xóa media. Chưa kiểm chứng hiển thị runtime hoặc giữ nguyên library state.

Đề nghị P2 đối chiếu APK đang chạy với HEAD, tái hiện màn hình thiếu nút và kiểm tra hierarchy/window ordering khi MediaController mở. Patch đề xuất có điều kiện: nếu activity cũ thiếu nút, đưa đúng block back hiện có (:30–64) vào bản tích hợp; nếu nút bị che, chỉ sửa z-order/window của nút sau khi xác minh. Không thêm nút trùng, không thay router/theme/navigation.

### Playback surface

Sau khi người dùng xác nhận cặp MP4: mở cùng URI trên Player và so với frame decode. Đo bounds root/VideoView/surface ở portrait/landscape và kiểm tra rotation metadata. Nếu MP4 đúng nhưng surface sai, patch chỉ ở VideoView constraints/onMeasure: fit theo display aspect ratio trong available bounds (đổi trục khi rotation yêu cầu), căn giữa, không crop/stretch; giữ timeline/MediaController. Chưa có bằng chứng để cung cấp patch áp dụng được an toàn. Không dùng sửa Player để giấu dải đen đã encode.

## Kiểm thử và giới hạn

| Kiểm tra | Kết quả |
|---|---|
| Git branch/status ban đầu | PASS: main, sạch |
| ffprobe hai mẫu | PASS: đọc được, JSON kèm theo |
| Trích frame gốc và đo dải đen | PASS: hai mẫu đều chứa dải đen |
| Decode toàn bộ mẫu mới | PASS: exit 0, stderr rỗng |
| Decode mẫu cũ | CẢNH BÁO: exit 0 nhưng null output muxer báo non-monotonic DTS; không coi là PASS sạch hoặc bằng chứng lỗi decoder |
| Xác định đúng cặp lỗi/bình thường người dùng báo | NOT VERIFIED |
| Sensor FPS/frame interval/dropped camera frames | NOT VERIFIED |
| Preview so với MP4, rotation/transform runtime, contention | NOT VERIFIED |
| Start/Pause/Resume/Stop sau sửa | NOT RUN: không có production patch |
| Audio sync nghe/nhìn | NOT VERIFIED: duration track không chứng minh đồng bộ |
| Player cũ/mới, portrait/landscape, Back và library state | NOT VERIFIED |
| Unit/build tests | NOT RUN: không sửa executable code |
| git diff --check | PASS tại thời điểm rà soát |

## Toàn bộ file do task tạo

- REPORT.md: báo cáo, giới hạn kiểm chứng và integration request P2.
- recent_ffprobe.json: metadata bản quay mới, blocks streams/format.
- older_ffprobe.json: metadata bản quay cũ, blocks streams/format.
- media_checks.json: kết quả decode, thống kê khoảng cách frame và cropdetect hai mẫu.

Các file này chỉ là tài liệu/bằng chứng; không ảnh hưởng UI hoặc Recording Engine. Không sửa production code hay chức năng nào; không tuyên bố đã khắc phục ba lỗi. Toàn bộ UI, FloatingRecordingControls.kt, timer, permission, overlay style và các controls được giữ nguyên.

Thiếu nút Stop ngoài app: **WAITING FOR TEAM DECISION**. Không triển khai.

Để tiếp tục sửa đúng nguyên nhân: cần tên/path cặp video lỗi và đối chứng cùng xác nhận facecam giật ở preview hay MP4; hai ảnh mô tả lỗi chưa có trong đầu vào. Thiết bị đã truy cập được, nhưng phiên camera lỗi chưa được tái hiện/đo.
