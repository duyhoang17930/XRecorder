# TASK 13 — P2 INTEGRATION REQUESTS (F22–F23)

**Role:** P1 — Capture, Realtime & Livestream  
**Recipient:** P2 — Platform & UI / Settings  
**Date:** 2026-11-08  
**Topic:** Shake to Stop & Touch Indicator Integration

---

## 1. Yêu cầu liên quan đến F22 — Shake to Stop

- **Setting hiện tại:** Trong `SettingsController` đã có trường `shake` (boolean, mặc định `true`).
- **Giao diện người dùng:** Nếu P2 cần hiển thị Switch cho "Shake to Stop" trên màn hình Cài đặt (`recording_settings_form.dart` hoặc `audio_video_settings_screen.dart`), P2 có thể thêm `SwitchListTile` tương tự các setting khác. P1 đã sẵn sàng nhận trường `shakeToStop` trong `RecordingSettings` và truyền sang native qua `start()`.

---

## 2. Yêu cầu liên quan đến F23 — Touch Indicator

- **Giới hạn hệ điều hành Android (OS Limitation):**
  - Android OS không cho phép ứng dụng bên thứ ba theo dõi sự kiện chạm toàn màn hình trên các ứng dụng khác mà không có `AccessibilityService` (quyền nhạy cảm).
  - Để hiển thị thao tác chạm trên toàn hệ thống trong video quay màn hình, người dùng cần bật tính năng **"Show taps" (Hiển thị thao tác nhấn)** trong **Developer options** (`Cài đặt cho nhà phát triển`).
- **Đề xuất tích hợp cho P2:**
  - Hộp thoại hướng dẫn `Touch-indicator guidance` trong `recording_settings_form.dart` hiện đã giải thích cơ chế này.
  - Nếu cần nâng cao trải nghiệm, P2 có thể xem xét bổ sung một nút bấm mở trực tiếp màn hình `android.provider.Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS` (nếu Developer Options đã được người dùng kích hoạt trên thiết bị) để hỗ trợ người dùng bật nhanh.
