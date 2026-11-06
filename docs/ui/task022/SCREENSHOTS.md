# TASK 02.2 — Screenshots

[Báo cáo](REPORT_VI.md) · [Ảnh ghép so sánh](comparison.png)

Visual before/after dùng cùng catalog rỗng và event screenshot tổng hợp; không thực hiện capture hoặc ghi settings/draft. API36, debug assertions bật.

| Màn hình | Before ~411dp | After ~411dp | After320dp |
|---|---|---|---|
| Home Light | [Ảnh](before/screenshots/01_home_light.png) | [Ảnh](after/screenshots/01_home_light.png) | [Ảnh](compact/screenshots/01_home_light.png) |
| Permission pending | [Ảnh](before/screenshots/02_permission_pending.png) | [Ảnh](after/screenshots/02_permission_pending.png) | [Ảnh](compact/screenshots/02_permission_pending.png) |
| Countdown | [Ảnh](before/screenshots/03_countdown.png) | [Ảnh](after/screenshots/03_countdown.png) | [Ảnh](compact/screenshots/03_countdown.png) |
| Saving | [Ảnh](before/screenshots/04_saving.png) | [Ảnh](after/screenshots/04_saving.png) | [Ảnh](compact/screenshots/04_saving.png) |
| Saved Light | [Ảnh](before/screenshots/05_saved_light.png) | [Ảnh](after/screenshots/05_saved_light.png) | [Ảnh](compact/screenshots/05_saved_light.png) |
| Saved Dark | [Ảnh](before/screenshots/06_saved_dark.png) | [Ảnh](after/screenshots/06_saved_dark.png) | [Ảnh](compact/screenshots/06_saved_dark.png) |
| Recording settings | [Ảnh](before/screenshots/07_recording_settings.png) | [Ảnh](after/screenshots/07_recording_settings.png) | [Ảnh](compact/screenshots/07_recording_settings.png) |
| Photo empty | [Ảnh](before/screenshots/08_photos_empty.png) | [Ảnh](after/screenshots/08_photos_empty.png) | [Ảnh](compact/screenshots/08_photos_empty.png) |
| Photo200% | [Ảnh](before/screenshots/09_photos_large_text.png) | [Ảnh](after/screenshots/09_photos_large_text.png) | [Ảnh](compact/screenshots/09_photos_large_text.png) |

Ảnh native thật, fixture chỉ là màn hình launcher AVD test:

- [PNG app chụp](native/captured-screen.png),1080×2400.
- [Feedback sau khi lưu thật](native/screenshots/01_real_saved_feedback.png).
- [View mở Photo preview](native/screenshots/02_real_image_preview.png).
- [Feedback đã tự ẩn](native/screenshots/03_feedback_expired.png).
- [Production main APK trở về Ready, không replay feedback cũ](production_smoke.png).

Ảnh Flutter visual không bao gồm status/navigation bars của hệ điều hành. PNG native có thể chứa privacy indicator của hệ điều hành; app không che hoặc giả lập indicator đó.
