# UI/UX 05B — Bàn giao P1

Ngày: 11/11/2026. HEAD: `e008fbb095be62db9538f4c598cbff89e6ceb7aa`, nhánh `main`.
P1 implementation và test P1 được giữ nguyên. TASK10 chưa bắt đầu.

## 1. Bốn test FAIL còn lại

Reproduce trên host, không dùng thiết bị hay capture:

```text
flutter test --no-pub test/recording_setup_sheet_test.dart
```

Lệnh trên là lệnh reproduction cho P1. Bằng chứng thực thi trong task này là full suite `flutter test --no-pub`: **463 PASS / 4 FAIL**, [log đầy đủ](full_host_final_161726_24f0a8b3.txt).

| Test | Expected / Actual | Nguyên nhân xác định từ source |
|---|---|---|
| a stale selection is rejected until the user selects a supported tuple | Expected resolution `1080p FHD`; actual `720p HD`. Service chưa được phép start ở assertion trước đó. | `RecordingSettingsForm.didChangeDependencies` gọi `_normalizeSelection` sau capabilities; hàm cập nhật resolution/FPS/codec/bitrate khi tuple cũ không hỗ trợ. Test yêu cầu “No silent normalization”. Hai contract đang mâu thuẫn. |
| Setup pins actions… 320dp | Không tìm thấy widget handle, lỗi khi `getRect(handle)`. | Finder cố định `Container` kích thước 36×4; theme ứng dụng hiện là 40×3. |
| Setup pins actions… 360dp | Như trên. | Như trên. |
| Setup pins actions… 411dp | Như trên. | Như trên. |

Source để review:

- [Test stale selection](../../../test/recording_setup_sheet_test.dart:94).
- [Finder và các assertion pinned controls](../../../test/recording_setup_sheet_test.dart:190).
- [Normalization của form P1](../../../lib/features/settings/recording_settings_form.dart:21).
- [Theme handle hiện tại](../../../lib/core/ui/theme/app_theme.dart:198).

**Không thể kết luận ba test pinned controls chứng minh layout bị hỏng:** chúng dừng tại locator trước khi chạy hết các assertion pinning. Không bỏ hay nới assertion. P1 cần cập nhật locator theo component/semantics thực tế rồi kiểm tra lại geometry. Với stale selection, P1 cần quyết định chính sách normalize hay yêu cầu người dùng chọn lại và đồng bộ implementation/test.

## 2. Capabilities của QA AVD

AVD đã xác nhận: `ThreeHRecorder_TASK09B_API36`, serial `emulator-5570`.
[Native result](native_player_result_final.txt) có query **chỉ đọc** `CaptureConfig.capabilities(activity)`:

- Audio sources: mute, microphone, internal, mixed.
- Presets: **rỗng** ở query này.
- AVC: c2.android.avc.encoder / OMX.google.h264.encoder; HEVC: c2.android.hevc.encoder. Cả ba báo hardwareAccelerated=false.
- HEVC supported=false, noiseReduction=false.

Đây là snapshot của query và môi trường QA, không phải toàn bộ capability được CaptureBridge bổ sung, không chứng minh recording hoạt động trên thiết bị thật. Không fake-enable preset, không đổi codec/default/permissions, không chạy capture.

[Ảnh màn hình đích Settings hiện tại](final_recording_destination_light.png) cho thấy các lựa chọn không được thiết bị quảng bá bị disabled. Cần thiết bị/capability phù hợp và P1 approval riêng trước gate recording integration.

## 3. Presentation/localization cần P1 phê duyệt

Settings P2 đã gộp hai entry thành **Recording settings**, đi tới route cũ `/settings/audio-video`. Không thay form.

Màn hình P1 còn title hardcoded **Audio & Video Settings**, cùng các label tiếng Anh: Recording mode, Resolution, Target FPS, Bitrate, Video codec, Orientation, Audio source và các control bổ sung. [Danh sách source cần review](hardcoded_ui_review.json). Trong screenshot Sort tiếng Việt, recording card của P1 vẫn có tiếng Anh.

Đề xuất cho owner: dùng key `recordingSettings` cho tiêu đề; chuyển presentation strings sang localization, giữ nguyên giá trị lưu trữ/capability mapping. **WAITING FOR P1 APPROVAL**; chưa tích hợp thay đổi này.

Yêu cầu default first-install Follow System còn từ UI02B: **WAITING FOR P1 APPROVAL** nếu cần đổi default của Settings/native shared initialization. UI05B không đổi mặc định hay migration. Người dùng QA hiện có explicit Light/English; task khôi phục đúng hai lựa chọn đó.

## 4. Bảo toàn và bước tiếp

[Hash source](final_host_storage_preservation.json): 32 file được liệt kê trong nhóm protected, gồm MainActivity, recording native/Dart, SettingsController, form/settings screen và EditorPreview.kt đều unchanged. `studio_create_sheet.dart` cũng giữ nguyên trong manifest baseline. Fix frame khi rotate của EditorPreview.kt được bảo vệ.

[Hash dữ liệu cuối](final_device_preservation.json): 7 file private và 4 media fixture kiểm tra khớp; package UID không đổi. Không reset/clear/uninstall, không đổi SAF grants, không commit/push.

P1 cần:

1. Giải quyết hai contract/test issues trên; chạy lại bốn case và full suite.
2. Phê duyệt/tích hợp localization presentation trong phần P1.
3. Xác minh capabilities và recording trên môi trường phù hợp, trong gate riêng.
4. Sau khi có bằng chứng, đánh giá lại readiness TASK10; UI05B không tự mở gate này.
