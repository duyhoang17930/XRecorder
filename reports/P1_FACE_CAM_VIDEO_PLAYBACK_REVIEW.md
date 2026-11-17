# P1 Facecam và video playback — 2026-11-17

Baseline: `main`, `9f5dcc9`. Thiết bị QA được cho phép: 2602DPT53G, Android 16/API 36, màn hình 1268×2756. Giữ nguyên tài liệu có sẵn trong `docs/reports/RECORDING_PLAYBACK_REVIEW_20261117/`. P1 đã commit `3567cb9` theo yêu cầu sau khi đánh giá Facecam. Sau đó người dùng cho phép sửa thêm: Back theo playback controls, khóa dọc 5 lựa chọn, nút + giữa thanh và hiệu ứng chuyển tab. Chỉ sửa các component này; không đổi theme, Recording Settings, VideoEncoder hay Floating Controls. Phần UI bổ sung đang ở working tree; không push.

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
- PASS trên APK checkpoint P1: Start → Pause (journal paused) → Resume (recording) → background/foreground giữ session → Stop; finalize content://media/external/video/media/1514; projection được giải phóng; Library hiện video mới Recording_1794904491559.mp4.
- PASS: hai MP4 sau sửa (16,52s và 137,48s) decode toàn bộ sạch, AVC 1080×1920; bbox [98,0,981,1920], giữ đủ tỷ lệ nguồn.
- PASS trên máy QA theo người dùng: Facecam dọc đúng chiều, chuyển động trái/phải đúng, không còn giật rõ.
- Audio mixed có track trong mẫu; đồng bộ nghe/nhìn: NOT VERIFIED, duration track không chứng minh sync.
- PASS runtime: playback mới URI 1514 và playback cũ URI 1342, VideoView bounds [0,251,1268,2505] = tỷ lệ 9:16; frame decode được giữ đầy đủ. MP4 cũ có owner_package_name=NULL, cần URI grant chỉ đọc tạm một file theo luồng mở từ Files; không cấp quyền toàn thư viện.
- NOT VERIFIED trên APK cuối: quay ngang mới, xoay giữa phiên, không Facecam, screenshot và Back khi đang recording. Không lấy unit tests thay cho các phép thử này.
- Livestream/region và thiết bị khác: chưa kiểm thử runtime trong task; không thay logic hiện có.

## BUG-03 — Viewer Back, được người dùng cấp quyền sửa P2

Nút Back hiện có vẫn giữ 48dp, vị trí top-left, SafeArea và hành vi finish riêng player. Theo yêu cầu mới, nút chỉ hiển thị khi MediaController hiện; hide() của controls cũng ẩn nút. Không thêm nút trùng, không đổi timeline/player layout.

PASS trên máy: controls tự ẩn → Back ẩn; chạm video → controls và Back hiện; chạm Back → Details → Library, giữ media. Bounds Back [26,182,182,338], 156px ở density 3,25 tương ứng 48dp. File video được giữ nguyên. Back khi đang recording: chưa đo runtime; source finish không gọi CaptureService.

## Yêu cầu UI bổ sung đã thực hiện

- Video, Photo, Edit hub, Settings và menu + giữ portraitUp. Rời các tab vào viewer/trình chỉnh sửa thực tế trả lại orientation mặc định. Không ép landscape editor hay đổi preference hệ thống lâu dài.
- Thanh dưới theo thứ tự Video–Photo–+–Edit–Settings. + ở giữa, nhô lên và chồng khung; khoảng trống giữa thanh tách khỏi touch targets Photo/Edit. Giữ icon/màu/font hiện có.
- Chuyển tab trượt ngang theo vị trí tab; giữ các Navigator mounted, scroll position và trạng thái từng nhánh. Outgoing branch không nhận touch/semantics. Menu + giữ bottom sheet từ dưới lên. Reduce Motion chuyển tức thì.

| File bổ sung | Khối thay đổi / ảnh hưởng |
|---|---|
| media/VideoPreviewActivity.kt | show/hide của MediaController đồng bộ visibility nút Back; không đổi decoder |
| lib/app/app.dart | Listener áp portrait cho 4 tab chính; + là sheet nên kế thừa khóa; gỡ khóa ngoài các tab |
| lib/core/widgets/studio_shell.dart | Chỉ StudioBottomNavigation: gap giữa, Stack đặt + và offset indicator |
| lib/core/widgets/studio_tab_transition.dart | Container render chuyển tab, giữ child Navigators và trạng thái |
| lib/app/router/app_router.dart | Dùng container chuyển động trên cùng StatefulShellRoute; giữ nguyên paths/branches |
| test/home_orientation_test.dart | Kiểm tra các tab, +, viewer/editor và trả lại orientation |
| test/studio_tab_transition_test.dart | Hai chiều, đảo tab nhanh, scroll state và Reduce Motion |
| test/ui_startup_navigation_test.dart | Kiểm tra + giữa/nhô cao/không đè touch target ở compact/RTL/chữ lớn |

PASS: 23 tests cuối liên quan animation/navigation/orientation/route/modal/footer; analyze sạch; build debug thành công. Test native 168 PASS sau thay đổi Player. Trước đó 32 test UI PASS, 1 FAIL tương phản Arabic/light/text scale 2: 1,30 < 4,5. Đã chạy lại test này với component tại commit 3567cb9, cùng tỷ lệ 1,30 và cùng màu; lỗi baseline, không sửa màu/theme trong task.

PASS thiết bị trước khi thêm animation: cả 5 lựa chọn vẫn rotation=0 khi hệ thống yêu cầu landscape. Bounds nút + [550,2457,719,2626]; Photo kết thúc x=537, Edit bắt đầu x=732: không giao vùng chạm; + cao hơn các tab 39px. Sau thêm animation: Video↔Photo runtime PASS; kiểm tra lại Video/Photo/Edit/Settings PASS, bước + bị gián đoạn khi người dùng đang mở Media Details, không coi là lỗi sản phẩm hoặc PASS toàn bộ lượt này. Bộ test Flutter đủ 5 lựa chọn PASS.

## P2 integration còn lại / trường hợp chưa kiểm chứng

Không còn yêu cầu thêm nút Back mới. Với media cũ không còn owner, P2 cần giữ luồng Files/SAF cấp URI grant cụ thể trước khi preview; deep link không có quyền không chứng minh lỗi decoder. Không tự thêm quyền storage rộng hoặc sửa MediaCatalog. Cần kiểm thử thêm rotation metadata của mẫu có display matrix, video ngang mới, A/V sync nghe nhìn và thiết bị khác.

Floating Controls thiếu Stop ngoài app: **WAITING FOR TEAM DECISION**; giữ nguyên toàn bộ overlay/timer/permission/notification controls.
