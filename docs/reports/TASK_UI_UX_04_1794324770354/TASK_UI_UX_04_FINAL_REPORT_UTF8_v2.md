# TASK UI/UX 04 — Editor HCI & Interaction Redesign

Ngày kiểm tra: 10–11/11/2026. Branch `main`; HEAD `64e84ec0f952c4e28063488812933010f05bfa7d`.

## 1. Kết quả

**UI/UX 04: PARTIAL.** Triển khai và regression trong phạm vi đã kiểm tra đạt. Chưa chứng nhận hiệu năng, TalkBack/máy thật hoặc mọi tổ hợp project nâng cao. **TASK10: NOT STARTED.** Không commit/push, clean, xóa dữ liệu hoặc evidence.

- Effects được tách thành màn hình có 5 nhóm, giữ Apply/Cancel và dữ liệu cũ.
- Photo Editor ưu tiên preview; công cụ và thuộc tính theo ngữ cảnh. Màu mở trong sheet; Save copy có footer riêng khi bàn phím đóng.
- Sửa controller Rename bị dispose sớm; frame preview đang pause bị đen/cắt sau xoay; tool đang chọn bị khuất sau xoay; overflow khi nhập chữ ở Landscape với IME.
- Analyzer PASS; **167/167 host tests PASS**; debug APK x64 build PASS. Đã thao tác và xem ảnh main app thật trên AVD được phép.
- PNG và MP4 xuất thật đã được đọc lại, decode và kiểm tra pixels. Không trình bày mock UI như backend hoạt động.

## 2. Preflight và inventory

Đã đọc hướng dẫn repo/local, UX Guidelines, báo cáo UI/UX trước, contracts và tài liệu P3 Editor/QA liên quan. Working tree vốn dirty; giữ các thay đổi đó, không dựng lại file từ Git HEAD. Không đủ bộ 13 ảnh lịch sử dưới đường dẫn reference hiện có; không khẳng định đã xem đủ. Đã chụp BEFORE trực tiếp: [Effects cũ](before_effects_verified.png), [Photo cũ](before_photo_verified.png), [Rectangle cũ](before_photo_rectangle_verified.png). `before_effects_top.png` chụp trước khi dialog mở nên không dùng để chứng minh Effects.

| Khu vực | Khả năng và hợp đồng giữ lại |
| --- | --- |
| Video | Preview Media3; timeline/chọn/split/trim/crop/rotate/flip clip; Undo/Redo; Rename; subtitles; Effects; Export queue. Không viết lại controller/repository/model. |
| Effects | Filter, speed/aspect; tracks/gain/fades/noise/voice/pitch/music; subtitle styles; text/sticker/drawing layers; MP4/GIF quality. Giữ keys/defaults/validation/retiming. |
| Photo | Pen, Rectangle, Circle, Arrow, Text, Eraser; crop hai chiều; rotate/flip; Undo/Redo; PNG/JPEG/size/quality. Vẫn decode một lần và lưu bản sao. |
| Gesture/history | Tọa độ tương đối với ảnh; history theo thao tác; crop guard và exit confirmation giữ lại. Eraser giữ semantics xóa mark tại điểm bắt đầu gesture. |
| Persistence | Video autosave giữ project ID/draft. Photo vẫn ở bộ nhớ đến khi Save copy; không thêm schema hoặc hứa phục hồi sau process-kill. |

## 3. Thiết kế và before/after

| Nội dung | Thay đổi / evidence | Trạng thái |
| --- | --- | --- |
| Effects | Màn hình riêng với Video / Audio / Subtitles / Overlays / Export quality. Sidebar khi rộng, danh mục cuộn ngang khi hẹp. Local state đến khi Apply. [So sánh](effects_before_after.png). | PASS phạm vi đã thử |
| Audio | Voice/pitch/music mở theo yêu cầu; reuse tracks editor. [Audio](effects_audio_dark.png), [Tracks](audio_tracks_dialog.png). Không thêm điều khiển backend chưa có. | PASS UI/mapping; audible tests NOT RUN |
| Subtitles/Overlays/Quality | [Subtitles](effects_subtitles_dark.png), [Overlays](effects_overlays_dark.png), [Quality](effects_export_quality_dark.png), [GIF controls](effects_gif_controls.png). Mở lại các sub-editor sẵn có. | PASS UI; chưa kiểm mọi tổ hợp dữ liệu |
| Photo | Preview giữ aspect, Portrait trên/dưới; Landscape preview một bên, controls bên kia. AppBar Undo/Redo, All tools, Save copy/footer. [So sánh](photo_before_after.png), [APK cuối Dark](photo_dark_latest_apk.png), [Light](photo_light_final.png). | PASS |
| Color | Nút màu hiện tại; sheet 5 preset với tên/dấu chọn; chọn xong đóng, màu giữ qua tool switch. [Dark](color_dark_latest_apk.png), [Light](color_picker_light_final.png), [RTL 200%](color_ar_320_text200_reduce.png). | PASS |
| Sliders | Stroke width có tên/pixels; chỉ hiện khi phù hợp. Crop có nhãn/phần trăm. Text/Eraser không có slider vô nghĩa. [Crop](photo_crop_final_landscape_2.png), [endpoints thật](final_photo_boundaries.json). | PASS |
| IME | Landscape quá thấp ưu tiên text field; đóng IME trả lại canvas/tools. Giữ text/focus. [Portrait](photo_text_keyboard_portrait.png), [Landscape](photo_text_keyboard_landscape.png). | PASS |
| Selected tool | Reveal tool sau đổi layout/IME, giữ selection/history. [Crop trên APK cuối sau xoay](photo_crop_selected_latest_landscape.png). | PASS |
| Cancel/exit | Color/presentation panels không đổi marks; Cancel Effects không ghi draft; giữ Keep editing/Discard. [Guard](photo_unsaved_guard_final.png), [Cancel byte-exact](video_effects_qa_v4.json). | PASS |

## 4. Root causes và sửa lỗi

1. **Slider boundary:** giữ bản sửa UI02C: nội suy floating point có thể vượt `.02`; clamp khi cập nhật state, bỏ giá trị không hữu hạn. Crop kiểm finite/bounds/min span. Android kéo đến hai đầu hiển thị 2/5 pixels trên ảnh 256px; host kiểm min/max số và cập nhật nhanh.
2. **Rename red screen:** Future của dialog hoàn tất trước khi reverse animation/TextField unmount; controller cũ bị dispose quá sớm. Controller nay thuộc State của dialog và dispose đúng vòng đời. Host tái hiện `TextEditingController was used after being disposed`; native trước sửa có red screen. [Repro](rename_reproduction_c42c87282119470f9ec61a66b1ac78b0.txt), [green](rename_fixed_c3d170d145704cf1962f0b498afc4976.txt), [ảnh lỗi](rename_checkpoint.png). Save/Cancel với IME có regression; native rename clone thành công.
3. **Frame preview pause sau xoay:** SurfaceView đổi kích thước nhưng graph pause không sinh frame mới. Seek lại từ Flutter đã thử và KHÔNG giải quyết được; experiment được gỡ bằng patch hẹp. `editor_preview.dart` hiện khớp hash baseline. Native **P3** bật replayable cache Media3, replay frame sau Surface changed và gỡ callback khi dispose. Không tự play audio, seek/reload composition hoặc thêm channel.
   [Trước đen](preview_paused_landscape_refreshed.png) → [Landscape đã sửa](native_cache_preview_landscape_refreshed.png), [về từ Effects](native_cache_preview_after_rotated_effects.png), [trở lại Portrait](native_cache_preview_return_final.png). [Vị trí 1.0s giữ qua xoay](native_cache_preview_final.json). Khi vừa mở, preview còn chờ prepare: [ảnh sớm](video_preview_latest_apk.png), [ảnh settle](video_preview_settled_latest_apk.png). Chưa đo chính xác latency frame đầu.
4. **Tool bị khuất:** viewport toolbar dựng lại giữa Row/Column và mất offset. Test đỏ ghi bounds phải `1204.56 > 856`; reveal sau layout sửa lỗi, assertion geometry giữ nguyên và PASS.
5. **IME overflow:** test có SafeArea 24dp và IME 260dp tái hiện overflow 17px. Compact layout ưu tiên TextField, giữ FocusNode/GlobalKey/controller; host và Android đã qua.
6. **Label ES/FR dài:** Row giá trị stroke từng overflow; đổi sang Wrap, không giảm text scale hoặc xóa expectation.

API/tradeoff theo [CompositionPlayer 1.11.0](https://github.com/androidx/media/blob/1.11.0/libraries/transformer/src/main/java/androidx/media3/transformer/CompositionPlayer.java): replayable cache dùng thêm tài nguyên. Cần profile với media lớn và retest khi nâng Media3. HCI tham khảo [Apple toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [motion](https://developer.apple.com/design/human-interface-guidelines/motion); không sao chép asset Apple.

## 5. Changed-file inventory

| File/nhóm | Thay đổi UI04 |
| --- | --- |
| `lib/features/editor/project_effects.dart` | Nhóm/adaptive Effects, Apply/Cancel cục bộ; giữ mapping. |
| `lib/features/editor/editor_screen.dart` | State/controller Rename dialog. |
| `lib/features/media/photo_tools_screen.dart` | Layout/contextual tools, active gesture repaint, bounded sliders, IME/tool visibility. Giữ load/save/render contracts. |
| `lib/features/media/photo_editor_panels.dart` — mới | Color picker và export options presentation-only. |
| `android/app/src/main/kotlin/com/xrecorder/xrecorder/editor/EditorPreview.kt` | Replay frame khi Surface resize; chỉ preview P3. |
| `lib/core/constants/app_icons.dart`, `lib/core/ui/theme/motion.dart` | Alias Lucide/chip motion additive. `brandReveal` đã có trước UI04. |
| `lib/l10n/app_*.arb` — 14 file | 13 key Editor mới cho 12 locale/variants; giữ entries cũ, dùng generator hiện tại. |
| `test/editor_hci_test.dart` — mới | Context/history, responsive/RTL, picker/options, IME, repaint isolation, finite bounds, tool visibility. |
| `test/editor_preview_load_queue_test.dart` | Resize không seek/load từ Flutter; giữ kiểm serialization gốc. Native redraw kiểm trên Android. |
| `test/ux_interaction_test.dart`, `test/refinement_test.dart`, `test/task09b_editor_interactions_test.dart`, `test/task09b_history_localization_test.dart` | Dialog/IME regression; mở đúng nhóm/tool mới và sửa locator scroll; giữ data/timing/error assertions. |

`test/photo_tools_test.dart` đã dirty trước task; regression Slider sẵn có được chạy lại. Settings/shell/splash/onboarding/MainActivity dirty từ trước không bị ghi đè. Không xóa backend/components ngoài thay subtree presentation đúng phạm vi redesign.

## 6. Design-system reuse và motion

Reuse Manrope, StudioColors, spacing/radius, Lucide/AppIcons, StudioDialog/Studio bottom sheet. Không thêm package, artwork hoặc blur trên ảnh/video. Chip selection 180ms, enable 120ms; reveal/advanced panel dùng AppMotion; Reduce Motion đưa duration về zero. Không animate từng sample vẽ hoặc delay input.

Test 20 pointer samples xác nhận toolbar widget không rebuild mỗi sample; image instance giữ qua xoay. Không tự suy ra FPS từ test này.

## 7. Performance

**PARTIAL — không chứng nhận 60 FPS hoặc không regression.** [Gfxinfo debug cuối](final_gfxinfo.txt): 181 Android frames, 154 janky (85.08%), p50 28ms/p90 150ms. Đây là thống kê Android UI tích lũy trong phiên debug/emulator với rotate/font/locale changes, không phải Flutter raster benchmark hoặc đối chứng trước/sau. Không bỏ qua số xấu, cũng chưa có baseline tương đương để quy cho patch cache.

[Meminfo](final_meminfo.txt): PSS 387112KB tại một thời điểm; không chứng minh không leak. Cần profile đối chứng trên QA hardware/media 1080p, nhiều layer/track, đo build/raster, frame đầu và chi phí cache. `am start -W` debug vẫn timeout khoảng 15–16s như vấn đề startup có trước; UI04 không sửa startup/P1 hoặc tuyên bố tối ưu nó.

## 8. Android, orientation, accessibility

Chỉ dùng `emulator-5570`, xác minh AVD **ThreeHRecorder_TASK09B_API36**, user0, main app thật và install-replace. APK cài trên thiết bị khớp output SHA256 `3a413219a95158ef9a0eb1fac95bd3765d19be56019d3a2aee8a98ba35dc5ba2`.

| Screen/flow | Kiểm Android | Trạng thái |
| --- | --- | --- |
| Photo + marks/Undo/Redo | P→L→P; so pixels sau trở lại | PASS |
| Color | P→L→P Dark; Light; Arabic 320dp/text200 và Landscape | PASS phạm vi đã thử |
| Crop/export options | P→L→P; controls còn, scroll khi màn thấp | PASS |
| Transform | Rotate 90° rồi Undo trên fixture | PASS; không lặp mọi tổ hợp flip Android |
| Photo Text/IME | Nhập `UI04_keyboard`, P→L→P, giữ text/focus | PASS |
| Effects Overlays | UI04 text giữ qua P→L→P; Cancel không ghi draft | PASS |
| Paused preview | 1.0s P→L→P; rotate trong Effects rồi Cancel | PASS sau sửa |
| Effects adaptive | Light/Dark; Arabic text200 320×920 và 920×320 | PASS nhóm đã mở; cần scroll controls dưới |
| Width/native font | Photo RTL 320/200%, 360/150%, 393/100%, 411/100% | PASS layout/Save reachability; không phải toàn Cartesian matrix |
| CJK/12 locales | Host layout/localization suites | PASS host; chưa đủ locale Android/máy thật |
| Targets/Reduce Motion | Host target/semantics/zero-duration; Android animator scale0 | PASS automated; human TalkBack/motion NOT RUN |

[Ma trận Android](editor_native_rtl_responsive.json), [keyboard](photo_keyboard_light_resume.json), [crop/options/guard](photo_keyboard_light_complete.json), [endpoints APK cuối](final_photo_boundaries.json).

[Video tương tác](photo_interaction_v2.mp4), ~20.08s encoded/0.81MB: Pen → Color/Cyan → width → draw → Undo → Redo → Rectangle → Landscape → Portrait. [20 frame mẫu đã xem](photo_interaction_v2_full_review.png), [actions](photo_interaction_result_v2.json). Video có trước patch cuối reveal tool; APK cuối được kiểm riêng bằng native RTL run/screenshot. Video không chứng nhận FPS/human usability.

Giữ các attempt lỗi. Có lỗi harness: hint TextField không nằm trong content-desc, locator loại Transform ở footer, UiAutomator tranh service. Đã sửa harness rồi tiếp tục, không đổi app để che lỗi. Không kill tiến trình không rõ hoặc xóa data. Rename red screen là lỗi app thật, xử lý riêng tại mục4.

## 9. Output thật và state

- [PNG validation](photo_output_validation.json): 2 copy 256×128, 6573/6640 bytes, full decode PASS, pixels đổi 527/810 so input tương ứng. Undo đổi 1344 pixels ở preview ROI; Redo và return Portrait đều 0 pixel khác so ảnh đã vẽ.
- [MP4 validation](video_output_validation.json), [file MP4](UI04_export_ca13829a.mp4): queue completed; H264 96×64 + AAC stereo; 2.066395s, 436509 bytes. Full decode/DTS monotonic PASS; pixel filter invert và 302 pixel trắng overlay UI04 được kiểm. Không suy ra chất lượng video lớn, audible audio hoặc A/V sync.
- Clone qua Duplicate draft: `project_1794327848468607`, tên `UI04_Editor_QA`. Apply invert/text, Undo/Redo, export và mở lại sau install-replace giữ draft. Project gốc không sửa.
- GIF/JPEG export lại Android UI04, nghe mọi audio effect, max8 tracks/nhiều layers, process-kill đang edit/export: **NOT RUN**. Control/mapping có host regression; không lấy evidence Task09B cũ làm PASS runtime mới.

## 10. Exact checks và kết quả

Chạy tuần tự bằng Dart trực tiếp + Flutter tools snapshot của SDK `D:\Android\flutter`, tránh tranh lock. Lệnh tương đương:

```text
dart format <12 Dart files liên quan>
flutter analyze --no-pub
flutter test --no-pub test/editor_hci_test.dart test/photo_tools_test.dart test/editor_effects_ui_test.dart test/task09b_editor_interactions_test.dart test/task09b_history_localization_test.dart test/project_controller_test.dart test/project_repository_test.dart test/timeline_effects_test.dart test/drawing_project_snapshot_test.dart test/editor_preview_load_queue_test.dart test/ux_interaction_test.dart test/refinement_test.dart test/global_layout_test.dart
flutter build apk --debug --no-pub --target-platform android-x64
git diff --check
dart format --output=none --set-exit-if-changed <12 Dart files liên quan>
```

| Check cuối | Kết quả/evidence |
| --- | --- |
| Analyze | No issues, exit0, 4.8s — [log](analyze_7afe1945ab4f46d2aa5b9ee44bb881dd.txt) |
| 13 host files | **167 PASS**, exit0, ~57s — [log](editor_tests_4310343096bf46a4b67f7ade9ca04418.txt) |
| Debug build | PASS, exit0, assemble ~20s — [log](build_9fbc5c8ed27a48c093c81c2d55783083.txt) |
| Format/diff | PASS; 12 files/0 format changes; Git chỉ cảnh báo LF/CRLF — [log](final_checks.txt) |
| Android | Flow ở mục8–9 có runtime evidence; không dùng test-only entrypoint |

[Runner](verify_host.ps1). Các lần đỏ trước: locator, ES/FR overflow, Rename lifecycle, SafeArea/IME, tool geometry. Không skip/xóa expectation để xanh. Không chạy lại toàn TASK09B/full host suite; chạy 13 file liên quan.

## 11. P1 boundary và preservation

[Manifest cuối](final_preservation.json), [baseline](baseline.json), [SAF](final_saf_permissions.txt), [Git status](final_git_status.txt).

- 52/53 source hashes trong danh sách bảo vệ khớp. Khác duy nhất **native EditorPreview.kt thuộc P3**, sửa có chủ đích. Recording/capture, MainActivity, recording Settings/controller, shared Create, model/repository/controller trong danh sách khớp baseline dirty.
- **4 shared_prefs + project gốc khớp byte tuyệt đối**. Chỉ thêm clone QA. Theme Dark, locale Follow system/onboarding preferences trở về giá trị cũ; không overwrite documents để restore.
- Hai ảnh fixture giữ SHA baseline. UI02C/Task09B SAF tree còn persisted `0x3`. Không có checksum trước task cho mọi video/model/database; không tuyên bố kiểm toàn bộ dữ liệu app.
- AVD trở về 411×920/density160/font1.0/rotation0/auto1/animator null. Không thao tác QA5560/5554, tạo/wipe AVD, snapshot, clear data, uninstall hoặc chạy P1 capture.
- Staged list rỗng; dirty/untracked work và mọi evidence giữ lại. Clone/ảnh/MP4 mới là output QA được giữ.

## 12. Storage

[Số đo](final_storage.json), một lượt logical-size scan, bỏ reparse points; không hash 141GB.

| Phép đo | Trước | Sau | Chênh |
| --- | ---: | ---: | ---: |
| build logical bytes | 141309297691 | 141309690523 | +392832 bytes (~0.39MB) |
| Free D: bytes | 30717423616 | 29604143104 | −1113280512 bytes (~1.11GB) |
| Evidence mới | 0 | khoảng 6.9MB kể cả báo cáo/check cuối | Không xóa evidence cũ |

Logical size không phải allocated sparse AVD size. Chênh free toàn ổ gồm hoạt động AVD/cache/tiến trình khác; chưa có allocation baseline để quy chính xác 1.11GB cho task. Không giấu chênh này sau số build nhỏ; không clean. Không tạo artifact lớn >2GB; APK là output debug hiện có được build lại.

## 13. Remaining gates và owner

| Hạng mục | Owner/trạng thái |
| --- | --- |
| Profile, latency frame đầu, replay cache ở media lớn | P3/QA — PARTIAL; cần profile đối chứng, debug gfxinfo chưa đủ cơ sở chứng nhận smoothness. |
| TalkBack/máy thật/drawing dài/thermal | QA người thật — NOT RUN; automated semantics không thay thế. |
| Nested audio/layer/subtitle dialogs max data, mọi locale/orientation | P3/QA — PARTIAL, không suy ra từ happy paths. |
| JPEG/GIF, audible audio/A-V sync regression mới | P3/QA — NOT RUN runtime UI04; backend không đổi, PNG/MP4 thật đã xác minh. |
| Bản dịch cũ/label hỗ trợ dài text200 | Localization review — PARTIAL; có ellipsis ở supporting labels và cần cuộn ở Landscape thấp. Chưa linguistic acceptance. |
| Startup debug chậm | Gate performance/startup riêng; không sửa P1, không coi bỏ splash trước đây là sửa latency. |
| Recording/encoder/permission/rotation | P1 — không sửa/chạy capture. TASK10 không mở. |

## 14. Ghi chú report

Bản xuất đầu bị pipeline PowerShell chuyển ký tự thành dấu hỏi; đã xóa bản lỗi trong lượt dọn file được người dùng yêu cầu. **Dùng bản UTF-8 v2 này**. Nội dung v2 ghi bytes UTF-8 trực tiếp, kiểm dấu tiếng Việt và link local.

**P1 BOUNDARY: PRESERVED. DATA PRESERVATION: PASS trong phạm vi đối chiếu nêu trên. TESTS: PASS (167 host và native flow có evidence). PERFORMANCE: PARTIAL. UI/UX 04: PARTIAL. TASK10: NOT STARTED.**

## 15. Dọn file và refactor theo yêu cầu — 11/11/2026

- Xóa 77 artifact không còn cần, 43.10 MB: binary Flutter trùng hash với APK, script/ảnh/video thử đã có bản cuối, log PASS trung gian, bytecode Python và report lỗi encoding. Giữ báo cáo cuối, log lỗi quan trọng, ảnh/video đang được dùng làm bằng chứng và toàn bộ recovery TASK08.
- Gộp 8 báo cáo UI/UX 02–02B thành [UI/UX 02](../../implementation/TASK_UI_UX_02_REPORT_20261110.md) và [UI/UX 02B](../../implementation/TASK_UI_UX_02B_REPORT_20261110.md). Các trạng thái lịch sử không đổi. Backup dữ liệu QA và snapshot source giữ trên ổ, thêm rule Git-ignore riêng.
- All tools/Shapes dùng chung `choosePhotoTool` trong `photo_editor_panels.dart`; giữ danh sách, scrolling, callback và Apply/Cancel, đồng bộ dấu chọn với tool đang hoạt động. Không đổi drawing/history/export hoặc P1.
- Có lỗi dấu ngoặc thừa trong lượt patch đầu, bị format/analyzer bắt; đã sửa trước khi chạy regression. [Log đỏ](analyze_21b7ef3cd6e64795b6d6dc5a681a8fb3.txt) được giữ.
- Sau refactor: [Analyzer PASS](analyze_23c4137080bd45d7bea03677965d8881.txt), [168/168 tests PASS](editor_tests_d79348ffdc074f46a6aa94a9db5d74ab.txt), [debug build PASS](build_4d9be169623a4a69ac71cbfaf85a7974.txt). Test mới kiểm Back không mất marks và selection nhất quán giữa hai picker.
- Không install hoặc thao tác AVD trong lượt dọn/refactor này. Ảnh/video Android ở các mục trước thuộc bản trước refactor; không coi đó là runtime test mới. SHA APK phía trên cũng là SHA của lượt Android trước.
- Không commit/push. Gate performance/TalkBack còn PARTIAL; TASK10 vẫn NOT STARTED.
