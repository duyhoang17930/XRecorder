# Baseline FINAL P2/P3 — 07/11/2026

Source: `b9aea926c1ab024dd32a139e5ab43b0e0e584908`, branch main.
Lúc bắt đầu chỉ prompt FINAL mới là untracked; không có sửa code chưa commit.
Nhiệm vụ này không commit/push, không thay P1, không xóa dữ liệu/model.

Đã đọc cấu trúc lib/app/core/features, native editor/media/MainActivity, tests,
README/spec/master/UX và bộ progress/contracts/evidence/reuse hiện tại. Spec cũ
đề xuất server AI và README ghi AI deferred đã lỗi thời so với quyết định Whisper
offline hiện tại; không áp dụng đề xuất kiến trúc cũ như trạng thái implementation.

16 file P1 được SHA256 tại `build/verification/final_p2_p3/p1_hashes_before.json`:
recording Dart/native, hai settings forms, studio_create_sheet. Không đổi capture
events/consent/controller. Bằng chứng diff không thay thế runtime P1 signoff.

| Gate | Baseline đã xác minh | Việc tiếp theo |
|---|---|---|
| Host | Analyze sạch;138 unit/widget PASS,21s | Regression sau sửa |
| A performance |3 profile trials API36,1009 ảnh,30 drag400ms: raster p95 43.711/40.386/45.366ms; build p95 7.181/6.268/12.088ms | Bỏ outer card clip có ripple boundary, đo lại3 lượt;320/411/theme matrix và soak |
| Memory | Decoded cache21,189,216bytes cả3 lượt; compressed cache có bounds | Preview30x/export-cancel20x/ASR10x; time-series, không suy leak từ một snapshot |
| C ASR | Native engine/source/model store có thật; báo cáo trước chỉ1 mẫu vi | Thêm3 MALE test+3 FEMALE train,2 English, noise/silence controls; đo CER/WER/RTF/RAM |
| D/E media/recovery | Code/tests/output cũ còn tồn tại | Rerun current native outputs và fault tests; kiểm frame/audio thực |
| B/F physical | Chỉ AVD QA kết nối; không có người dùng/máy thật được cấp quyền | NOT RUN physical/HCI/TalkBack gesture, thermal/battery/SD và final P1 integration |

Môi trường: Flutter3.47.8/Dart3.13.7, JBR21, min24/target36, Media3 1.11.1,
`emulator-5560 / ThreeHRecorder_Task021`, API36 x86_64, SwiftShader,
1080×2400/density420≈411dp. Các image cài trên host: API34/36/37.1;
không mặc định một image tương đương một thiết bị đã test.

Raw traces và corpus fingerprint từng lượt:
`build/verification/final_p2_p3/performance/before_*/emulator_verification.json`.
`scrollTimeline` là VM timeline Dart/Embedder/GC; ring buffer có giới hạn nên event
counts có thể ít hơn FrameTiming. Không so causal với số cũ1006 ảnh/khác harness.
Trace dominated bởi GPURasterizer/SurfaceFrame::Submit trên GLES software;
không tự kết luận 60fps hay cần rewrite renderer.

P0/P1 backlog: kiểm invalid ASR request không để job queued vĩnh viễn; cancel và
late result; mẫu đa dạng/default model; preview dispose/poll; callback ownership;
fault publication/recovery. Chỉ sửa lỗi tái hiện, giữ API/version1 draft tương thích.

Kết quả sau sửa nằm tại [Final Quality Report](P2_P3_FINAL_QUALITY_REPORT_VI.md),
[performance](P2_P3_PERFORMANCE_BEFORE_AFTER.md) và [AI evaluation](P2_P3_AI_SUBTITLE_EVALUATION.md).
Đây là baseline lịch sử của đúng nhiệm vụ; các số trước sửa không được đổi thành
runtime verdict của bản sau. Current raw evidence dùng `final_p2_p3`, tách khỏi
artifacts nhiệm vụ implementation trước ở `p2_p3`.

Phân loại tại baseline: **implemented/verified** host138 tests và artifacts cũ có
provenance; **implemented/unverified trong task mới** runtime P2/P3 cần chạy lại;
**not implemented tại baseline** CPU graph-node abort propagation, native stage
timings, stale poll guard và catalog EXIF display bounds; **external gates** máy
thật/người thử/P1-ready build. Các mục mới đã được xử lý sau baseline được ghi ở
Final Quality Report, không sửa ngược evidence trước sửa.
