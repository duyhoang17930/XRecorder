# TASK UI/UX 05B — Final acceptance

Ngày 11/11/2026. Nhánh `main`, HEAD `e008fbb095be62db9538f4c598cbff89e6ceb7aa`.
Task tiếp tục trên dirty tree UI05; không commit/push, không bắt đầu TASK10.

## 1. Kết quả

Đã triển khai gộp Recording settings, shared root header, sửa bản dịch theo ngữ cảnh, thêm Back cho player native P2 và chặn chuỗi tap mở Create kích hoạt/dismiss nhầm modal. Đã kiểm tra main app từ **APK cuối**, không dùng integration-only entrypoint thay thế.

| Gate | Trạng thái | Giới hạn |
|---|---|---|
| UI FIXES | **PARTIAL** | Các sửa P2 bên dưới PASS; destination P1 còn hardcoded English. |
| LOCALIZATION | **PARTIAL** | Cấu trúc 14 ARB PASS; cần native-speaker review, chuỗi P1 cần owner. |
| FULL TESTS | **FAIL** | 463 PASS / 4 FAIL, đều trong test Recording Setup P1. |
| PERFORMANCE | **PARTIAL** | Profile trước/sau có số đo; raster vượt budget trên SwiftShader. |
| P1 INTEGRATION | **BLOCKED** | Contract/test P1 và gate recording chưa được xác nhận. |
| USER VISUAL ACCEPTANCE | **PENDING** | Người dùng cần xem APK và xác nhận. |
| TASK10 READINESS | **NOT READY** | Chưa đóng các gate trên. TASK10 NOT STARTED. |

[APK debug](../../../build/app/outputs/flutter-apk/app-debug.apk). SHA-256:
`769077768f79d77d32ece76be460acc61aa5acd15592b1ab58ff06c6189ec566`.
[APK trên AVD khớp chính xác](final_device_preservation.json).

## 2. Năm vấn đề người dùng báo

| Vấn đề | Sửa / bằng chứng | Trạng thái |
|---|---|---|
| Hai entry Capture mở cùng màn hình | Một entry **Recording settings**, subtitle **Video quality, audio & recording options**. Route cũ giữ nguyên. [Trước](before_settings_capture.png) / [Sau](final_settings_capture_light.png). | PASS P2 |
| Destination Recording settings | Giữ toàn bộ form, không sửa defaults/semantics. [Trước](before_recording_destination.png) / [Sau](final_recording_destination_light.png). Vẫn title Audio & Video Settings và labels của P1. | PARTIAL, bàn giao P1 |
| Bốn root header thiếu nhất quán | Dùng StudioRootHeader, cùng typography/coral/48dp title row và inset. [Trước Edit](before_header_edit.png), [trước Settings](before_header_settings.png); sau: [Video](final_header_video_light.png), [Photo](final_header_photo_light.png), [Edit](final_header_edit_light.png), [Settings](final_header_settings_light.png). | PASS trong phạm vi đã test |
| Sort tiếng Việt sai ngữ cảnh | **Sắp xếp**, Mới nhất, Cũ nhất, Tên, Dung lượng lớn nhất, Thời lượng dài nhất. Comparator Largest thực sự theo sizeBytes giảm dần. Không thêm Smallest không có backend. [Trước](before_sort_vietnamese.png) / [Sau](after_sort_vietnamese.png). | PASS |
| Player thiếu Back | Nút native 48×48dp, scrim cục bộ, SafeArea/cutout, label localized, luôn visible. System Back tương đương kể cả khi MediaController có focus. [Trước](before_video_player.png) / [Portrait](final_video_player_portrait.png) / [Landscape](final_video_player_landscape.png). | PASS tested paths |

Header bounding box coral trên bốn screenshot 411×920 đều **[17,73,102,82]**, [pixel check](final_host_storage_preservation.json). Không chèn brand vào nested screens, không đổi route graph hay recreate branch.

## 3. Rapid Create: root cause và patch

Guard cũ chỉ trong child sheet không chặn được tap thứ hai rơi lên **scrim** lúc sheet đang đi vào; Android đã tái hiện sheet bị dismiss. Không biến thất bại đó thành PASS: [lần thử lỗi](after_main_qa_v2.json) được giữ lại.

Patch cuối đặt shield trong **root overlay**, chỉ phủ vùng nút Create ban đầu (+8dp). Dùng quiet window 300ms theo Flutter kDoubleTapTimeout; mỗi pointer-down bị chặn làm mới window. Ngoài vùng này, controls phản hồi ngay. Không debounce toàn app, không đổi P1 Create sheet, không trì hoãn animation/startup, timer được dispose.

- Host: 12 tổ hợp burst 2/3/5 × normal/reduced motion × 411/800dp; gồm tap rơi lên sheet và scrim, child control, dismiss sau quiet window.
- Android: cả 2/3/5 tap giữ **một** Create sheet, không nhảy vào Start Recording.
- Intentional Create → Screen recording vẫn mở Recording Setup; chỉ xem rồi Back, **không Start**.
- [Ảnh 5 tap](final_create_five_taps.png), [events cuối](final_main_qa.json).

## 4. Localization toàn ứng dụng

Đã đối chiếu toàn bộ **707 keys × 14 ARB**, gồm 12 locale shipping và pt/zh parent aliases, key coverage, placeholder/plural structure và chuỗi UI nghi ngờ. [Catalog đầy đủ](localization_review_catalog.json), [matrix](localization_review_matrix.json), [hardcoded review](hardcoded_ui_review.json).

| ARB | Entries đổi, gồm 2 key mới | Heuristic flags cần review |
|---|---:|---:|
| en | 2 | 0 |
| vi | 433 | 10 |
| ar | 19 | 6 |
| de | 19 | 10 |
| es | 18 | 11 |
| fr | 16 | 17 |
| hi | 18 | 8 |
| id | 18 | 15 |
| ja | 17 | 5 |
| ko | 18 | 8 |
| pt | 16 | 12 |
| pt_BR | 16 | 12 |
| zh | 18 | 6 |
| zh_Hans | 18 | 6 |

Tiếng Việt sửa thuật ngữ sai như Save → Lưu, Arrow → Mũi tên, Rectangle → Hình chữ nhật, Volume → Âm lượng; rà editor/effects/ASR/draft/errors/help, không chỉ Sort. Các locale khác sửa các lỗi literal rõ ràng và hai key Recording settings. Không ép Title Case tiếng Anh lên mọi ngôn ngữ.

Giữ key cũ và placeholder; thêm duy nhất recordingSettings/recordingSettingsSummary. Native Back lấy từ key onboardingBack qua tool sync hiện có. pt và pt_BR được phép **5 khác biệt regional cụ thể** đã được viết trong test; các key còn lại vẫn so equality. zh parent/Hans giữ parity.

Flags chỉ là shortlist heuristic; **không có flag không đồng nghĩa dịch chuẩn**. Chưa có native-speaker acceptance cho toàn bộ ngôn ngữ. Những chuỗi recording hardcoded thuộc P1 vẫn thấy trong ảnh tiếng Việt; không sửa chéo ownership.

## 5. File changes và phạm vi

[Manifest 473 file tại baseline](baseline.json) / [đối chiếu cuối](final_host_storage_preservation.json) liệt kê chính xác thay đổi. Nhóm file UI05B:

- Shared UI: lib/core/ui/components/cards/studio_cards.dart (StudioRootHeader, SectionTitle.minimumHeight), lib/core/widgets/studio_shell.dart; thêm lib/core/ui/components/bottom_sheets/studio_sheet_launch.dart.
- Consumers: lib/features/media/media_library_screen.dart, lib/features/editor/editing_hub_screen.dart, lib/features/settings/settings_hub_screen.dart. Editing hub chỉ đổi header.
- 14 lib/l10n/app_*.arb; tool/sync_p2_native_l10n.py; 12 locale resource p2_strings.xml.
- Player P2: android/app/src/main/kotlin/com/xrecorder/xrecorder/media/VideoPreviewActivity.kt; thêm drawable/p2_chevron_back.xml và values/p2_ids.xml.
- Host tests: design_system_test.dart, task09b_shared_interactions_test.dart, localization_test.dart, widget_test.dart; thêm ui_ux_05b_acceptance_test.dart.
- Native tests: thêm Ui05BPlayerInstrumentation.java; runner Task07AccessibilityInstrumentation.java thêm **opt-in** ui05b=player, giữ các nhánh cũ.
- Evidence/scripts mới chỉ ở thư mục báo cáo versioned này và build/verification/uiux05b.

Các sửa UI05 có sẵn tại dialog/feedback/theme/motion/trash/details/ux_interaction_test không phải patch mới UI05B. Giữ nguyên chúng. Không thêm dependency. AndroidTest Manifest không có final content diff.

## 6. Test commands và kết quả

Flutter wrapper chạy Dart SDK + flutter_tools.snapshot của máy; tương đương CLI sau:

| Command | Kết quả / log |
|---|---|
| dart format --output=none --set-exit-if-changed [11 Dart files liên quan] | PASS, 0 changed. [Log](format_final_163435_635f40.txt). |
| flutter gen-l10n | PASS. [Log](gen_l10n_final_115526_9fed94fb.txt). |
| flutter analyze --no-pub | PASS, No issues, 4.3s. [Log](analyzer_final_overlay_161720_a7aca3bb.txt). |
| flutter test --no-pub | **463 PASS / 4 FAIL**, 158s. [Log cuối](full_host_final_161726_24f0a8b3.txt). |
| flutter build apk --debug --no-pub --target-platform android-x64 | PASS, 50.6s. [Log](debug_final_build_162012_cb500c95.txt). |
| flutter build apk --profile --no-pub --target-platform android-x64 | PASS, 53.9s, final production guard. [Log](profile_final_build_122908_7111e9b7.txt). |
| Gradle :app:assembleDebugAndroidTest --offline --max-workers=2, target main/x64 | PASS. [Log](native_test_build_121324_0c0b01.txt). |
| am instrument -w -e ui05b player -e uri content://media/external/video/media/1536 -e sha256 [fixture SHA] com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation | **4/4 PASS**: visible Back, system Back, landscape Back, reopen Back; player disposed, source hash exact. [Log cuối](native_player_result_final.txt). |
| python audit_localization.py | Structural errors: 0; linguistic review PARTIAL. [Matrix](localization_review_matrix.json). |
| git diff --check | PASS; chỉ cảnh báo CRLF informational, không whitespace error. |

42 test mới nằm trong full suite: 24 header configurations (mỗi case kiểm 3 locale × portrait/landscape = 144 layout samples), 12 Create cases, 4 long/RTL photo Sort cases, 1 Vietnamese Sort, 1 Settings route/persistence. Không gọi 144 samples là 144 tests.

Ba lỗi P2 từ UI05 được giải quyết:
- design_system_test: entry Privacy cũ đã chuyển official legal link và help disclosure; test kiểm chính hành vi mới, vẫn assert nội dung “What leaves my device?”.
- shared_interactions: kiểm View introduction, Privacy Policy/Terms URL và không ghi settings.
- localization: pt/pt_BR regional expectations theo bản dịch đã có, không xóa parity check.

Bốn FAIL P1 giữ nguyên: stale resolution expectation và ba locator handle 36×4 không còn match theme 40×3. Chưa chứng minh pinning layout hỏng vì test dừng ở finder. [Bàn giao chi tiết](P1_UI05B_HANDOFF.md).

Các log đỏ trước đó vẫn giữ: lỗi harness locator/route/dispose/fixture và lỗi thật Create scrim đã dẫn tới patch. Không xóa/skip expectation để xanh.

## 7. Android acceptance và orientation

AVD được xác nhận theo tên, không chọn chỉ theo port: ThreeHRecorder_TASK09B_API36 / emulator-5570. Chỉ boot lại **AVD này** sau checkpoint nghỉ; không tạo AVD/snapshot, không chạm 5554/QA5560. Cài replace bằng tool backup trước install; không uninstall/clear.

| Flow | Kiểm tra thực tế | Trạng thái |
|---|---|---|
| 4 root tabs, Back, Settings destination | Switch, state, entry → existing form → Back, header images | PASS tested |
| Reselect / scroll | Script profile và main app root reselection; không đổi controller/branch | PASS tested; không thay full state-restoration audit |
| 4 root tabs P→L→P | 411dp Light, marker/state tồn tại sau mỗi lần xoay | PASS tested |
| Player P→L→P | Visible Back, play/pause, system Back, end/reopen, native disposal | PASS tested |
| Arabic Settings + Sort | 320×760, text 200%, fast scroll, rotation | PARTIAL: không thấy overflow/red screen; landscape 320px cao còn rất ít vùng đọc |
| English Settings | 360×800, text 150%, rotation | PASS tested |
| Navigation Dark | 393×850, text 100%, selection/contrast | PASS observed; ảnh giữ scroll state nên title ở mép trên |
| Reduced Motion | Android animation scales 0, Create open/Back; host duration/guard cases | PASS tested |
| Keyboard | Language picker search, keyboard visible, Back rồi close dialog | PASS tested |
| Background/foreground | App Home → resume main task, state/root còn | PASS tested |
| Settings stretch | 10 fast flings, thêm Arabic 200% scroll và rotation | **NOT REPRODUCED**, không tuyên bố FIXED |
| Hardware GPU / physical-device playback/perf | Không có device được cấp phép phù hợp | NOT RUN |
| Human TalkBack | Không có kiểm thử bằng người | NOT RUN |

[Main events](final_main_qa.json), [locale/rotation events](localized_visual_qa.json).
[Small RTL landscape](after_settings_arabic_320_text200_landscape.png), [RTL Sort](after_sort_arabic_320_text200.png), [360dp text150](after_settings_360_text150.png), [Dark](after_navigation_dark_393.png), [keyboard](after_language_keyboard.png), [Reduce Motion](after_create_reduced_motion.png).

320/360/393/411dp × text100/150/200 × Light/Dark và fr/de/ar/ja long Sort được bổ sung host coverage; **không nói mọi tổ hợp này đều được chạy Android**.

## 8. Accessibility

Full host suite có Android tap-target, labeled target, text contrast, high contrast/no blur, nav selection clipping và Reduce Motion tests từ UI05, đều PASS. Nút Back native đo 48dp bằng instrumentation. Shared headers không animate lại khi rebuild.

Các tiêu chí cần người dùng/TalkBack, readability khi media đang chuyển động, native-language review và landscape cực thấp vẫn PARTIAL. Không dùng semantics test thay human acceptance.

## 9. Performance trước/sau

So sánh **baseline UI05** với **final UI05B profile**, cùng AVD SwiftShader, Light/English, 411×920/160dpi và script thao tác. Warm cả 4 tab trước đo. Chỉ một pass mỗi phase, không có hardware-GPU run.

| Scenario | UI p90 ms trước→sau | Raster p90 ms trước→sau | Samples trước→sau |
|---|---:|---:|---:|
| Tabs | 10.613→10.990 | 57.596→46.176 | 135→138 |
| Create sheets | 12.223→11.192 | 50.306→49.471 | 87→84 |
| Settings scroll | 4.152→5.178 | 46.097→43.556 | 94→85 |
| Reselect | 6.591→4.698 | 54.669→42.339 | 17→18 |
| Color picker | 5.993→6.872 | 34.107→34.431 | 126→125 |
| Drawing/Undo | 4.285→4.965 | 33.896→34.549 | 147→145 |
| Photo rotation | 18.742→48.826 | 88.502→40.002 | 6→6 |
| Paused video scrub | 3.996→3.716 | 14.443→33.334 | 65→58 |
| Video rotation | 23.948→24.175 | 100.120→37.775 | 6→6 |

[Core baseline](baseline_profile_summary.json) / [final](final_profile_summary.json);
[editor baseline](baseline_editor_profile_summary.json) / [final](final_editor_profile_summary.json);
[video baseline](baseline_video_profile_summary.json) / [final](final_video_profile_summary.json).
Raw timelines cùng prefix được giữ để tái phân tích. Phase after là intermediate guard, không dùng thay final.

Raster final vượt 16.67ms ở 138/138 tab frames, 84/84 Create frames, 85/85 Settings frames. Đây là **timing over-budget samples**, không phải phép đo chính xác số frame trình bày bị drop. Video scrub p90 tăng và photo-rotation UI tail tăng; mẫu rotation chỉ 6, chưa tách được variance/backend/AVD. **Không đủ bằng chứng certify no-regression hoặc 60 FPS.** Không sửa Media3 cache/EditorPreview để làm đẹp điểm.

Memory PSS baseline: 143538→159218KB; final: 141995→163856KB, trước/sau cùng chuỗi 7 scenarios core/photo. Delta final +21861KB, baseline +15680KB. Đây là hai snapshots có warm-up/cache, chưa chứng minh leak hoặc bounded memory. [Final before](final_mem_before.txt) / [after](final_mem_after.txt).

## 10. Startup

Không thêm splash, waiting timer hay sửa startup. Không so debug UI04 15–16s trực tiếp với profile lần này.

| Boundary | Baseline profile | Final profile |
|---|---:|---:|
| am start -W TotalTime / WaitTime | 2674 / 2677ms | 2629 / 2656ms |
| Flutter engine entry → first completed GPU draw | 1156.127ms | 1151.593ms |
| Engine entry → first UI Frame end | 1067.448ms | 358.440ms |
| First successful hierarchy observation | 6.078s | 6.328s |

[Startup metrics và phương pháp](startup_metrics.json), [baseline launch](baseline_launch.txt), [final launch](final_launch.txt).
Engine/draw boundary không phải physical first-presentation; hierarchy polling gồm ADB overhead và không phải exact time-to-usable. Intermediate phase còn chậm 8.796s observation. **Startup acceptance PARTIAL**, không tuyên bố patch cải thiện startup hay tất cả máy khởi động dưới 1s.

## 11. Evidence mới, đúng APK

- [Video main interactions cuối — 153s / 3.86MB](UI05B_main_interactions_final.mp4): 4 tabs, Settings/destination/Back, rapid Create, child handoff, player play/pause/Back/rotation, scroll/resume.
- [Video Sort tiếng Việt — 76.7s / 1.44MB](UI05B_localized_sort_final.mp4), [frame Sort](review_localized_15s.png).
- [Main sampled frames](review_main_10s.png), [Create](review_main_60s.png), [player](review_main_110s.png), [Settings](review_main_145s.png).

Đã xem screenshots và sample frames của hai video. Android screenrecord là công cụ evidence, **không chạy recording/capture của app**. Video có ADB/locator pauses; stream có thể giữ canvas portrait khi xoay, nên dùng screenshot landscape riêng để đánh giá geometry. Video không chứng minh FPS.

Các ảnh before chụp từ baseline trước patch; chỉ các ảnh final_* và localized QA nêu trên dùng làm acceptance patch cuối. File final_navigation_dark.png trong benchmark thực tế là **Light**, tên kế thừa harness; ảnh Dark đúng là after_navigation_dark_393.png.

## 12. Bảo toàn dữ liệu và ownership

[Final device check](final_device_preservation.json):

- 7/7 hash private giữ nguyên: p2_locale, onboarding_state, app_settings, media_catalog, 2 projects, export_jobs.
- 4/4 media fixture giữ nguyên bytes, gồm 2 input UI02C, PNG editor và video retained QA.
- UID app 10219/test 10218 không đổi; host/device APK SHA khớp.
- Settings trở về **explicit Light + English**, đúng UI05B baseline; recording values không đổi.
- Display trở về 411×920/160dpi, text1.0, portrait0/auto1, transition1.0 và animator null như trước test.
- SAF grants không được thay; không reauthorize, không mở Trash auto-purge, không Save/Export output từ QA editing.

[Host check](final_host_storage_preservation.json): không thiếu file nào trong manifest 473 file; 32 protected source hashes unchanged, gồm MainActivity, recording, SettingsController/form/screen và **EditorPreview.kt rotation fix**. studio_create_sheet.dart cũng unchanged. Dirty UI05 work và untracked fonts/tests/reports vẫn còn.

Backup tool giữ 5 bản private-data backup trước install (~455.67MB tổng), logs host/device backup hash. [Install evidence](../../../build/verification/uiux05b). Không claim đã hash toàn bộ user media/private tree; kết luận bảo toàn byte áp dụng cho tập dữ liệu đã kiểm tra. Không delete/reset/restore/clean/commit/push.

## 13. Storage

[Baseline](storage_before.json): build **142649866989 bytes** / 20344 files.
[Snapshot cuối](final_host_storage_preservation.json): build **143312453184 bytes** / 20456 files, tăng **662586195 bytes ≈0.663GB**. Logical size; allocated/sparse size chưa đo.

Evidence tại snapshot ~49.54MB; video locale và báo cáo bổ sung sau snapshot khoảng 1.5–2MB. Tổng tăng build + evidence khoảng **0.72GB**, dưới 2GB. Build growth gồm backup ~455.67MB, APK/intermediates/native test outputs; không tạo model/fixture/AVD disk mới. D: free 29.150GB→28.429GB tại snapshot, không quy toàn bộ free-space delta cho task.

Không xóa evidence hay cleanup để giảm con số. Một số command/harness thất bại vẫn giữ để trace.

## 14. Vấn đề còn lại và owner

| Việc còn lại | Owner / đầu vào cần |
|---|---|
| 4 test P1, normalize selection contract và pinned locator | P1; [handoff](P1_UI05B_HANDOFF.md) |
| Recording Settings/card hardcoded English, first-install theme default còn chờ | P1 approval; không sửa schema/default chéo |
| Full linguistic acceptance 12 locales + regional variants | Native speakers/studio; catalog và flags đã xuất |
| Raster chậm SwiftShader, scrub tail/rotation, memory dài hạn | P2/P3 performance review trên hardware GPU được cấp phép |
| 320px-high landscape + text200% ít không gian đọc | UI follow-up; scroll vẫn cần human usability review |
| TalkBack và physical device | Human QA, chưa có phép thay bằng host tests |
| User visual acceptance | Người dùng xem APK/screenshots/videos |

## 15. Verdict

Các lỗi P2 đã sửa và kiểm thử lại trong phạm vi nêu trên; không có exception mới khớp Flutter/FATAL/RenderFlex trong logcat process cuối được thu. Điều đó không chứng minh toàn app không có crash.

UI05B giữ **PARTIAL**, full tests **FAIL do 4 case P1**, performance/localization **PARTIAL**, user acceptance **PENDING**.
TASK10 **NOT STARTED / NOT READY**; cần đóng gate P1 và các acceptance còn thiếu trước khi xem xét.
