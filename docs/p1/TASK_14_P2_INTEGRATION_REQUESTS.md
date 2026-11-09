# TASK 14 — P2 INTEGRATION REQUESTS (F20–F21)

**Role:** P1 — Capture, Realtime & Livestream  
**Recipient:** P2 — Platform & UI / Settings  
**Date:** 2026-11-08  
**Topic:** Microphone Noise Suppression & Audio Ducking Integration

---

## 1. Yêu cầu liên quan đến F20 — Microphone Noise Suppression

- **Hiện tại:** Trong `recording_settings_form.dart` đã có switch `Microphone noise reduction` kết nối với `s.noise`.
- **Tình trạng:** P1 đã kết nối đầy đủ từ `RecordingSettings` sang `CaptureConfig` và gắn vào `NoiseSuppressor(mic.audioSessionId)`. Không cần thay đổi thêm từ P2.

---

## 2. Yêu cầu liên quan đến F21 — Audio Ducking

- **Ngữ cảnh:** P1 đã triển khai hoàn tất engine `AudioDuckingEngine` và tích hợp vào `SessionAudio.kt` cho chế độ `Mixed Stream`.
- **Đề xuất tích hợp cho P2:**
  - Khi UI freeze kết thúc, P2 có thể thêm trường `bool audioDucking = false` vào `RecordingSettings` (`lib/core/domain/models.dart`) và thêm thuộc tính `bool ducking = false` vào `SettingsController` (`lib/features/settings/settings_controller.dart`).
  - Trên giao diện cài đặt âm thanh (`recording_settings_form.dart` / `audio_video_settings_screen.dart`), P2 có thể bổ sung một Switch:
    - **Tiêu đề:** `Audio ducking (Tự động giảm âm lượng nền khi nói)`
    - **Điều kiện hiển thị/enable:** Chỉ khả dụng khi nguồn âm thanh được chọn là `Mixed Stream`.
    - **Mô tả:** `Tự động giảm âm lượng âm thanh nội bộ khi phát hiện giọng nói từ micro để giọng nói rõ ràng hơn.`
  - Phương thức `start()` của `recording_service.dart` đã sẵn sàng nhận tham số `audioDucking` và truyền xuống native `CaptureConfig`.
