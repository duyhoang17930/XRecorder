# Task 03 — P2 Integration Request

## IR-03-01 — Stereo configuration contract (P1)

- Files P2: `lib/core/domain/models.dart` (RecordingSettings/RecordingCapabilities), `lib/features/settings/settings_controller.dart` nếu lưu lựa chọn.
- Vấn đề: pipeline/schema hiện chỉ mono; Task 03 yêu cầu mono/stereo theo capability nhưng không có channel-count contract. Không thêm UI trong task này.
- Thay đổi tối thiểu đề xuất: `RecordingSettings.audioChannelCount` kiểu int, mặc định 1; `RecordingCapabilities.audioChannelCounts` kiểu Set<int>, mặc định `{1}` tương thích ngược. Persistence chỉ cần nếu owner quyết định cho phép chọn channel count; không bắt buộc thêm control mới.
- Sau tích hợp, P1 mới mở rộng PCM/channel conversion và AAC mapping cho 2 channels khi các input + encoder hỗ trợ. Hiện chưa advertise stereo, chưa đổi shared model hoặc giả thành công.
- Acceptance: cấu hình cũ vẫn mono; chỉ công bố 2 sau probe phù hợp và test MP4 stereo/Mixed channel conversion trên Android; codec/input lỗi phải fail rõ, không âm thầm đổi nguồn. Không thay layout/style.
- Priority: P1 để nghiệm thu phần stereo; không chặn pipeline mono hiện hữu. Chỉ ghi bàn giao trong repo, chưa gửi ra ngoài.
