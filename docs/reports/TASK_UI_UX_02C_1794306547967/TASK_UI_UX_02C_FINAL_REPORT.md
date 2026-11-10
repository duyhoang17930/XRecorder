# TASK UI/UX 02C — Kết quả triển khai và handoff

Ngày 10/11/2026 · **TASK: PARTIAL** · **TASK10: NOT STARTED**

## 1. Kết quả chính

Đã sửa crash Slider có reproduction đỏ → xanh, sửa layering modal, thêm replay onboarding không ghi preferences, chỉnh Settings, tích hợp MxT APP/URL/email và chặn gallery ngoài debug. Đã build/cài cập nhật, kiểm tra ứng dụng main trên AVD thật; không dùng entrypoint integration-test thay app.

**Chưa đóng task:** cold start debug còn chậm/không ổn định; đã gặp ANR trên APK baseline và timeout ở một số lượt debug mới. Handoff splash còn đổi vị trí wordmark. Chưa chứng minh đã sửa đúng hiện tượng Settings bị kéo méo ban đầu vì thiếu bộ ảnh/video người dùng mô tả.

| Hạng mục | Trạng thái | Phạm vi bằng chứng |
|---|---|---|
| A1 — Crash Photo Slider | PASS | Reproduction widget; Android min/max, kéo lặp, đổi tool; không assertion |
| A2 — Settings bị méo | PARTIAL | Tắt stretch overscroll riêng Settings; đã xem clip cuộn lặp; chưa tái hiện/đối chiếu đúng 13 ảnh lỗi |
| B — Splash | PARTIAL | Sửa H thiếu nét và mask; video đủ từ launch tới Home; latency/wordmark/animation visibility chưa đạt |
| C — Navigation | PASS trong UI idle đã thử | 4 tab, Create, inset, state/reselect host, Light/Dark, 320dp thực; capture-active chỉ regression bằng session giả |
| D — Modal sheets | PASS | Sort/Create thật che navigation, có scrim/handle; root Navigator và handoff regression |
| E — Replay introduction | PASS | 3 trang Light/Dark, Next/Get Started thật; Skip/Back/swipe/persistence trong tests; preferences completion giữ nguyên |
| F — Settings | PASS trong phạm vi đã thử | Nhóm, divider, intro/legal/studio; 320dp chữ 200% thực |
| G — Gallery | PASS với điều kiện build | Debug vẫn có entry; profile không có entry, deep link trả Page unavailable; release APK riêng chưa chạy |
| H — Studio/legal | PASS về thông tin và mở link | About hiển thị MxT APP và version từ package; 3 URL HTTP 200 và Android intents đúng |
| I — Feedback | PASS trong phạm vi đã thử | Gmail ACTION_SENDTO đúng email/subject; fallback lỗi có unit/widget tests; không gửi thư |
| Accessibility/global performance | PARTIAL | Matrix host RTL/locales/text scale; chưa human TalkBack, chưa frame/raster benchmark |

## 2. Baseline và ranh giới

Repo `D:\FAU_App\XRecorder`, branch `main`, HEAD `64e84ec0f952c4e28063488812933010f05bfa7d`; working tree đã dirty/untracked trước task. Không reset/restore/clean/commit/push. Không chỉnh các dirty changes cũ của MainActivity, recording controller/settings hoặc native recording.

Đã đọc local AGENTS/SKILLS, UX Guidelines, debugging/testing playbooks, reports UI/UX 01/02/02B, DocumentApp port và TASK09B handoff. Reference tìm thấy: [UI concept](../../implementation/UI/onboarding.png), [DocumentApp](../../implementation/UI/bottom_navigation.png), [splask.mp4](../../implementation/UI/splask.mp4). Video hiện có dài 4.967 giây; không phải bằng chứng video 11.67 giây mới. **13 screenshots và video 11.67 giây chưa được tìm thấy/cung cấp đường dẫn.** Đã hỏi đường dẫn, chưa có câu trả lời. Không tuyên bố đã xem chúng.

## 3. Root causes và cách sửa

### Slider — đã chứng minh

Flutter `Slider._lerp(1)` tính `(.02 - .002) + .002 = .020000000000000004`. Callback lưu trực tiếp số này, lần build sau vi phạm assertion max .02. Default .006 hợp lệ; không có bằng chứng initial value bằng 0.

Clamp **ngay tại điểm cập nhật state** về [.002, .02]; không catch/suppress assertion. Test trước patch FAIL đúng giá trị trên, sau patch PASS. Trên Android, 5 lượt kéo mỗi phía, đổi Rectangle/Circle/Pen không gây assertion. Lượt kéo xuống đầu tiên chưa tới đúng endpoint được giữ trong JSON cũ; sau đó đã xác minh lại bằng tap endpoint:
- [Min xác minh](slider_minimum_validated.png): 4 pixels/2048px, tương ứng .002.
- [Max](slider_maximum_android.png): 41 pixels/2048px, tương ứng .02.
- [Kết quả gesture/tool](slider_android_results.json), [min xác minh](slider_minimum_validated.txt), [log tiến trình](slider_runtime_log.txt).
- Hai fixture trên thiết bị giữ nguyên SHA256 với bản host; không Save/Export, không sửa ảnh gốc.

### Settings stretch — còn giới hạn

Android có stretch overscroll mặc định. Dùng ScrollConfiguration tắt overscroll indicator riêng Settings, giữ scroll controller/reselect và không thay recording fields. [Clip cuộn](settings_scroll_after.mp4), [các frame](settings_scroll_compact.png). Không thấy layout méo tồn tại sau gesture trong lượt này; một số frame khi đang cuộn mờ/chuyển động. **Không đủ bằng chứng kết luận stretch chính là toàn bộ lỗi người dùng.** Cần bộ ảnh/gesture gốc để phân biệt rendering artifact với persistent layout defect.

### Modal/navigation

Modal cũ dùng Navigator gần nhất trong branch, nên shell navigation còn nằm trên sheet. Đổi helper sang root Navigator, thêm handle và guard presentation theo route: chặn double-open nhưng cho handoff Create → setup sau pop. Giữ callbacks và selection semantics.
- [Sort thật](sort_modal_android.png): scrim phía trên sheet, navigation không nổi lên trên sheet.
- [Create thật](create_modal_runtime.png): sheet che navigation.
- Shell extendBody cho UI idle; thêm bottom scroll clearance cho Media Library/Edit/Settings, outer Row giữ Create bên phải cả RTL.
- **Footer capture:** khi có feedback/session cần hiển thị, giữ vùng footer theo layout cũ để controls không bị bar che. Host regression session paused giả chứng minh Stop ở trên nav; không chạy recording thật.
- Indicator/blur/motion giữ tokens hiện có; không thêm shader/dependency. Không có đo FPS.

### Onboarding và decode

Route /introduction dùng ReplayOnboardingStore chỉ trong RAM: không đọc/ghi first-run channel; không reset completion. System Back ở trang đầu replay có thể thoát, các trang sau quay trang trước. Flow first-run hiện hữu giữ nguyên.

Phát hiện thêm cảnh báo decode ở fixture Reduce Motion: MediaQuery size=0 → cacheWidth=1 → chiều cao ảnh làm tròn 0. Đổi sang width của LayoutBuilder và min decode 3px (max 1200px). Chạy lại 21 test liên quan: PASS, không còn cảnh báo resize đó.

## 4. Splash: đo đạc và phần chưa xong

| Lượt | Android am start -W |
|---|---:|
| APK baseline | timeout, WaitTime 14017ms |
| Debug mới, lượt đầu | TotalTime 13655ms |
| Debug sau sửa native mark | 10585ms |
| Debug lặp | 8405ms |
| Các lượt debug khác | timeout, WaitTime 13837ms / 12459ms |
| Profile cùng source/AVD | TotalTime 4896ms |

Đây là thời gian Android ghi nhận hiển thị activity, **không phải thời gian app usable, không phải benchmark production**. Cache/JIT/tải host không được kiểm soát hoàn toàn; không khẳng định đã tối ưu được latency.

[Video raw đầy đủ](splash_complete.mp4), [bản xem 18 giây](splash_view_18s.mp4), [contact sheet tới Home](splash_complete_contact.png), [giây đầu](splash_first_second.png). Video raw có timestamp/duration không đồng nhất với wall-clock chạy screenrecord; bản 18 giây được encode lại để xem, không dùng chứng nhận FPS.

Native H trước đây có nhiều contour cùng một trimPathEnd; tách thành ba path. Thu mark vào vùng an toàn icon Android để không bị mask cắt. Frame mới thấy đủ 3H. Flutter loading splash tạm theo system brightness để khớp nền native; persisted theme chỉ dùng khi vào app, không bị ghi đè.

**Chưa đạt:** native wordmark ở dưới màn hình, Flutter wordmark sát logo; chưa quan sát rõ toàn bộ nét 3 → H trong video, frame native đầu đã gần hoàn chỉnh. Không giữ app thêm thời gian để ép branding chạy đủ.

Baseline ANR: FocusEvent input dispatch timeout 5004ms, PID 29601. [Last ANR](baseline_lastanr.txt), [screenshot ANR](startup_stalled.png), [DropBox trace](startup_anr_dropbox.txt). LLVM xác nhận Build ID `af989f25713a86e52cca6166586cccde095aff4f` là libflutter.so; symbolizer trả ?? vì binary stripped. Không đủ bằng chứng quy lỗi cho P1 hay Dart feature cụ thể. Profile nhanh hơn debug trong lượt đo, chỉ gợi ý ảnh hưởng build mode/engine/emulator.

Cần tiếp tục startup trace (Perfetto/Flutter timeline, symbols phù hợp); phối hợp P1 nếu phải đặt checkpoint/sửa trong MainActivity/onCreate/configureFlutterEngine. Không sửa protected native startup. Default theme Follow System và native đọc persisted preference vẫn **WAITING FOR P1 APPROVAL**.

## 5. Visual comparison và Settings/studio

So với [reference](../../implementation/UI/onboarding.png), giữ artwork hiện hữu, nền warm-white, Manrope và hierarchy. Khác biệt còn rõ: nút Next đầy chiều ngang thay pill bên phải, khoảng trống/title khác, artwork phone/caption ít chi tiết hơn reference. Không tuyên bố pixel parity.

| Trang | Actual Light | Actual Dark |
|---|---|---|
| Record | [Ảnh](onboarding_light_1.png) | [Ảnh](onboarding_dark_1.png) |
| Edit | [Ảnh](onboarding_light_2.png) | [Ảnh](onboarding_dark_2.png) |
| Subtitles | [Ảnh ổn định](onboarding_light_3_reviewed.png) | [Ảnh](onboarding_dark_3.png) |

[Nav Dark](navigation_dark.png), [Settings/Nav Light](settings_light.png), [320dp chữ 200%](settings_android_320_text200.png). Capsule có clip, pill nằm trong capsule; vùng ngoài thấy nội dung bên dưới. Màu Light accent sẫm theo contrast tokens cũ, khác màu đỏ tươi reference.

Settings giữ nhóm Capture/Appearance/Your workspace/Help & About; thêm divider, supporting text ở Help và studio links, View introduction. Recording rows/destinations giữ nguyên để bàn giao P1.

[About Android](about_studio_android.png) có 3HRecorder, MxT APP, package version/build 0.1.0 (1), website và View licenses. Không hardcode version. [Profile Settings](profile_settings_gallery_hidden.png), [profile deep link bị chặn](profile_gallery_deeplink.png), [labels](profile_gallery_deeplink.json). Source/gallery tests và licenses được giữ.

MxT APP: [website](https://mxtapp.website/), [Privacy](https://mxtapp.website/privacy-policy.html), [Terms](https://mxtapp.website/terms-of-use.html), email maixuantruongcvdev@gmail.com. HTTP kiểm tra thực tế cả ba = 200; website/legal pages chứa email này. [Privacy/Terms intents](official_link_results.json), [website intent](website_intent_activity.txt), [email intent](email_intent_activity.txt) xác nhận Android ACTION_SENDTO với subject [3HRecorder] Feedback. Gmail nhận compose intent; **không gửi email**, không auto-attach media/logs/diagnostics. Copy email fallback luôn có; lỗi thiếu email/browser được localized và kiểm bằng fault injection.

Một bước lưu thêm HTTP JSON bị automatic approval review từ chối do đánh giá nguy cơ overwrite. Không retry hoặc đổi cách ghi cùng artifact đó; kết quả HTTP đến từ lệnh read-only đã thành công trước, không có file JSON HTTP được tạo.

## 6. Privacy/data-handling audit

Chính sách studio là chính sách chung nhiều app và nêu không phải app nào dùng mọi service. Source/dependencies hiện xem không có account, billing, ads, Firebase analytics hoặc cloud-upload implementation cho 3HRecorder; không thêm Delete Account hay acceptance flow.

App có capture màn hình/âm thanh/camera theo quyền P1; recordings, drafts, MediaStore/SAF và ASR xử lý local. Download model là request HTTPS tới Hugging Face; bên tải có thể nhận IP/request metadata. Export/share và feedback chỉ handoff theo hành động người dùng. Browser mở legal links tạo request web thông thường. Diagnostics chỉ thu sau checkbox consent và được hiển thị để review.

Studio cần xác nhận disclosure cụ thể cho MediaProjection, internal/mic audio, facecam, SAF/MediaStore, local ASR/model download, chia sẻ và Data Safety của 3HRecorder. Danh sách dịch vụ/analytics chung trên website không phải bằng chứng app này thu dữ liệu tương ứng. **Link hoạt động không chứng nhận legal compliance.**

## 7. Tests/build và failures đã xử lý

Toolchain: standalone Dart hoạt động. Flutter trong sandbox báo không ghi được khóa SDK; chạy tool với quyền công cụ phù hợp đã giải quyết. Không xóa lock/cache, không kill tiến trình lạ.

[Raw checkpoint log](final_validation_1794308971153.log): analyzer PASS, **120/120** test PASS, git diff --check PASS. Sau đó:
- Decode constraint guard: onboarding + startup/navigation + UI02C, **21/21 PASS**, hết cảnh báo resize.
- Footer guard: UI02C + startup/navigation + UX interaction, **23/23 PASS**, gồm geometry Stop không bị nav che.
- Analyzer cuối: no issues (4.2s); debug APK build PASS (15.0s). Profile diagnostic build PASS (66.4s), 45.9MiB.
- Các nhóm overlap; **không cộng dồn** thành số test độc lập mới hoặc tuyên bố full TASK09B đã chạy.

Lệnh dùng Dart SDK và flutter_tools.snapshot thực thi cùng Flutter tool, ví dụ:
```powershell
& D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe D:\Android\flutter\bin\cache\flutter_tools.snapshot analyze --no-pub
# Test checkpoint: đầy đủ 10 file và exit codes có trong raw log.
# Các lượt sau:
flutter test --no-pub test/onboarding_test.dart test/ui_startup_navigation_test.dart test/ui_ux_02c_test.dart
flutter test --no-pub test/ui_ux_02c_test.dart test/ui_startup_navigation_test.dart test/ux_interaction_test.dart
flutter build apk --debug --no-pub --target-platform android-x64
flutter build apk --profile --no-pub --target-platform android-x64
git diff --check
```

Dart format đã chạy trên các Dart files thay đổi. Failures trung gian đã sửa: API scrollBehavior đặt sai vị trí; import RecordingState thiếu; cast AssetImage cũ không hỗ trợ ResizeImage; Create double-open/handoff; test scroll cần layout pump; fixture current phải trả idle đúng contract. Không skip/xóa assertions; asset paths và guards vẫn được assert. Profile build còn warning CupertinoIcons font không bundled; app dùng Lucide/Material, chưa thấy missing icon tại các màn đã xem. Không thêm package để che warning.

Android thực: AVD tên ThreeHRecorder_TASK09B_API36, serial emulator-5570, user 0; xác nhận cả bằng getprop, không chọn chỉ theo port. Từng install dùng adb install -r, không fallback uninstall. Đã xem 3 onboarding Light/Dark, 4 tabs/Create, Sort layer, Slider endpoints/tools, Settings cuộn, email/legal/about và profile deep link. 320dp/font 2.0 thử thật; restore 411×920/font 1.0 trong finally: [manifest](responsive_android.json).

NOT RUN: physical device/thermal/FPS, human TalkBack, native Dark-system splash, Android RTL và Reduce Motion đầy đủ, native widths 360/393, release APK riêng, capture/MediaProjection/encoder, TASK10. Host có matrix 12 locale, RTL, 320/360/411/840 và navigation 393dp, scales 1.5/2.0.

## 8. Changed-file inventory

Chỉ liệt kê delta của task, các dirty edits cũ vẫn giữ:
- `lib/features/media/photo_tools_screen.dart`: clamp cập nhật stroke.
- `lib/core/ui/components/bottom_sheets/studio_bottom_sheet.dart`: root modal, handle, route-aware guard.
- `lib/core/widgets/studio_shell.dart`: extendBody/inset presentation, Create guard, RTL geometry, bảo vệ capture footer.
- `lib/features/media/media_library_screen.dart`, `lib/features/editor/editing_hub_screen.dart`: scroll clearance dưới nav.
- `lib/features/settings/settings_hub_screen.dart`, `studio_identity.dart`, `support_screen.dart`: IA, studio, links, email/fallback.
- `lib/app/router/app_router.dart`: replay route và debug-only gallery; `lib/app/app.dart`: splash system-theme handoff.
- `lib/features/onboarding/onboarding_screen.dart`, `onboarding_store.dart`: replay/back và decode constraint.
- `android/.../SupportBridge.kt`: package version, HTTPS whitelist, ACTION_SENDTO.
- `android/app/src/main/res/drawable/splash_3h_{light,dark}.xml`, `splash_3h_animated_{light,dark}.xml`: H paths và mask-safe scale.
- 14 ARB files: 8 strings mới, tái dùng localization generator; không đổi schema/settings defaults.
- Tests: `photo_tools_test.dart`, `support_test.dart`, `onboarding_test.dart`, `ui_startup_navigation_test.dart` (format/import fix cũ được giữ), mới `ui_ux_02c_test.dart`.

Không đổi MainActivity, recording_service, RecordingSettingsForm, SettingsController hay native recording/capture files trong task này.

## 9. Preservation, storage và handoff

[Handoff manifest](handoff_manifest.json) chứa APK hashes, source hashes và preference checks:
- MainActivity: 42f33d82…53158; SettingsController: 74e82510…7d570; RecordingSettingsForm: 0df96cc3…94478 — **khớp baseline**.
- Preferences cũ p2_locale/onboarding_state byte-exact sau install/replay; toàn bộ 4 preferences ở lần install cuối được so byte-exact.
- Theme thử bằng UI rồi trả Dark; app_settings được materialize từ defaults qua các thao tác Theme QA, không đổi recording semantics.
- Thêm đúng hai fixture nhỏ trong Download/UI02C_1794308051935, thêm grant SAF của thư mục QA riêng; không revoke grant cũ. Không Save/Export/delete/trash media; fixtures retained, hash khớp host.
- Không thao tác QA5560/5554; không wipe/reboot/create AVD, không xóa evidence/snapshot/models. Không commit/push.

Storage logic (bỏ reparse points, không đo allocated size):
| Mục | Trước | Sau lượt build/profile đo cuối |
|---|---:|---:|
| build/ | 140,713,515,917 B | 140,543,554,251 B |
| build/ delta | | -169,961,666 B (~-170MB) |
| Evidence mới, gồm ELF 40MB phục vụ ANR | 0 | ~46MB, tăng nhẹ theo report cuối |
| Free D: | 31,672,553,472 B | 31,714,684,928 B |

Net build + evidence khoảng -0.124GB; không có cleanup. Build/test thay intermediate bình thường; không quy mọi thay đổi free space cho riêng task vì còn process khác. Thêm profile APK ~48MB đã nằm trong build tổng trên; APK debug 120,021,985 B. Không phát sinh >2GB artifact trong kế hoạch/lượt đo này. File log/ảnh chụp sớm/clip không hoàn chỉnh giữ nguyên và không dùng làm PASS; xem các link được chọn trong report.

### Việc còn lại / owner

| Ưu tiên | Việc | Owner / điều kiện |
|---|---|---|
| HIGH | Startup debug timeout/ANR; phân pha engine/init/first Flutter frame/ready, không chỉ am start | P2/P3 performance phối hợp P1 tại native startup; cần symbols/trace thích hợp, không đủ bằng chứng chỉ đổ lỗi P1 |
| HIGH | Đối chiếu lỗi Settings bị kéo méo gốc | P2 UI; cần đường dẫn 13 ảnh và video 11.67s/gesture sequence |
| MEDIUM | Wordmark handoff, bảo đảm thấy 3→H, native theme theo preference | Shared UI + P1 phê duyệt nếu sửa native initialization; không thêm branding delay |
| MEDIUM | Video quality và Audio/Countdown/Facecam cùng destination; disabled capability chips; recording region; floating ball ngoài app | P1, giữ TASK09B handoff |
| FOLLOW-UP | Filters khó tìm, Media Details crowded, selected-language styling, explanations khi unavailable | P2/global UI |
| FOLLOW-UP | Dense video/audio effects; photo tool/color workflow; slider visual labels; tool-specific controls | P3/editor UX |
| QA | Native RTL/Reduce Motion, TalkBack người thật, physical performance; release smoke | QA riêng, không tự thao tác emulator cá nhân |

**UI/UX 02C: PARTIAL · P1 BOUNDARY: PRESERVED · DATA: PRESERVED trong phạm vi kiểm chứng · TASK10: NOT STARTED.**

[APK debug hiện tại](../../../build/app/outputs/flutter-apk/app-debug.apk) · [APK profile dùng so sánh](../../../build/app/outputs/flutter-apk/app-profile.apk). Profile không thay thế chứng nhận release; debug vẫn có rủi ro startup nêu trên.
