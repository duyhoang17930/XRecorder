# P1 Facecam và video playback — 2026-11-17

Baseline: `main`, `9f5dcc9`. Thiết bị QA được cho phép: 2602DPT53G, Android 16/API 36, màn hình 1268×2756. Giữ nguyên tài liệu có sẵn trong `docs/reports/RECORDING_PLAYBACK_REVIEW_20261117/`. Không sửa Flutter UI, theme, router, settings, P2, VideoEncoder hay Floating Controls. Người dùng cấp quyền commit sau khi đánh giá Facecam; không push.

## BUG-02 — Video thu nhỏ: nguyên nhân capture đã xác minh

| MP4 trên thiết bị | Codec / canvas | Nội dung trong frame gốc tại giây 1 |
|---|---|---|
| Recording_1794899425474.mp4, mẫu mới lỗi | HEVC, 1280×720 | Bbox [474,0,805,720], rộng 25,86% canvas |
| Recording_1793967077287.mp4, mẫu cũ đối chứng | AVC, 1080×1920 | Bbox [98,0,981,1920], rộng 81,76% canvas |
| Recording_1794901880738.mp4, bản thử hướng theo màn hình | HEVC, 720×1280 | Bbox [65,0,654,1280], rộng 81,81% canvas |

Cả ba mẫu decode toàn bộ thành công; ffprobe không xuất SAR/DAR hay rotation/display matrix. Vùng đen lớn đã encode trong mẫu lỗi. Tại lúc chẩn đoán, preference là Landscape nhưng nguồn màn hình dọc. Người dùng đã cho phép đầu ra theo hướng màn hình lúc bắt đầu.

P1 sửa hướng cấu hình phiên ngay trước khi mở encoder/VirtualDisplay, sau countdown và chờ camera. Chỉ hoán đổi hai cạnh preset, kiểm tra lại encoder hỗ trợ khi đổi cạnh; giữ codec/FPS/bitrate/audio. Không ghi lại preference, không crop/stretch. Screenshot, region và livestream giữ chính sách cũ. Orientation đầu ra cố định trong phiên: xoay giữa phiên vẫn có thể letterbox; chưa xử lý resize encoder động. Viền nhỏ do tỷ lệ màn hình 1268:2756 khác preset 9:16 vẫn được giữ để không mất nội dung.

## BUG-01 / BUG-01a — Facecam giật, nằm ngang và trái/phải

Source áp thêm sensor rotation và mirror vào TextureView vốn đã nhận camera producer transform. Log chẩn đoán sau frame 30 cho ma trận producer có hoán đổi trục, lặp lại ổn định. Ma trận identity ở callback đầu chỉ là dữ liệu khởi tạo, không dùng để kết luận. Bản thử bù sensor bổ sung gây regression đã loại bỏ.

P1 chỉ sửa `calculateTransform`: bù display rotation, không bù sensor/mirror lần hai; tính scale theo buffer đã định hướng để giữ tỷ lệ và center crop hiện có. Không đổi window, vị trí, kích thước 110×147dp, camera stream, AE FPS, lifecycle hay encoder. Mọi log tạm trong FacecamOverlay đã gỡ.

Người dùng xác nhận: **“Đúng chiều, trái/phải đã đúng”**, sau đó **“Đã mượt hơn, không còn giật rõ”**. Đây là xác nhận trên máy QA, không phải bảo đảm mọi máy đều hết jank.

| Đo trong debug APK | Trước | Sau transform được xác nhận |
|---|---|---|
| Sensor FPS từ median interval | 30,052 | 30,052 |
| Sensor median / p95 / max | 33,276 / 33,276 / 33,276 ms | 33,276 / 40,071 / 43,277 ms |
| Sensor interval >50 ms | 0/558 | 0/547 |
| Preview render median / p95 / max | 33,309 / 50,084 / 72,430 ms | 33,297 / 50,348 / 67,089 ms |
| Preview interval >50 ms | 21/400 | 32/368 |
| FrameTimeline jank | 2/401 | 1/369 |

Không kết luận scheduling jitter đã hết: render vẫn có khoảng cách >50ms; thời lượng trace/ánh sáng/chuyển động khác nhau và bản đo có log chẩn đoán. Không lấy FPS MP4 làm FPS camera; không coi khoảng cách render là số HAL dropped frames. Trace trước không cho thấy main-thread task dài bất thường (doFrame max khoảng 9ms trong cửa sổ đo). Chưa xác minh tranh chấp GPU/encoder là nguyên nhân.

Tham khảo kỹ thuật: [Android Camera2 preview](https://developer.android.com/media/camera/camera2/camera-preview), [TextureView display compensation](https://developer.android.com/codelabs/android-camera2-preview). Kết luận cuối dựa thêm vào ma trận runtime và xác nhận người dùng.

## File sửa và phạm vi

| File | Khối thay đổi / lý do | UI / engine |
|---|---|---|
| CaptureConfig.kt | Thêm atDisplayOrientation, chỉ cho quay full-screen | Không UI; cấu hình phiên |
| CaptureService.kt | startEncoder: hướng tại thời điểm bắt đầu, revalidate tuple | Không UI; capture |
| FacecamGeometry.kt | calculateTransform: bỏ sensor/mirror trùng, scale đúng trục | Chỉ nội dung ảnh Facecam; không đổi khung |
| CaptureOrientationTest.kt | 4 test: hai hướng, giữ thuộc tính, loại trừ region/live | Test |
| FacecamGeometryTest.kt | Cập nhật kỳ vọng TextureView; kiểm tra tỷ lệ/phủ khung/bốn hướng | Test |
| Báo cáo này và evidence/verified_metrics.json | Kết quả, giới hạn và số đo | Tài liệu |

## Test trước/sau và giới hạn

- PASS: flutter analyze --no-pub, không có issue.
- PASS: 56 Flutter tests liên quan Facecam/recording/region/screenshot/consent/route identity.
- PASS: 168 Android JUnit tests, 0 failure/error; build debug APK thành công.
- PASS trên APK cuối: Start → Pause (journal paused) → Resume (recording) → background/foreground giữ session → Stop; finalize content://media/external/video/media/1514; projection được giải phóng; Library hiện video mới Recording_1794904491559.mp4.
- PASS: hai MP4 sau sửa (16,52s và 137,48s) decode toàn bộ sạch, AVC 1080×1920; bbox [98,0,981,1920], giữ đủ tỷ lệ nguồn.
- PASS trên máy QA theo người dùng: Facecam dọc đúng chiều, chuyển động trái/phải đúng, không còn giật rõ.
- Audio mixed có track trong mẫu; đồng bộ nghe/nhìn: NOT VERIFIED, duration track không chứng minh sync.
- Playback cũ/mới, landscape, xoay giữa phiên, không Facecam, screenshot trên APK cuối: đang kiểm tra tiếp; chưa đánh dấu PASS.
- Livestream/region và thiết bị khác: chưa kiểm thử runtime trong task; không thay logic hiện có.

## BUG-03 — P2 integration request

`VideoPreviewActivity.kt` đã có p2_player_back, 48dp, top-left, margin theo system bars/cutout và finish() riêng player. `video_details_screen.dart` có AppBar Back. Không thêm nút trùng. P2 cần kiểm tra runtime visibility/z-order khi MediaController mở, thư viện giữ state, Back không dừng recording và không sửa/xóa video. Nếu APK cũ thiếu block này, tích hợp đúng block hiện có; chỉ sửa z-order khi tái hiện bị che. Không tự sửa code P2.

Floating Controls thiếu Stop ngoài app: **WAITING FOR TEAM DECISION**; giữ nguyên toàn bộ overlay/timer/permission/notification controls.
