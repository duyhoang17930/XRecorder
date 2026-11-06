# TASK 02.2 — Screenshot UX & visual polish

Ngày: 06/11/2026. Giữ Dark Bento Studio, Manrope offline, Lucide, navigation và dữ liệu hiện có. Không triển khai Task 03, không đổi encoder/audio pipeline hoặc preset chất lượng, không commit/push.

## 1. Nguyên nhân

- **Processing/Stop/timer sai ngữ cảnh:** `CaptureStatusBar` coi mọi session busy là video, kể cả screenshot. `finalizing` được map thành Processing; một Wrap riêng đẩy View/close xuống hàng thứ hai. Trạng thái completed không có thời hạn hiển thị. Native screenshot thực sự xuất PNG, không phải vô tình chạy video.
- **Xin quyền gây nhiều bước:** trước đây screenshot đi qua cả yêu cầu POST_NOTIFICATIONS. Thao tác này không cần thiết để khởi động foreground service; vẫn phải có notification của service. [Tài liệu notification permission chính thức](https://developer.android.com/develop/ui/compose/notifications/notification-permission).
- **Dễ chụp trúng điều khiển của app:** trước đây app vẫn ở foreground trong countdown. Luồng mới thu nhỏ app sau approval, cho người dùng 3 giây chuyển tới màn hình cần chụp; không thêm overlay/accessibility permission.
- **Mất sự kiện khi có hai observer:** native test tái hiện getter `sessions` tạo nhiều `receiveBroadcastStream()` trên cùng EventChannel. Subscription sau thay callback của subscription trước; có thể gặp “No active stream to cancel”. Đã dùng một broadcast stream chung giữa các AndroidRecordingService instance và thêm regression test hai observer.
- **Light hơi phẳng:** canvas gần trắng/card trắng và nút Record idle màu đỏ, trong khi primary khác màu cam. Chỉnh canvas trung tính nhẹ, hero bớt tint/border cam; primary idle dùng cam, success teal, recording-active đỏ.
- **Empty state sai nguồn:** cùng một mô tả “Choose a folder…” được dùng cho cả App media, selected folder và Photo Library. Đã tách theo nguồn, loại media và search.

## 2. Luồng Screenshot hiện tại

`Screenshot → system consent thật → app thu nhỏ → countdown 3/2/1 → lấy một frame → lưu PNG → dừng capture/service → Photo Library cập nhật → thông báo saved/View/× khi trở lại app`.

Countdown chỉ bắt đầu sau approval. Không có màn setup trung gian, không tự chụp lại. Native giữ busy guard; Dart khóa request ngay khi gửi để chặn nhấn lặp trước acknowledgement. Screenshot dùng label riêng: permission/countdown/capturing/saving/saved/cancel/error; không có timer/Pause/Resume/Stop của video. Cancel chỉ có trong countdown và gọi native cancel hiện có. Permission pending không hiện panel đỏ. Trong lúc chụp/lưu, app không vẽ một thanh Processing kéo dài.

Native ngừng VirtualDisplay/MediaProjection ngay khi đã nhận image duy nhất. Reader sống tới khi worker dùng xong image; bitmap luôn recycle trong finally, kể cả lỗi ghi/OOM. Sau đó release reader, gỡ foreground notification và dừng service. Không duy trì projection để tránh hộp quyền lần sau. completed vẫn là kết quả terminal có URI để tra cứu; UI/busy đã trở về trạng thái bình thường.

Consent là UI của hệ điều hành, không giả lập hay restyle. Mỗi session dùng token mới; Android14+ không cho tái sử dụng token để tạo thêm VirtualDisplay. [Tài liệu MediaProjection chính thức](https://developer.android.com/media/grow/media-projection).

App không tự quay lại foreground sau capture: người dùng chọn thời điểm trở lại. Hướng dẫn “minimizes after approval · 3s delay” có ngay gần thao tác Screenshot. Không hứa hiển thị countdown overlay trong ứng dụng khác. Notification screenshot có countdown/Cancel nếu thiết bị cho phép notifications; không yêu cầu quyền notification mới cho screenshot.

## 3. Thông báo gọn và thời hạn

Card nằm trên thanh điều hướng, một hàng ở cỡ chữ thường: icon teal, **Screenshot saved**, **View**, **×**. Touch target giữ tối thiểu48dp. Không có hàng điều khiển thứ hai, shadow/blur hoặc animation trang trí liên tục. Khi chữ lớn được phép tăng chiều cao để không cắt chữ.

- Saved tự ẩn sau **5 giây** ở foreground; nếu hoàn tất trong background, chờ lần trở lại để người dùng có thời gian xem. Rời foreground tạm dừng timeout; lần trở lại có cửa sổ5 giây.
- View đóng feedback ngay và mở **Photo preview của đúng URI PNG đã lưu**; × đóng ngay, không điều hướng.
- Native event lặp/refresh không phát lại kết quả đã dismiss/hết hạn; app startup không báo lại một saved session lịch sử.
- Hủy/Back consent về idle, không output/false success. Lỗi screenshot dùng copy thân thiện; lỗi operational có một nơi hiển thị, tránh card và snackbar báo trùng. Error có10 giây theo quy ước Task02.1, không áp timeout5 giây của thông báo thành công cho lỗi cần xử lý.
- Kết quả video cũng dùng card gọn “Video saved”; controls của video đang chạy/pause/stop vẫn giữ.

## 4. Copy và visual polish

Recording settings dùng “Your device may ask for screen access before recording. Visible content may be captured.” và “Video quality and FPS depend on your device. Changes apply next time.” Giữ cảnh báo nội dung nhạy cảm, protected audio và giới hạn Performance mode; không đổi settings/presets.

Light canvas `#F0F3F8`, card trắng, hero wash cam3% với border neutral. Record idle dùng primary cam, active recording giữ đỏ. Palette Dark giữ nguyên; card success dùng token teal của từng theme. Không thêm font/icon/dependency/asset hoặc hiệu ứng nặng. Contrast suite hiện có vẫn được chạy.

Empty states: App media video “No recordings yet / Your videos will appear here”; photos “No screenshots yet”; selected folder “No videos/photos in this folder”; search “No matching media”.

## 5. Phạm vi file

- `lib/features/recording/recording_service.dart`: broadcast stream, request guard, feedback lifecycle/timer, screenshot/video UI separation và compact card.
- `lib/features/recording/capture_status_presentation.dart`: mapping screenshot riêng.
- `lib/features/recording/recording_setup_sheet.dart`, `lib/features/settings/recording_settings_form.dart`: copy và đóng sheet trước khi gọi screenshot.
- `lib/core/widgets/studio_create_sheet.dart`, `studio_widgets.dart`, `lib/core/constants/design_tokens.dart`: hero/primary/color hierarchy.
- `lib/features/media/media_library_screen.dart`: contextual empty copy và lời giải thích thu nhỏ app.
- Native `recording/CaptureBridge.kt`: consent screenshot trực tiếp, thu nhỏ sau approval. `CaptureService.kt`: notification screenshot riêng và cleanup một image.
- Mới `test/screenshot_ux_test.dart`, `integration_test/screenshot_visual_test.dart`, `integration_test/screenshot_native_test.dart`; cập nhật kỳ vọng liên quan trong các tests có sẵn. `tool/verify_ui.ps1` thêm hai mode screenshot, vẫn giữ guard serial/AVD và keep-app-running.
- README, báo cáo/ảnh Task02.2 và local conventions. Những thay đổi Task01/02/02.1 đã có trong worktree được giữ; scope được so với snapshot đầu Task02.2, không so toàn bộ dirty diff với HEAD.

## 6. Validation

| Check | Kết quả thực thi |
|---|---|
| Dart format | Đã chạy các file lib/test/integration/driver |
| Flutter analyze | **No issues found** |
| Flutter unit/widget suite | **88/88 passed** |
| Android debug build | Thành công; entry point production `lib/main.dart`, ba ABI |
| Native integration API36 | **1 scenario passed**, gồm Cancel, Back, hai lần chụp, nhấn lặp, View, expiry, cleanup, video/microphone/Pause/Resume/Stop |
| Visual debug khoảng411dp | **1 scenario passed**, 9 screenshots Light/Dark và chữ200% |
| Visual320dp | **1 scenario passed**, đủ9ảnh; gồm Light/Dark và photos200%; saved card200% được kiểm tra bằng widget tests |
| Production smoke | **Passed** sau `install -r` main APK: home Ready, không có saved lịch sử/Processing/Stop; [JSON](production_smoke.json), [ảnh](production_smoke.png) |
| Format/runner syntax/diff | Format sạch; PowerShell parse được; `git diff --check` không có whitespace error, chỉ cảnh báo CRLF |

Không cộng teardown vào số scenario. Không dùng kết quả trước của Task02.1 để chứng nhận source Task02.2.

Native output thực tế: hai PNG **1080×2400**, lần lượt **1,374,869** và **1,374,633 bytes**. Countdown tới lúc capturing: **3,109ms / 3,132ms**; saving→completed: **1,362ms / 1,069ms** trên emulator debug. Không suy ra tốc độ máy thật từ số này. Timeline không có state recording cho screenshot. Cả hai PNG decode được và có nội dung nhiều màu; [ảnh mẫu thật](native/captured-screen.png) là launcher của AVD test, không có giao diện điều khiển của 3HRecorder hay hộp consent.

Lượt video tạo MP4, metadata có audio track và duration **4,445ms**, sau Pause/Resume. Đây là kiểm tra chức năng/track presence; không chứng nhận chất lượng âm thanh, FPS hoặc A/V sync.

[Native assertions/timeline](native/emulator_verification.json) · [ADB cleanup proof](native/host_cleanup_verification.json) · [APK integrity/hash](apk_verification.json). ADB ghi nhận service “(nothing)” và Media Projection `null` sau mỗi screenshot và sau video.

[Tổng hợp verification, source scope và smoke result](verification.json).

Production debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, **165,377,596 bytes**, SHA256 `43d46868f4a6b716d60c46e2fdb9dc492429114045b65dba71d7a44ba0133916`. ZIP CRC hợp lệ, kernel không chứa entry point/marker integration. Đây là APK debug nhiều ABI, không phải số đo release. Canonical APK đã khôi phục từ bản main sau khi build visual harness.

## 7. Before/after và giới hạn

[Ảnh ghép so sánh](comparison.png) · [Danh mục screenshots](SCREENSHOTS.md).

Before được chụp bằng APK source đầu Task02.2 trên AVD test, dùng fixture rỗng và event tổng hợp. After dùng cùng fixture; ảnh output native là lượt riêng. Đã xem ảnh mẫu PNG, card feedback native và bảng ghép Light/Dark/Processing/settings. Reference screenshot từ người dùng không bị sửa hoặc dùng làm fixture.

Các lần thất bại được giữ trong `.claude-local/scratchpad/task022/`: compile const Uri trong test; timer fixture chưa sở hữu controller lifecycle; constraint chiều cao ban đầu quá chặt; native test phát hiện stream tranh callback; visual320dp thiếu frame pump sau timeout. Đã sửa nguyên nhân và chạy lại, không đổi timeout5 giây để né assertion. Native stream là lỗi contract đã tái hiện; các lỗi const/lifecycle fixture/frame pump là lỗi harness.

Giới hạn còn lại:

- Chỉ runtime trên API36 emulator. Chưa chứng nhận OEM/máy thật, API24–35, rotation/lock hoặc protected screens.
- Storage full, lỗi command/native capture và late acknowledgement được kiểm tra bằng fake/unit contracts; không làm đầy bộ nhớ hoặc cố tình phá service của thiết bị. Không tuyên bố các lỗi phần cứng/storage đó đã được fault-inject bằng native.
- Không đo FPS, nhiệt, pin hay phiên quay dài; đây không phải Task03. Notification countdown tùy quyền notification hiện có của thiết bị. Khi app đang background không có overlay countdown riêng.
- UI nhỏ/chữ200% có thể tăng chiều cao card; không ép thu nhỏ chữ hoặc cắt nội dung để giữ một hàng.

## 8. Bảo toàn dữ liệu và scope review

Chỉ dùng **emulator-5560 / ThreeHRecorder_Task021 / API36** và data directory riêng đã tạo từ Task02.1. Mỗi lần runner đều kiểm tra tên AVD trước thao tác. Không cài/force-stop/uninstall/clear-data hoặc chạy harness trên emulator người dùng **emulator-5554**. Luôn `--keep-app-running`; cleanup chỉ với URI do test vừa tạo, kiểm tra app-owned trước trash/permanent delete. Không xóa media hay private data ngoài các fixture đó.

Main APK đã cài lại bằng `install -r` trên AVD test sau integration; đã dọn đúng file dump tạm do Task02.2 tạo và tắt riêng AVD test để trả RAM. Reference assets và thư mục Task01/02/02.1 không bị ghi đè.

So hash snapshot đầu Task02.2: **18 file Kotlin ngoài CaptureBridge/CaptureService không đổi**, gồm encoder, audio, muxer, MediaOutput, catalog, media actions và editor/export. Application ID, manifest/permissions, font/icon package, preference schema và presets không đổi. Self-review scope/diff; không có independent reviewer. Logs build/analyze/tests/native/visual và snapshot scope nằm trong `.claude-local/scratchpad/task022/` (Git-ignored).

Chạy lại bằng AVD test đã tạo riêng:

```powershell
.\tool\verify_ui.ps1 -Mode screenshot-visual
.\tool\verify_ui.ps1 -Mode screenshot-native
```

Native mode cần xử lý consent và trở lại app tại marker RETURN; automation nội bộ chỉ thao tác đúng AVD guard. Sau integration cài lại APK `lib/main.dart` bằng `adb -s <verified-test-serial> install -r`; không uninstall.
