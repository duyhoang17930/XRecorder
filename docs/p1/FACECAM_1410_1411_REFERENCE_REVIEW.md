# Facecam — đối chiếu video 1410 / 1411

Ngày: 2026-11-10. Phân tích offline bằng OpenCV 4.6; không dùng ADB, không sửa source trong lượt đối chiếu.

| Input | Kích thước | Frame giải mã | FPS trung bình từ container | Thời lượng xấp xỉ |
|---|---:|---:|---:|---:|
| `/home/hieu/Downloads/1410.mp4` | 1280×720 | 306 | 33.379 | 9.167s |
| `/home/hieu/Downloads/1411.mp4` | 1080×1920 | 106 | 24.957 | 4.247s |

**Quan sát:** 1411 là cảnh camera toàn khung đi qua các góc trung gian; frame 20–35 cho thấy hướng cảnh đổi dần qua từng frame. 1410 là screen recording có Facecam nhỏ; frame 30–45 cho thấy nhiều cặp hình gần như giữ nguyên xen kẽ các đoạn đổi hướng rõ hơn. Các video khác thời lượng, bố cục, chuyển động và pipeline; không thể coi là phép benchmark đồng điều kiện.

Trong vùng bên trong Facecam của 1410, 85/305 cặp frame kề nhau có mean absolute grayscale difference <0.5 trên thang 0–255; không có cặp giống hệt từng pixel. 1411 có 0/105 cặp dưới ngưỡng này khi xét toàn frame. ROI khác nhau nên các số này chỉ mô tả độ giống ảnh giải mã, **không đo camera FPS, dropped frames hoặc sensor/render latency**. Không đủ bằng chứng để đổi camera FPS, exposure hay encoder.

**Đối chiếu implementation:** luồng hiện tại đã thay gate bốn hướng + 400ms + ValueAnimator bằng góc unwrapped, One Euro Filter và một callback VSYNC. Matrix xử lý góc trung gian; kiểm thử toán học giữ mirror, tỷ lệ pixel và hướng người. Camera session, MediaProjection và layout theo Display được giữ nguyên. Giữ thông số filter hiện tại; cần clip sau patch để tinh chỉnh theo trải nghiệm thực tế.

**Evidence:**

- [1410 — vùng Facecam theo thời gian](test_evidence/facecam_reference_1411/1410_contact.jpg)
- [1410 — frame liên tiếp 30–45](test_evidence/facecam_reference_1411/1410_consecutive_frames_30_45.jpg)
- [1411 — toàn chuỗi tham chiếu](test_evidence/facecam_reference_1411/1411_contact.jpg)
- [1411 — frame liên tiếp 20–35](test_evidence/facecam_reference_1411/1411_consecutive_frames_20_35.jpg)
- [Metadata](test_evidence/facecam_reference_1411/metadata.json), [decoded-image similarity](test_evidence/facecam_reference_1411/decoded_frame_similarity.json).

Nhãn thời gian `~` và CSV chỉ là frame index / average FPS, không phải frame PTS chính xác. OpenCV trả timestamp không hợp lệ ở cuối clip nên không dùng để đo timing. Frame index là định danh dùng để đối chiếu.

**Trạng thái:** giải mã/đọc reference PASS; kiểm thử local của patch trước đó: 32 JVM + 14 Flutter PASS, native compile và diff check PASS. Lượt này chỉ thêm evidence và báo cáo, không chạy lại tests source không đổi. Không có build hash hoặc telemetry gắn với hai video; chúng không xác minh bản code sau patch. So khớp độ mượt sau patch, preview, TC01–12 trên điện thoại, MP4 mới, dropped frames, camera restarts và latency: **NOT VERIFIED**. Không commit/push.
