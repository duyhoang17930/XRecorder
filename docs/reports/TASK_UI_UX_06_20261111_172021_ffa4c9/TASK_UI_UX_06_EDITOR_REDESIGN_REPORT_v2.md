# TASK UI/UX 06 — Editor redesign & final acceptance

Ngày 11/11/2026. HEAD `e008fbb095be62db9538f4c598cbff89e6ceb7aa`, branch `main`; không commit/push. Báo cáo theo bằng chứng, không thay thế user visual acceptance.

## 1. Executive summary

**UI/UX 06: PARTIAL.** Đã triển khai presentation P2/P3, picker-first, Create, Media Details, input Clear và kiểm thử main app Android trên đúng `ThreeHRecorder_TASK09B_API36 / emulator-5570`.

- Analyzer: **PASS**, không còn diagnostics trong lần analyze cuối.
- Focused editor/workflow/interaction/layout: **104/104 PASS**. Full host suite: **515 PASS / 4 FAIL**, cả bốn thuộc Recording Setup đã bàn giao P1. Không skip test để làm xanh.
- APK cuối xuất MP4 thực từ video + ảnh; PNG Save copy, crop/xoay thực đều full decode PASS. Các thao tác không chỉ đổi UI.
- P1 source/native contracts được giữ nguyên. Bảy draft gốc, bốn source media, Settings/onboarding được xác minh; có delta metadata journal P1 được ghi riêng ở mục16, không tuyên bố mọi file private byte-identical.
- Auto-stop overlap và screenshot delay/feedback phụ thuộc P1 chưa được sửa trái quyền. Performance và acceptance toàn diện vẫn PARTIAL. **TASK10 NOT STARTED**.

## 2. Reference audit và Phase A

Đã đọc CapCut official, README/source/license/dependencies của pro_image_editor và pro_video_editor trước khi sửa Editor. Xem [reference audit](EDITOR_REDESIGN_REFERENCE_AUDIT.md), [inventory/architecture](PHASE_A_EDITOR_ARCHITECTURE.md), [wireframe](editor_wireframe.svg).

Quyết định: học hierarchy, selected/contextual tools và picker-first; dùng controller/repository/native renderer hiện có. Không copy logo/artwork CapCut, không vendor widget gắn state riêng của OSS, không thêm package, không thay Media3/export bằng FFmpeg SDK. FFmpeg có sẵn chỉ dùng trên host để kiểm tra output QA.

## 3. UI architecture trước/sau

| Trước | Sau | Contract giữ lại |
|---|---|---|
| Video nhiều controls/clip cards xếp dọc | Preview + transport + horizontal timeline + toolbar + context | Model, autosave, history, composition/export |
| Photo tool chips/context rải nhiều hàng | Toolbar chung icon/label; Crop/Draw/Shapes/Text/Transform; context phía trên | Canvas, normalized coordinates, rendering, Save copy |
| New video tạo draft rỗng ngay | Chọn media, xác nhận rồi mới save một project | ID/schema/repository P3 |
| Create quảng bá cả mục unavailable | Hai tác vụ chính, hai đích phụ thật | Public capture/setup callbacks P1 |

Reuse `EditorTool` cho video/photo và `StudioClearTextButton` cho các input có cùng semantics. Không refactor backend/editor algorithms. Photo render function và toàn bộ native Android được đối chiếu với baseline; không sửa `EditorPreview.kt`.

## 4. Create / screenshot / icons

Create gồm Record screen, Screenshot, Recording settings và Editing Studio. Mục unavailable không còn chiếm diện tích tương đương tác vụ chính; source/routes cũ được giữ. ASR vẫn truy cập qua Subtitle Editor thật, không thêm card AI chưa nối backend. Livestream chưa có backend/owner được xác nhận nên không quảng bá là hoạt động.

Guard rapid tapping được giữ cho Create và All tools. Host test2/3/5 taps PASS; [Android final guard evidence](native_final_v2/acceptance_screens_qa.json), [Create screenshot](native_final_v2/acceptance_create.png). Modal che navigation đúng tầng. Không chạy recording/screenshot của ứng dụng; video QA dùng `adb screenrecord` riêng.

Home đã bỏ caption screenshot cố định. Feedback trước capture và dropdown delay0/3/5/10 **chưa triển khai**: API hiện là fixed3s, phải phối hợp P1 để không ghi toast vào ảnh hoặc tạo setting giả. [P1 handoff](P1_UI06_HANDOFF.md).

| Old icon | New icon | Lý do / nơi dùng | Xác minh |
|---|---|---|---|
| AppIcons.ready → Lucide circleCheck | Lucide badgeCheck | Ready của Home, cùng outline system | [Android](native_final_v2/acceptance_root_video.png) |
| Tool chips có kiểu trình bày khác nhau | AppIcons/Lucide qua EditorTool | Video/Photo toolbar có selected semantics | Native + host tests |
| Input thiếu Clear | AppIcons.close, tooltip localized, target48dp | Project/media rename, photo text, layer text | Host focus/no-submit + native Clear/Cancel |

Source audit không thấy direct `Icons.*` / `CupertinoIcons.*` trong `lib/`; không thay icon hệ thống Android. Không thêm icon/font package.

## 5. Video Editor

Top bar có Rename và Export; preview giữ GlobalKey/platform-view lifecycle. Timeline lazy, dùng cache thumbnail hiện có, playhead qua ValueNotifier. Hai mươi position ticks không gọi decode thumbnail lại trong regression test. Trim commit một lần khi kết thúc gesture, không rebuild/reload composition mỗi pointer event.

Edit mở selected filename/trim range/Split và Clip options; Transform giữ crop/rotate/flip/still duration. Audio/Text/Subtitles/Effects/Quality mở đúng editor/category hiện có. Speed vẫn là project-level theo backend, không giả per-clip speed. Thumbnail là source frame; effects được áp dụng ở preview/export.

Native final: picker video+ảnh → trim → scrub tới split point hợp lệ → Split → Undo/Redo → grayscale → Undo/Redo → Portrait/Landscape → Export PASS. Duplicate/reorder/remove/replace-source Cancel được kiểm tra thêm trên draft UI06 riêng; không dùng draft gốc để thử thao tác phá hủy.

Lỗi selection khi reorder phát hiện trong candidate đã sửa ở presentation: giữ identity clip qua move/Undo/Redo. [Unit/native evidence](selection_native_verified.json), [final menu completion](native_final_v2/acceptance_tool_menus.json).

## 6. Photo Editor

Toolbar/context chỉ hiện thuộc tính phù hợp. Color là nút mở sheet, không dàn preset thường trực. Pen/Eraser, Shapes, Text, Crop, Transform và export options vẫn tồn tại. Text có Apply đặt mark có thể Undo, đồng thời giữ gesture đặt chữ cũ. Stroke có label/giá trị; min/max.002–.02 và crop constraints vẫn được validate.

Native final đã thử Text/IME ở360dp/chữ150, màu, slider endpoints, drawing, Undo/Redo, background/resume, Save copy và quay lại Studio. Crop + Rotate90 + Save copy là session bổ sung. Rectangle/Circle/Arrow, Eraser, Keep editing/Discard được kiểm tra riêng. Eraser round-trip xác nhận xóa mark thật: Undo/Redo rồi Back không còn dirty mark. [Eraser evidence](native_final_v2/acceptance_eraser_roundtrip.json).

Hai lỗi thực tế được sửa trong quá trình acceptance:

1. **Studio khóa sau Save copy:** chờ Future của photo route đã bị `pushReplacement` giữ `creating=true`. Guard picker nay kết thúc khi launch route; regression dùng replacement contract và native Save copy → Back → New video → Cancel PASS.
2. **Toolbar tự cuộn lại khi accessibility thay đổi:** `didChangeDependencies` dùng toàn bộ MediaQuery và luôn reveal selected tool. Test trước fix cho offset220 →46.75; sau fix chỉ reveal khi geometry/IME/text scale/locale/direction đổi. Test red/green và Android Text150 đều xác minh. Không đổi drawing/render algorithm.
3. **Landscape thấp/chữ200 mất canvas và toolbar:** fallback cũ chỉ trả contextual controls. Với Android status/gesture insets24dp, regression tái hiện canvas biến mất. Nay preview vẫn ở một bên, toolbar/context cuộn ở bên còn lại; nhánh IME không đổi. Test ban đầu không có system insets đã không tái hiện, được giữ trong log; test có insets mới là red repro hợp lệ.

## 7. Editing Studio / Media Details / inputs

New video chọn tối đa30 video/still photo, có thứ tự selection; Cancel/system Back không tạo draft. Edit photo dùng photo picker thật. Năm project QA mới đều có clip; các draft0 clip cũ không bị xóa. Shortcut pinning chuyển vào menu header, tính năng vẫn giữ.

Media Details có Edit video gần Preview/Share cho video hợp lệ; giữ URI, tạo project copy và reuse project khi mở lại trong cùng Details route. Photo Edit giữ nguyên. Host test cả MediaStore và SAF URI; native MediaStore action đã thử, draft cũ dùng SAF vẫn preview sau rotation. Không xin/revoke SAF grant để mở rộng QA. Luồng import/SAF mới toàn diện còn PARTIAL.

Clear không tự Submit/Save hoặc bỏ focus. Đã thử Cancel rename trên native; source filename/media bytes không đổi. Search/language search đã có Clear nên không làm lại.

## 8. Ma trận11 vấn đề người dùng

| Vấn đề | Kết quả | Bằng chứng / giới hạn |
|---|---|---|
| Create quá nhiều card/trùng đích | PASS | Compact presenter + rapid guard native |
| Auto-stop text overlap | BLOCKED — P1 approval | Có source analysis/patch đề xuất, chưa áp dụng |
| Details thiếu Edit | PASS cho scope đã thử | Native MediaStore; host SAF; broader SAF/import PARTIAL |
| Ready/icon thiếu nhất quán | PASS | AppIcons/Lucide, ảnh Home |
| Caption screenshot và delay | PARTIAL | Home đã sạch; capture feedback/new delays chờ P1 |
| Video Editor dàn trải | PASS cho presentation/flows đã thử | Timeline/context/real MP4 |
| Photo Editor/context khó dùng | PASS cho flows đã thử | Text/draw/shapes/eraser/crop/rotate/real PNG |
| Studio tạo project trống | PASS | Picker-first; Cancel không save; draft cũ còn nguyên |
| Rename/input thiếu Clear | PASS | Focus/no-submit tests + native Cancel |
| Text stretch trong Video Project | PARTIAL — NOT REPRODUCED | Có baseline/final flings; chưa tái hiện độ méo mạnh của user |
| Root headers lệch | PASS | Reuse StudioRootHeader; bốn ảnh Android final |

Viewport context video mới không dùng overscroll stretch để glyph dễ đọc; đây là quyết định scoped presentation, **không phải bằng chứng fix root cause của ảnh méo cũ**. Không đổi physics toàn ứng dụng.

## 9. Source changes và ownership

So với dirty preflight:32 tracked source/test files thay đổi,7 source/test files mới, cộng2 dòng `analysis_options.yaml`. Mười bốn ARB chỉ bổ sung bốn key `clearText`, `homeScreenShortcuts`, `captureScreenshot`, `clipOptions`; không đổi persisted language keys/schema. Danh sách/hash đầy đủ: [source boundary](source_boundary_final_v2.json).

P1/native Android/models/controller/repository được kiểm tra473 baseline files: **0 protected violation,0 baseline source mất**. Các thay đổi UI05/05B có sẵn, native VideoPreviewActivity và untracked files trước task được giữ. Bảy reference assets đã bị user xóa trước task vẫn giữ nguyên trạng thái; UI06 không restore hoặc xóa thêm.

Files ngoài ARB:

- [lib/core/constants/app_icons.dart](../../../lib/core/constants/app_icons.dart)
- [lib/core/ui/components/inputs/studio_fields.dart](../../../lib/core/ui/components/inputs/studio_fields.dart)
- [lib/core/widgets/studio_shell.dart](../../../lib/core/widgets/studio_shell.dart)
- [lib/features/editor/editing_hub_screen.dart](../../../lib/features/editor/editing_hub_screen.dart)
- [lib/features/editor/editor_preview.dart](../../../lib/features/editor/editor_preview.dart)
- [lib/features/editor/editor_screen.dart](../../../lib/features/editor/editor_screen.dart)
- [lib/features/editor/layers_editor.dart](../../../lib/features/editor/layers_editor.dart)
- [lib/features/editor/media_picker.dart](../../../lib/features/editor/media_picker.dart)
- [lib/features/editor/project_effects.dart](../../../lib/features/editor/project_effects.dart)
- [lib/features/media/media_library_screen.dart](../../../lib/features/media/media_library_screen.dart)
- [lib/features/media/photo_tools_screen.dart](../../../lib/features/media/photo_tools_screen.dart)
- [lib/features/media/video_details_screen.dart](../../../lib/features/media/video_details_screen.dart)
- [test/design_system_test.dart](../../../test/design_system_test.dart)
- [test/editor_hci_test.dart](../../../test/editor_hci_test.dart)
- [test/localization_test.dart](../../../test/localization_test.dart)
- [test/refinement_test.dart](../../../test/refinement_test.dart)
- [test/ux_interaction_test.dart](../../../test/ux_interaction_test.dart)
- [test/widget_test.dart](../../../test/widget_test.dart)
- [lib/core/widgets/studio_quick_create.dart](../../../lib/core/widgets/studio_quick_create.dart)
- [lib/features/editor/editor_entry.dart](../../../lib/features/editor/editor_entry.dart)
- [lib/features/editor/editor_selection.dart](../../../lib/features/editor/editor_selection.dart)
- [lib/features/editor/editor_timeline.dart](../../../lib/features/editor/editor_timeline.dart)
- [lib/features/editor/editor_workspace.dart](../../../lib/features/editor/editor_workspace.dart)
- [test/editor_workspace_layout_test.dart](../../../test/editor_workspace_layout_test.dart)
- [test/ui_ux_06_workflows_test.dart](../../../test/ui_ux_06_workflows_test.dart)
- [analysis_options.yaml](../../../analysis_options.yaml)

## 10. Test commands/results

CLI được chạy tuần tự qua `run_check.py`/Flutter SDK snapshot tương đương Flutter CLI; log UTF-8 tạo exclusive.

| Check | Result | Log |
|---|---|---|
| dart format file đã đổi | PASS | [format baseline batch](format_180202_75414e.txt); formatter chạy lại khi có patch mới |
| flutter analyze --no-pub | PASS, No issues | [final analyzer](short_layout_analyze_222400_4fe13c.txt) |
| Focused editor/workflow/interaction/layout |104 PASS | [focused](short_android_insets_green_222329_2ed5f6.txt) |
| Workspace layout320/360/393/411 × scale1/1.5/2 × orientation |24 PASS | [layout](workspace_surface_fixture_180300_c48c4b.txt), cũng nằm trong full suite |
| flutter test --no-pub --reporter expanded |515 PASS /4 FAIL | [full](final_v2_full_222727_bd151e.txt) |
| flutter build apk --debug --no-pub --target-platform android-x64 |PASS | [debug](final_v2_debug_222607_a6159a.txt) |
| flutter build apk --profile --no-pub --target-platform android-x64 |PASS | [profile](final_v2_profile_222627_84f947.txt) |
| git diff --check |PASS | Chỉ có cảnh báo LF/CRLF, không whitespace error |

Red repro không bị xóa: [accessibility scroll failure](toolbar_accessibility_red_212910_76b387.txt), [short Android Landscape](short_android_insets_red_222237_3bdcba.txt). Những log đỏ do locator/fixture/tool permission được giữ; không dùng chúng làm bằng chứng app PASS. Analyzer từng đọc foreign reference Dart snapshots; đã exclude đúng `docs/reports/**/references/**`, không exclude app/tests. Profile build có warning font Cupertino framework; không thêm package chỉ để dập warning.

Bốn test P1 giữ nguyên: stale resolution expected1080pFHD/actual720pHD; pinned-controls320/360/411 không tìm handle36×4 trong khi style hiện có40×3. Không suy diễn tất cả assertion pinning phía sau đã chạy. [P1 handoff](P1_UI06_HANDOFF.md).

## 11. Android screenshots / videos / output thực

APK final debug SHA256 `92d0047b7dcfab36ab731b3179c40d86b23f6afea813e9654ec9b0f3e68b6edf`; installed APK hash được so khớp. Profile SHA trong [manifest](native_final_v2/acceptance_apk_identity.json). APK build cho **QA x64**, chưa là bản release/ARM device acceptance.

| Before thật trên AVD | After từ APK cuối |
|---|---|
| [Video cũ](baseline_editor_v2_paused_video_after_rotation.png) | [Cùng draft SAF cũ, layout mới](native_final_v2/acceptance_existing_saf_project.png) |
| [Photo cũ, Pen/Light](baseline_editor_v2_photo.png) | [Photo mới cùng fixture,411dp/font100/Light/Pen](native_final_v2/acceptance_photo_default_light.png) |

Ảnh final tiêu biểu:

- [Video Light](native_final_v2/acceptance_video_workspace.png), [Landscape](native_final_v2/acceptance_video_landscape.png), [Dark](native_final_v2/acceptance_video_dark.png), [Dark Landscape](native_final_v2/acceptance_video_dark_landscape.png), [Audio](native_final_v2/acceptance_audio_dark.png).
- [Photo Text/IME150](native_final_v2/acceptance_photo_keyboard_360_text150.png), [Landscape150](native_final_v2/acceptance_photo_landscape_360_text150.png), [Color](native_final_v2/acceptance_photo_color_picker.png), [Dark](native_final_v2/acceptance_photo_dark.png), [Shapes](native_final_v2/acceptance_photo_three_shapes.png).
- [Root Videos](native_final_v2/acceptance_root_video.png), [Photos](native_final_v2/acceptance_root_photo.png), [Studio](native_final_v2/acceptance_root_edit.png), [Settings](native_final_v2/acceptance_root_settings.png), [Details Edit](native_final_v2/acceptance_media_details.png), [Clear](native_final_v2/acceptance_clear_rename.png).
- [Video Arabic320/text200](native_final_v2/acceptance_video_320_arabic_text200.png), [Effects Arabic Landscape](native_final_v2/acceptance_effects_arabic_landscape.png), [Photo Arabic320/text200](native_final_v2/acceptance_photo_320_arabic_text200.png).

Video QA từ APK cuối: [Video Editor118.1s](native_final_v2/UI06_acceptance_video_interactions.mp4), [Photo Editor95.7s](native_final_v2/UI06_acceptance_photo_interactions.mp4), [General UX109.1s](native_final_v2/UI06_acceptance_general_interactions.mp4). Photo crop/quarter-turn là [session bổ sung](native_final_v2/UI06_acceptance_crop_transform.mp4); không giả vờ đây là cùng một session liên tục. Đã xem screenshots/keyframes và đối chiếu assertions; chưa có human continuous-playback/user acceptance. [Keyframe review](native_final_v2/video_keyframe_review.json). Có một lỗi locator khi tìm App language sau fling; case đã tiếp tục từ checkpoint và trả English/Light trong [resume evidence](native_final_v2/acceptance_screens_resume.json), không xóa partial log.

[Output validation](native_final_v2/acceptance_output_validation.json): MP4 `6.593`s expected,198 frames, PTS tăng nghiêm ngặt, full video/audio decode; grayscale tới cả đoạn video và ảnh. Hai PNG decode PASS:256×128 có text/nét vẽ,128×229 có crop/quarter-turn. Xem [MP4 thực](native_final_v2/acceptance_output.mp4), [PNG marks](native_final_v2/acceptance_photo_output.png), [PNG crop/rotate](native_final_v2/acceptance_crop_output.png). Không coi full decode là human audible/A-V-sync certification.

Một số ảnh iteration bắt đúng native preparation/configuration frame đen/old-size được giữ, không dùng làm final settled PASS. Movie còn cho thấy black frames khi composition reload trong trim/split/effects; settled rotation đã hồi phục. Cần P3 review readiness/continuity, không sửa sâu Media3/cache để làm đẹp kết quả.

## 12. Performance — PARTIAL

Các số sau là profile VM timeline cùng AVD SwiftShader/411×920/160dpi/Light/English/font1.0, **trước các fix guard/accessibility/short-Landscape cuối**. App media giữ nguyên, Studio thêm một draft QA; root dataset không hoàn toàn bằng nhau. Editor dùng cùng image và unchanged SAF project. APK final đã rebuild và functional QA; chưa có benchmark final tương đương sau khi môi trường chạy thêm emulator cá nhân. Không thao tác lên emulator đó.

| Scenario | UI p90 before ms | UI p90 after ms | Raster p90 before ms | Raster p90 after ms |
|---|---:|---:|---:|---:|
| tabs | 14.31 | 11.88 | 51.45 | 47.21 |
| create_sheets | 13.78 | 6.69 | 53.82 | 51.66 |
| settings_scroll | 4.79 | 3.02 | 45.55 | 44.53 |
| reselect | 17.74 | 3.36 | 45.95 | 41.07 |
| color_picker | 4.61 | 6.57 | 31.82 | 32.44 |
| drawing | 4.37 | 5.00 | 33.76 | 31.56 |
| photo_rotation | 31.35 | 18.10 | 90.17 | 65.50 |
| video_scrub | 4.71 | 2.91 | 40.89 | 20.44 |
| video_rotation | 29.19 | 46.73 | 34.31 | 75.82 |

Không che các số xấu hơn: color picker UI p90 tăng, video rotation có6–8 samples nên không đủ kết luận. Raster nhiều luồng vẫn vượt16.67ms; trace duration không phải presented/drop-frame count. **Không tuyên bố60/120FPS**. [Raw comparison/limits](performance_comparison.json).

PSS sau cùng kịch bản photo156829 →164793KiB (+7964KiB); đây là một điểm đo, không chứng minh leak hay memory ổn định dài hạn. Cold profile `am start -W`3127 →2267ms là Activity launch, không phải đo riêng first Flutter frame; ready hierarchy sau5.75s gồm overhead ADB. Sau resume với workload khác, cold debug9430ms; không dùng để so ngang. Không thêm splash/delay hoặc sửa P1 startup.

## 13. Orientation / accessibility / localization

| Scope | Host | Android |
|---|---|---|
| Video/Photo411 Light P→L→P |PASS |PASS: frame/marks/history/main actions |
| Video393 Dark P→L→P |PASS |PASS screenshots sau settle |
| Photo360/font150, IME, resume |PASS |PASS: Text Apply, drawing/history/Save copy |
| Video/Effects320 Arabic/font200 |PASS |PASS: native screenshots, categories/pinned actions |
| Photo320 Arabic/font200/tool sheet/rotation |PASS |Native preview/toolbar còn hiện ở short Landscape; mark giữ qua rotation/Undo |
| All widths320/360/393/411, text100/150/200 |PASS affected fixtures |Tổ hợp native được chọn ở trên; không toàn bộ Cartesian product |
| Reduce Motion |PASS duration/lifecycle tests |Global animation scales0, modal vẫn hoạt động; cấu hình đã trả lại |
| TalkBack do người thật / native-speaker review |Không thay thế bằng automation |NOT RUN |

Touch targets/selected semantics/RTL/layout được kiểm tra trong focused/full tests. Một số timeline/context ở Landscape ngắn cần cuộn; không quảng cáo mọi control luôn đồng thời nằm trong viewport. Không thêm settings/Adjust/photo font controls chưa có backend. Chất lượng ngôn ngữ toàn bộ locale cần native-speaker review; không gọi automated ARB parity là bản dịch hoàn hảo.

## 14. Storage

Logical build size: 143.313 →144.167GB, tăng0.854GB. Evidence host khoảng76.8MB, backup install khoảng729.6MB nằm trong build. Tổng tăng build + evidence ngoài build khoảng0.93GB; không cộng backup lần hai. D free28.423 →27.917GB có thể gồm hoạt động workspace khác.

Không đo allocated size đáng tin cậy; metadata walk không follow reparse points hoặc hash AVD disk. Không tạo AVD/full snapshot mới, không clean/delete. Backup/evidence của các vòng fail cũng giữ lại. [Storage measurement](storage_final.json). Báo cáo/keyframe nhỏ tạo sau snapshot chỉ thêm ítKB.

## 15. P1 handoff và remaining owners

| Item | Owner | Status / input cần |
|---|---|---|
| Auto-stop spacing/labels/IME |P1 |WAITING FOR OWNER APPROVAL cho [patch đề xuất](P1_AUTOSTOP_SPACING_PROPOSED.patch); không đổi logic/default |
| Screenshot feedback và delay options |P1 |Chốt native/API/settings contract trước; hiện fixed3s |
| Four Recording Setup failures |P1 |Review normalization và test/style contract; không sửa chéo |
| Idle journal countdown delta |P1 |Review restoration/validation; xem mục16 |
| Native preview reload black frames / hardware profile |P3 + P2 QA |Có movie/keyframes; cần readiness/latency review, không đụng rotation cache fix |
| Strong text stretch user case |P2/P3 |NOT REPRODUCED; cần gesture/video chính xác nếu còn xảy ra |
| New SAF/import/revoked-grant scenarios; long/large media |P2/P3 QA |PARTIAL, không đổi grants/dữ liệu để ép coverage |
| Human TalkBack, language quality, visual acceptance |User/QA |PENDING/NOT RUN |

## 16. Data preservation

[Final read-only comparison](data_preservation_final_v2.json):11 private files byte-identical gồm7 draft và4 prefs; tất cả original export queue rows còn nguyên;4 retained public media SHA256 match; UID10219, APK installed và display/animation/font config match baseline. Các project QA mới đều nonempty; không xóa draft0 clip cũ. Output QA mới được giữ, không tự cleanup; IDs có trong JSON.

**Ngoại lệ không che giấu:** `capture_journal.xml` không byte-identical. Native initialization giữ session ID/idle/startedAt0/elapsed0/output null nhưng `config.countdown` và `countdownRemaining`3 →0. Recording preference countdown3s trong app_settings vẫn byte-identical. [Exact journal comparison](capture_journal_runtime_comparison.json), [handoff](P1_UI06_HANDOFF.md). Không manually restore/overwrite journal. Native source cho thấy initialize không round-trip countdownRemaining, config parse nằm trong runCatching và save lại; nguyên nhân config fallback cần P1 xác nhận, không gọi suy luận là bằng chứng exception.

Không chạy capture, clear data, uninstall, wipe, root hoặc regrant permissions. QA AVD đã tắt trong thời gian quota gián đoạn: chỉ boot lại đúng existing AVD với no-snapshot-load/save, giữ userdata. Cold boot có System UI unresponsive dialog; chọn Wait hồi phục, không kill. Log lastanr không ghi app ANR. Không tương tác5554/QA5560. [Resume record](resume_avd_c343ae55.json).

## 17. Final verdict / TASK10

- **UI/UX REDESIGN: PARTIAL** overall; presentation và core flows P2/P3 đã triển khai/kiểm chứng như trên.
- **P1 BOUNDARY: PRESERVED**; P1-dependent UI/runtime review còn pending.
- **FULL TESTS: FAIL —515 PASS /4 P1 FAIL**; focused checks PASS.
- **NATIVE QA: PASS cho case ghi rõ, PARTIAL cho coverage toàn bộ/backend combinations**.
- **PERFORMANCE: PARTIAL**; không có final hardware-GPU/FPS acceptance.
- **DATA: original media/drafts/preferences/queue preserved; P1 journal metadata PARTIAL review**, không tuyên bố toàn bộ private storage bất biến.
- **USER VISUAL ACCEPTANCE: PENDING**.
- **TASK10 READINESS: NOT READY; TASK10 STARTED: NO**.

Không coi những hạng mục PARTIAL/BLOCKED là DONE. P1 coordination/QA bổ sung là các gate tiếp theo; không tự chạy TASK10.
