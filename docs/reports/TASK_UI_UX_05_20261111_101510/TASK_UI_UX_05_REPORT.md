# TASK UI/UX 05 — Motion & Interaction Audit

11/11/2026 • main • HEAD e008fbb095be62db9538f4c598cbff89e6ceb7aa. Working tree sạch ở baseline.

**UI05: PARTIAL. Performance: PARTIAL. Full suite: 418 PASS / 7 FAIL. TASK10: NOT STARTED.**

## 1. Executive summary

Đã sửa lifecycle animation/dialog, lỗi Rename/IME, Reduce Motion của snackbar, contrast/blur của bottom navigation. Đo trước/sau bằng main app profile APK trên cùng AVD/script; tiếp tục kiểm tra debug APK và ảnh Android thật. Không dùng test-only entrypoint thay main app.

Không sửa P1/native/editor algorithms, không capture, export mới, clear data, clean, xóa evidence, commit/push. 473 file baseline được đối chiếu: 0 mất; Android/native và EditorPreview.kt exact. 7 private files + 2 fixture PNG giữ SHA-256 exact, UID/display/preferences khôi phục đúng.

## 2. Official guideline → implementation → verified result

Đọc trực tiếp nguồn chính thức; đây là đối chiếu thiết kế, không phải chứng nhận Apple compliance.

| Guideline | Current implementation | Evidence | Gap | Proposed change / thực hiện | Verified result |
|---|---|---|---|---|---|
| [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion): chuyển động có mục đích, giảm được | Route fade, nav pill, onboarding | motion red/green logs; runtime JSON | CurvedAnimation tạo listeners trong mỗi build; notice chưa nhận Reduce Motion | CurveTween; motion-aware snackbar | PASS lifecycle/notice host; runtime Reduce Motion xác nhận |
| [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials): phân tầng và legibility | Capsule blur10 alpha .74/.76 | Ảnh before/after; contrast tests | Chữ nhỏ contrast yếu; thiếu high contrast fallback | Blur6 bounded; alpha .90/.92, semantic text; high contrast opaque/filter off | PASS guideline/ảnh; performance PARTIAL |
| [Apple Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures): thao tác quen thuộc, dễ tiếp cận | Tap/reselect/swipe, visible controls, native Back | main_visual_qa_v2.json; duplicate/child tests | Branch current phía dưới root dialog cho phép yêu cầu trùng | Lock đồng bộ theo origin, vẫn cho child dialog | PASS host duplicate/child; Android flow/state |
| [Apple Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback): phản hồi phù hợp ngữ cảnh | Busy, notices, confirmations, Undo | Rename red/green; debug IME screenshots/log | Rename dispose controller trước route reverse/IME teardown | Controller thuộc dialog State; thống nhất confirmation | PASS Save/Cancel host, Cancel+IME Android ×2 |
| [Apple Design Principles](https://developer.apple.com/design/human-interface-guidelines/design-principles): clarity, control, recovery | Apply/Cancel, discard, stateful tabs | Editor video/events; preservation hashes | Cần bảo vệ state khi đổi presentation | Giữ backend, commands và safeguards | PASS các flow đã chạy; destructive native NOT RUN |
| [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility): nhãn, contrast, chữ lớn, Android targets | Semantics/tooltip | Guideline tests; RTL Android PNG | Nav không chỉ rõ Manrope; font giả không kiểm được Arabic glyph | Family/weight rõ; Arabic test-only fixture | PASS nav targets/contrast; Arabic Android đã xem, human acceptance NOT RUN |
| [Flutter Accessibility Testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing) | Có layout tests | ui_ux_05_motion_test.dart; native screenshots | Widget tests không thay device/TalkBack | 3 guideline APIs + Android QA | 6 tổ hợp Light/Dark ×100/150/200% PASS; TalkBack người thật NOT RUN |

120/180/260/280ms là **quyết định 3HRecorder**, không phải duration Apple quy định. Không port Apple renderer hay ép physics iOS. Giữ Android Back, Material scroll, IME, gesture SafeArea, 48dp targets và permission/consent hệ thống.

## 3. Motion UI01–04 được giữ

- UI03 đã bỏ branded Flutter splash; không đưa lại hoặc thêm startup delay.
- Onboarding: controller có dispose/Reduce Motion, swipe, visible Next/Skip/Get Started, replay và persistence giữ nguyên.
- Navigation: bốn StatefulShellBranch, indicator260ms; icon/label180ms; Create riêng.
- Sheets280/180ms, dialogs180/120ms; chips120/180ms; route fade theo token.
- Editor drawing/slider/scrub không thêm animation, blur hoặc observer trên hot path.
- Undo/Redo, Apply/Cancel, autosave/discard, feedback/progress/cancel giữ contracts.

## 4. Sửa và changed files

| File | Nguyên nhân / thay đổi |
|---|---|
| lib/core/ui/theme/app_theme.dart | CurvedAnimation mỗi build giữ status listeners; thay animation.drive(CurveTween), giữ fade/curve |
| lib/core/ui/theme/motion.dart | Token navigationIndicator260ms |
| lib/core/widgets/studio_shell.dart | Cache filter sigma6; semantic label contrast/Manrope700; high contrast tắt blur; giữ routes/bounds/reselect |
| lib/core/ui/components/dialogs/studio_dialog.dart | Guard theo origin route khóa trước await; root navigator; nhả finally; child dialog hợp lệ |
| lib/core/ui/components/feedback/studio_feedback.dart | Snackbar entrance/reverse nhận context.motion, giữ duration đọc/Help |
| lib/features/media/video_details_screen.dart | Rename controller thuộc Stateful dialog; không dispose khi pop Future vừa trả; không animate busy phía sau modal |
| lib/features/media/trash_screen.dart | Reuse StudioDialog, giữ permanent-delete confirmation/backend |
| lib/features/editor/editing_hub_screen.dart | Reuse delete-draft confirmation, không đổi mutation |
| test/ux_interaction_test.dart | Rename Cancel/Save + keyboard/reverse regression |
| test/ui_ux_05_motion_test.dart | 12 lifecycle/modal/feedback/contrast/accessibility cases |
| test/fixtures/fonts/* | Test-only Arabic font, OFL licence/provenance |

Đã review diff cuối: không đổi callable backend, schemas, locale keys, setting defaults, navigation graph, capture hoặc export. [Source hash audit](source_preservation_final.json).

Font NotoNaskhArabic: 307592B, [Google Fonts](https://github.com/google/fonts/tree/main/ofl/notonaskharabic), SIL OFL1.1 (4382B licence), SHA/provenance trong [README](../../../test/fixtures/fonts/README.md). Không thêm package/font/asset runtime vào pubspec. Fixture giúp host contrast dùng glyph Arabic thật; không mô phỏng hoàn toàn Android fallback.

## 5. Performance baseline / after

Cùng **ThreeHRecorder_TASK09B_API36, emulator-5570, profile main APK, SwiftShader, 411×920 @160dpi**, script cố định, không chạy host suite cùng lúc đo.

[Script](profile_scenarios.py), [video scenarios](profile_video.py), [baseline](baseline_profile_summary_corrected.json), [after](after_profile_summary.json), [baseline video](baseline_video_profile_summary.json), [after video](after_video_profile_summary.json). Raw timeline từng scenario nằm cạnh summary.

| Scenario | Samples before→after | UI/build p90 ms | Raster p90 ms | UI >16.67ms count | Raster >16.67ms count |
|---|---:|---:|---:|---:|---:|
| Tabs ×12 | 130→133 | 12.739→12.187 | 46.078→47.446 | 8→4 | 130→133 |
| Create ×5 | 78→84 | 7.314→9.471 | 53.988→52.587 | 3→2 | 78→84 |
| Settings scroll | 87→84 | 2.652→2.671 | 49.292→45.989 | 0→0 | 87→84 |
| Reselect | 16→18 | 3.607→4.647 | 46.975→44.620 | 0→0 | 16→18 |
| Picker ×5 | 131→121 | 4.650→4.984 | 31.564→33.433 | 1→0 | 124→112 |
| Drawing/Undo ×5 | 155→149 | 4.224→4.203 | 32.831→32.731 | 0→0 | 142→139 |
| Photo rotation | 6→7 | 17.347→29.563 | 55.930→41.564 | 1→2 | 4→5 |
| Video scrub | 65→63 | 4.007→5.395 | 40.128→29.136 | 2→4 | 10→8 |
| Video rotation | 6→6 | 23.554→23.764 | 79.103→35.503 | 2→1 | 6→5 |

UI lấy async Frame spans; raster lấy GPURasterizer::Draw. Counts là budget overruns, không phải dropped presentation frames/FPS chính xác. Parser baseline ban đầu bỏ sót async b/e, đã tính lại từ raw timeline cũ, giữ summary sai; không đo lại để chọn số đẹp.

**PARTIAL:** giảm blur không giải quyết raster bottleneck SwiftShader. Có scenario tăng/giảm, rotation quá ít mẫu; không chứng minh no-regression có ý nghĩa thống kê hay 60/120FPS. Không sửa Media3/cache/native để cải thiện điểm.

PSS chuỗi lặp: baseline143178→155993 KiB; after141244→160928 KiB ([before](after_mem_before.txt), [after](after_mem_after.txt)). Một phiên có warming/cache, không kết luận leak hoặc không leak.

Startup: profile after COLD TotalTime3102ms/Wait3107 ([log](after_profile_launch.txt)); debug5665/5673ms ([log](debug_launch.txt)). Baseline profile2190/2214 chỉ quan sát console, không lưu raw riêng: không dùng làm chứng cứ tối ưu. Android activity timing không phải full time-to-usable. Debug còn skipped90/39 frames khởi động; không tuyên bố giải quyết startup15–16s của UI04.

## 6. Android coverage và orientation

Xác minh AVD identity, reuse AVD; không tạo/wipe hoặc snapshot duplicate. Safe installer backup SHA trước install-r, không fallback uninstall:

[Baseline manifest](../../../build/verification/uiux05/baseline_install_20261111_1026_v2/backup_private_manifest_v1.json) • [After](../../../build/verification/uiux05/after_install_20261111_1044/backup_private_manifest_v1.json) • [Debug](../../../build/verification/uiux05/debug_install_20261111_1107/backup_private_manifest_v1.json).

Profile after SHA256 b6c730ce976aa89ff50e23a2e6cb8e1ebb0c6b035a963de91f9e75bb189240d2. Debug main APK cùng source cuối được cài và giữ lại.

| Flow | Thao tác / evidence | Status |
|---|---|---|
| Four tabs | Switch/fast taps, Settings scroll retained, reselect về Video quality | PASS scoped |
| Create/modal | Open/Back, một sheet, scrim che nav | PASS normal; rapid same-coordinate handoff PARTIAL |
| Search/Sort | QueryUI04, IME open/close/clear; selectedNewest, sheet/Back | PASS |
| Settings stretch | 10 fast flings, rotation | NOT REPRODUCED, không tuyên bố lỗi lịch sử đã hết |
| Onboarding replay | 3 trang Light/Dark, Next/GetStarted, landscape trang3 | PASS, completion hash exact |
| Photo Editor | Cyan/draw/Undo/Redo/Rectangle/AllTools/KeepEditing, Undo rồi Back | PASS, không Save copy |
| Video Editor | QA clone, scrub, paused frame P→L→P | PASS, native preview giữ nguyên |
| Rename debug | IME + nhập chuỗi thử + Cancel ×2 | PASS, tên gốc giữ; Save host mock |
| Reduce Motion | Correct transition setting, tabs/Create/dialog + VM read | PASS scoped |
| Background/foreground | Home→resume | PASS |
| Trash/Restore, Move/Delete, export thực | Không chạy trên data cũ (Trash mở có auto-purge expired) | Native NOT RUN; host chạy |
| SAF failures, share/export cancellation/status | Source/host audit, không native fault injection | PARTIAL |
| Human TalkBack | Không có phiên người thật | NOT RUN |

Rotation thật P→L→P: Videos, Photos, Edit hub, Settings, Photo Editor, Video Editor. Onboarding trang3 có landscape/return. Chưa rotate mọi dialog/sheet, chưa native lại360/393dp; host layout coverage không thay device QA.

[Main events](main_visual_qa_v2.json) • [Global events](global_visual_qa.json) • [Video events](after_video_profile_actions.json) • [Rename](rename_android_qa.json).

Attempts giữ lại: rapid Create3taps cùng tọa độ mở Recording settings, không Start/đổi controls; tap tiếp có thể chọn item vừa hiện, chưa đủ gọi duplicate command. Một RTL script bấm Back thừa đưa app ra launcher: ảnh after_arabic_320_text200 **không tính PASS**; v2 chụp app thật. Restore “English” ban đầu trùng text Search, v3 chọn đúng Button. Không sửa product/assertion để qua locator.

## 7. Accessibility và Reduced Motion

Host: androidTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline; Light/Dark ×1/1.5/2 tại320dp, Arabic ở2×, backdrop trắng/đen, high contrast filter off, rapid pill bounds; không hạ contrast4.5.

Android targets tại411dp: tabs83/83/82/83×56dp, Create52×52dp. Đã xem Arabic320dp/200% portrait/landscape. Nhãn Settings Arabic sát mép, còn tooltip/semantics đầy đủ; cần human readability review. Không gọi mọi screen đạt accessibility chỉ từ nav test.

Flutter Android dùng **transition_animation_scale**, không chỉ animator_duration_scale ([engine](https://chromium.googlesource.com/external/github.com/flutter/flutter/%2B/c12a552532baedf53d9cbd267816e9b01ffd7ae9/engine/src/flutter/shell/platform/android/io/flutter/view/AccessibilityBridge.java)). Phần animator-only trong clip đầu không tính là xác nhận Reduce Motion. Debug clip sau dùng cả hai=0; VM object read xác nhận flags132/disableAnimations=true ở0 và128/false ở1, restore transition1.0/animatornull ([JSON](runtime_reduce_motion_fields_v2.json)). Evaluate attempt thiếu compilation service; fallback getObject chỉ đọc thành công, không sửa app. JSON rỗng attempt đầu không phải PASS.

## 8. Before/after visuals và video

| Screen | Before baseline main/profile mới | After main/profile mới | Quan sát |
|---|---|---|---|
| Dark navigation | [Before](baseline_navigation_dark.png) | [After](after_navigation_dark.png) | Chữ rõ hơn, pill trong capsule, không opaque strip ngoài capsule |
| Light navigation | [Before](baseline_navigation_light.png) | [After](after_navigation_light.png) | Semantic foreground, Coral icon/Create giữ nhận diện |
| Photo | [Before](baseline_photo.png) | [Tool selected](after_selected_rectangle_v2.png) | Tools không redesign; context/state giữ |
| Paused video sau xoay | [Before](baseline_paused_video_after_rotation.png) | [After](after_paused_video_after_rotation.png) | Frame được khôi phục |

[Create](after_create_modal_v2.png), [Sort](after_sort_modal_light.png), [IME](after_search_keyboard_light.png), [Picker](after_color_picker_visual_v2.png), [Photo landscape](after_photo_landscape_visual_v2.png), [Rename debug](after_rename_keyboard_debug.png), [Cancel](after_rename_cancel_debug.png).

Onboarding [L1](after_onboarding_light_1.png)/[L2](after_onboarding_light_2.png)/[L3](after_onboarding_light_3.png), [D1](after_onboarding_dark_1.png)/[D2](after_onboarding_dark_2.png)/[D3](after_onboarding_dark_3.png), [landscape](after_onboarding_landscape_light.png).
Arabic app thật [portrait](after_arabic_app_320_text200_v2.png)/[landscape](after_arabic_app_320_text200_landscape_v2.png).

[Main interaction video](UI05_motion_interactions_v2.mp4):68.69s/2.89MB, tabs/scroll/Create/picker/tools/rotation/guard. Đã xem frames5/22/40/48/58s; không tuyên bố review liên tục mọi frame hay FPS/human acceptance.
[Reduced Motion debug video](UI05_reduced_motion_debug.mp4):272KB, target16s; xác nhận runtime riêng bằng JSON.

Ảnh/video mới đúng APK UI05; không dùng ảnh APK cũ làm after. Visual acceptance toàn app vẫn PARTIAL.

## 9. Test logs và failures

Runner ghi argv đầy đủ/UTF8/exit, Flutter CLI tuần tự.

| Command/scope | Result / log |
|---|---|
| dart format 10 scoped Dart files ở inventory | PASS,0changed — [log](format_final.txt) |
| flutter analyze --no-pub | PASS,No issues,3s — [log](analyze_clean_104103_a883c8f8.txt) |
| flutter test --no-pub test/ui_ux_05_motion_test.dart test/ux_interaction_test.dart (5 motion cases đầu) |18PASS — [log](motion_green_103148_deb61f2f.txt) |
| flutter test --no-pub test/ui_ux_05_motion_test.dart (bản cuối) |12PASS — [log](a11y_label_weight_103936_6c1ac3b0.txt) |
| flutter test --no-pub --concurrency=2 |418PASS/7FAIL,exit1,122s — [log](full_host_104955_d19c7ab5.txt) |
| flutter build apk --profile --no-pub --target-platform android-x64 |baselinePASS120.9s/[log](baseline_profile_101613_48690d59.txt), afterPASS58s/[log](after_profile_104107_82ad82bc.txt) |
| flutter build apk --debug --no-pub --target-platform android-x64 |PASS17.1s — [log](debug_build_105555_2ce55d62.txt) |
| git diff --check |PASS, chỉ cảnh báo LF/CRLF |

Red before fix: [motion](motion_red_102735_4b221f5e.txt), [Rename](rename_red_controller_103027_1b232836.txt). Không xóa/bỏ/giảm expectations.

7 FAIL:
- design_system_test concise settings và task09b_shared_interactions_test Settings rows: tìm “Privacy” cũ đã thay bằng Privacy Policy/external link trong HEAD.
- localization_test: yêu cầu pt/pt_BR giống hệt;5 chuỗi onboarding khác vùng. Không thay bản dịch hợp lệ chỉ để lấy xanh.
- recording_setup_sheet_test: stale selection expected1080pFHD/actual720pHD, cùng3 pinned-controls cases320/360/411dp: P1 review.

[HEAD provenance](full_suite_preexisting_failures_provenance.json): tests/Settings/ARB liên quan không đổi sau normalize EOL. Ba contract/test drifts cần P2 maintenance riêng; bốn recording failures bàn giao P1, không thay behavior/assertions. Không tuyên bố full regression PASS.

[Debug log](debug_runtime_logcat.txt)/[Rename log](debug_rename_runtime_logcat.txt): không E/flutter/FATAL/RenderFlex/disposed-controller/failed-assertion trong flow ghi log; còn startup skipped-frame warnings. Không suy rộng ra toàn app.

## 10. Data/ownership/storage

[Device preservation](device_preservation_final.json):9/9 SHA exact; appUID10219; display411×920/density160/font1/autoRotate1/rotation0, animatornull đúng baseline; themeDark và FollowSystem khôi phục. Onboarding completed/page, projects, export_jobs exact. [Source](source_preservation_final.json):473baseline,9trackedfiles đổi đúng inventory,0missing, Android/native/EditorPreview.kt exact.

Không chạm5554/QA5560, không Save/export/delete media, không reset preferences để demo. Backups/evidence cũ giữ. Đây không phải audit khôi phục QA5560 hay chứng minh mọi byte trên mọi volume.

[Storage](storage_final.json), logical size:
- Build142268138091→142649801453B: **+381663362B**.
- UI05 evidence~32426133B trước report; testfont~0.313MB.
- Tổng tăng~**414.4MB/0.414GB**, dưới2GB; report thêm vàiKB.
- FreeD29570678784→29151350784B; delta còn có hoạt động AVD/system.
- Chủ yếu3 safety archives~91.1MB/lần (phần lớn Flutter debug tool assets cũ), APK/intermediates, timeline và clip nhỏ. Không tạo AVD/snapshot lớn, không cleanup. Không nhận logical size là allocated disk usage.

## 11. Remaining / owner

| Item | Status | Next / owner |
|---|---|---|
| Lifecycle/dialog/Rename/notice fixes | PASS scoped | Giữ regressions — shared UI/P2 |
| Performance/startup | PARTIAL | Lặp profile/hardware, usable-frame timing, memory; P3 review nếu trace native, không tự sửa P1 |
| Full suite | FAIL7 | P2 contract tests3; P1 recording4 |
| Settings stretch | NOT REPRODUCED | Cần exact gesture/video nếu tái xuất hiện |
| Rapid Create same-coordinate | PARTIAL | UX/P1 xem handoff/position, không gọi fake duplicate |
| Arabic tiny labels/human a11y | PARTIAL | Human readability/TalkBack |
| Native SAF/Trash/export faults | NOT RUN/PARTIAL | Disposable fixtures/QA phù hợp, tránh auto-purge data cũ |
| New-install default Follow System | WAITING FOR P1 APPROVAL từ UI02B | UI05 không sửa default Dark/shared settings hoặc persisted preference |
| Orientation toàn app | PARTIAL | Các screen nêu trên đã xoay; chưa mọi modal/state/width |
| TASK10 | NOT STARTED | Ngoài scope |

## 12. Final verdict

UI/UX05: **PARTIAL**  
MOTION FIXES: **PASS scoped**  
PERFORMANCE: **PARTIAL**  
FULL HOST: **418 PASS / 7 FAIL**  
ANDROID QA: **PASS các flow nêu trên / PARTIAL toàn app**  
P1 BOUNDARY: **PRESERVED**  
DATA PRESERVATION: **PASS trong phạm vi đối chiếu**  
NEW STORAGE: **~0.414GB**  
COMMIT/PUSH: **NO**  
TASK10: **NOT STARTED**
