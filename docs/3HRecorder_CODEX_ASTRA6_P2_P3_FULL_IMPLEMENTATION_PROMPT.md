# MASTER IMPLEMENTATION PROMPT — 3HRecorder / Person 2 + Person 3

> **Dùng cho:** Codex, model **GPT-6 Astra**, reasoning **Extra High (`xhigh`)** cho audit/kiến trúc/tích hợp phức tạp; có thể dùng **High** cho từng task nhỏ đã xác định rõ.  
> **Mục tiêu:** Hoàn thiện ứng dụng Android 3HRecorder ở mức chất lượng sản phẩm thực sự, tập trung **P2 (App Core, Media, UX)** và **P3 (Editor, Export, AI)**.  
> **Dự án:** https://github.com/duyhoang17930/XRecorder  
> **Ngày yêu cầu:** 06/11/2026.  
> **Lưu ý:** Đây là **lệnh triển khai**, không phải yêu cầu chỉ lập kế hoạch. Làm từng milestone, kiểm chứng và tiếp tục trong phạm vi an toàn. Không tự báo đã hoàn thành khi chưa có bằng chứng chạy thực tế.

---

## 1. Vai trò, quyền sở hữu và phạm vi cứng

Bạn là **Principal Flutter/Android Engineer + Mobile Product Designer + Senior QA/Performance Engineer** của 3HRecorder.

Ứng dụng dùng Flutter cho UI, kết hợp Android native khi đó là cách đúng để xử lý media, file, codec, DSP hoặc hiệu năng. Tôn trọng kiến trúc hiện tại, tránh big rewrite không cần thiết.

Nhóm có **3 người**, nhưng người yêu cầu chỉ đảm nhiệm **hai phạm vi** dưới đây:

| Phạm vi | Chủ sở hữu | Trách nhiệm |
| --- | --- | --- |
| **P1 — Capture & Realtime** | Đồng đội khác, **KHÔNG sửa** | Screen recording, screenshot, mic/internal audio lúc quay, floating ball, Facecam, draw overlay, YouTube/RTMP Live, recording native service |
| **P2 — Core/Media/UX** | **Bạn thực hiện** | UI/UX HCI toàn app, navigation, media catalog/preview/actions, storage, settings, help/support, shared components, app/native bridge integration |
| **P3 — Editor/Export/AI** | **Bạn thực hiện** | Video editor, photo editor, timeline, audio hậu kỳ, drafts, export/compress/GIF, subtitles AI và export subtitle |

### Ngoài phạm vi — không tiêu tốn thời gian vào đây

- Không tạo tài khoản Google Play Console, không publish/update app, không viết Store Listing, ASO hoặc hình Play Store.
- Không thiết lập khóa ký phát hành của người dùng; không hỏi hoặc lưu secrets/signing material.
- Không làm định giá, thuê server, thanh toán dịch vụ, quản trị hóa đơn hoặc ngân sách.
- Không triển khai Google Play Billing, Subscription, Pro purchase, quảng cáo, ad mediation hay revenue analytics. Các feature **F54–F56** gạch khỏi scope thực hiện hiện tại.
- Không làm pháp lý/đăng ký trademark/review license thay nhóm khác. **Tuy nhiên bắt buộc ghi nguồn, phiên bản/commit, file/logic đã reuse và thông tin license thấy được** vào tài liệu để họ thẩm định. Không đưa vào app mã/binary không có nguồn hợp lệ hoặc các bản decompile không được phép; không xóa attribution hoặc che giấu provenance.
- Không viết lại/thay đổi trực tiếp P1 capture pipeline, `CaptureService`, encoder, permission consent, Facecam, drawing-over-app hoặc native livestream. Nếu cần contract hoặc event, tạo yêu cầu tích hợp hoặc adapter được phê duyệt; không chiếm ownership.
- **AI có thể cần backend/model**, nhưng mọi chuyện chi phí, hạ tầng, tài khoản/credentials sẽ do bên khác cung cấp. Ở phần P3, ưu tiên thử giải pháp **on-device/offline thực sự chạy được**; nếu không khả thi trên thiết bị mục tiêu, xây dựng frontend + API contract thật, ghi rõ external dependency. Không tạo AI giả, không fake transcript và không tuyên bố hoàn thiện khi backend thiếu.
- Không tự commit/push/merge vào main nếu chưa được yêu cầu rõ. Không xóa draft/media người dùng, không uninstall/clear-data/emulator wipe, không reset hard hoặc sửa file unrelated.

### Kết quả mong muốn

1. Ứng dụng **có thể dùng thật**, không chỉ đẹp hoặc trình diễn.
2. Mỗi chức năng UI có backend/hành vi thật hoặc trạng thái unavailable trung thực.
3. Không làm hỏng recording/screenshot/overlay do P1 phụ trách.
4. Video, ảnh, draft gốc không mất dữ liệu sau lỗi/Back/background/restart.
5. Flutter analyze/tests/build và Android-native smoke đạt trong phạm vi thiết bị có thể kiểm thử.
6. Bàn giao code, APK QA, reports, test evidence và danh sách giới hạn còn tồn tại; không cần publish.

---

## 2. Bắt buộc khảo sát trước khi code

ĐỌC TRỰC TIẾP từ working tree, không suy đoán từ README và báo cáo trước:

1. `AGENTS.md` ở root và các AGENTS lồng (nếu tồn tại), quy tắc Git/current branch.
2. `README.md`, `pubspec.yaml`, Android native files, Flutter entrypoint/routes.
3. `docs/APP_SPEC_VI.md`, `docs/TECH_STACK_RESEARCH_VI.md`, `docs/IMPLEMENTATION_PHASES.md`, `docs/XRecorder_Flutter_Implementation_Master_Plan.md`, tài liệu reference screenshots.
4. Task 01/02/02.1/02.2/03/03.1, tài liệu `3HRecorder_TASK_03_1_UX_GUIDELINES.md` và `USABILITY_TEST_VI.md` nếu hiện diện.
5. Repo `lib/features/home/`, `lib/features/media/`, `lib/features/settings/`, `lib/features/editor/`, `lib/core/`, `lib/app/`.
6. `android/app/src/main/kotlin/com/xrecorder/xrecorder/` gồm `media/`, `editor/` và `MainActivity.kt`.
7. Unit/widget/integration tests, native output validation, performance/visual reports và APK handoff hiện có.
8. `git status --short`, branch, HEAD. Lập baseline riêng; **giữ nguyên** mọi dirty changes hiện tại, nhất là code P1 mà người khác đang sửa.

### Khởi tạo bảng kiểm chứng cho từng tính năng

Đánh dấu mỗi feature là **DONE / PARTIAL / MISSING / BLOCKED / UNVERIFIED**, kèm:

- Code path và dòng/chức năng tương ứng.
- UI entry point và native dependency.
- Test có sẵn và kết quả thực sự đã chạy.
- Vấn đề UX, lỗi dữ liệu, hiệu năng, permission hoặc compatibility.
- Mục tiêu cải thiện, definition of done, người sở hữu (P2/P3/P1).

Không lấy nhãn DONE từ lịch sử Task03/03.1 mà chưa nhìn mã hoặc chạy verification. Không reimplement tính năng đã hoạt động tốt; ưu tiên **sửa phần thiếu, bug và usability debt**.

Ghi audit đầu tiên ở `docs/implementation/P2_P3_CURRENT_AUDIT.md` (tạo folder nếu cần). Đây là checkpoint, không được dừng toàn bộ công việc sau khi viết audit.

---

## 3. Tiêu chuẩn kỹ thuật và triết lý thực thi

### 3.1 Reuse GitHub là ưu tiên số 1, nhưng phải thực dụng

- Tìm các repo/package GitHub **gần nhất với đúng tính năng** trước khi tự viết algorithm/phần lớn UI.
- **Không phân biệt ngôn ngữ**: Dart, Flutter, Kotlin, Java, C/C++, Rust, Swift (chỉ tham khảo logic cho Android), JavaScript/TypeScript, Python đều có thể tham khảo hoặc port.
- Quy tắc chọn: **reuse package tương thích trực tiếp** > **reuse một module/native wrapper** > **port thuật toán/kiến trúc có test** > **viết mới**.
- Android-first: không cố port media encoder native thành Dart khi dùng Kotlin/Java Media3 hiệu quả và dễ kiểm chứng hơn. C++ DSP hoặc STT có thể tích hợp qua JNI/FFI nếu benchmark chứng minh hiệu quả.
- Không thay package/model/schema đã ổn định chỉ vì có repo mới hoặc nhiều stars.
- Kiểm tra release gần đây, health, API level, Flutter/Dart/Gradle/AGP compatibility, minSdk, ABI, binary size, RAM, security, transitive dependencies, maintenance và license metadata.
- **Đánh giá thực tế** bằng POC nhỏ và test đầu ra trước khi đưa vào app; fallback/rollback path bắt buộc.
- Không dán code từ repo khác một cách mù quáng, không bundle ví dụ/debug secrets, không hardcode CDN/model link không được kiểm chứng.
- Ghi `docs/implementation/REUSE_REGISTER.md`: GitHub URL, tag/commit, mục đích, cách tích hợp/port, phần được chỉnh sửa, tests, hạn chế và ghi chú license để bộ phận khác xử lý.

### 3.2 Danh sách candidate có thật để nghiên cứu, không bắt buộc dùng tất cả

| Nhu cầu | Repo tham khảo | Ghi chú |
| --- | --- | --- |
| Android media playback/edit/export | https://github.com/androidx/media | Ưu tiên xem **Media3/Transformer** cho xuất video, composition, format/capability; kiểm tra version hiện tại |
| Flutter official utilities | https://github.com/flutter/packages | `video_player`, `file_selector`, `go_router`, `animations`, `image_picker`, `shared_preferences`, `quick_actions` |
| Media catalog/gallery | https://github.com/fluttercandies/flutter_photo_manager | Đối chiếu với MediaStore/SAF native đã có; tránh hai catalog cạnh tranh |
| Image viewer, editor UX | https://github.com/fluttercandies/extended_image | Crop/rotate/flip/zoom; cân nhắc reuse widget/logic thay vì rewrite ảnh gốc |
| Video trim/crop UI | https://github.com/LeGoffMael/video_editor | **Chỉ UI/editor controller**, repo không tự cung cấp pipeline export hoàn chỉnh |
| Native sharing | https://github.com/fluttercommunity/plus_plugins | `share_plus` và các plugin tương ứng; chỉ thêm nếu giải quyết thiếu sót thật |
| Image/animated GIF processing | https://github.com/brendan-duncan/image | Dart GIF, PNG, image transforms; benchmark trên ảnh/video lớn, isolate/memory |
| Audio noise reduction | https://github.com/xiph/rnnoise | Candidate DSP hậu kỳ, cần test chất lượng âm thanh và overhead native |
| Local speech-to-text | https://github.com/ggml-org/whisper.cpp | Có Android example; cần đánh giá model size, Vietnamese accuracy, RAM/battery |
| Flutter animation references | https://github.com/flutter/samples | Học các mẫu motion và animation thay vì thêm package nặng |

Có thể tìm repo **khác tốt hơn** sau khi nghiên cứu, kể cả Java/Kotlin/C++/Python, nhưng phải nêu cơ sở so sánh. Không gắn chặt tên candidate vào kiến trúc nếu source hiện tại đã có module tốt hơn. Đừng cài cả 10 repo cùng lúc.

### 3.3 Tiêu chuẩn kiến trúc

- Flutter = presentation, gestures, accessible controls, navigation, state. Native Android = MediaStore/SAF, Media3 transforms/codecs, service/platform-specific processing. Backend AI (nếu cần) = adapter độc lập.
- API/contract rõ: `MediaScope`, `MediaItem`/Content URI, `EditorProject`, `ExportJob`, `MediaChangeEvent`, typed errors. Dùng interface hiện có; chỉ thêm khi cần.
- State machine đơn nhất cho job: idle → preparing → running → finalizing → succeeded/failed/cancelled, đúng semantics. Không trộn processing của screenshot với encoding video.
- Editor non-destructive: lưu instruction/project và xuất bản sao; không bao giờ ghi đè file gốc.
- Tách rendering pipeline khỏi widget; snapshot input bất biến khi người dùng nhấn Export; guards đồng bộ trước await.
- Media file qua Content URI/SAF grant, không giả định mọi file đều có filesystem path cố định.
- Cache có invalidation, dispose và giới hạn RAM. Background work chỉ dùng cơ chế Android phù hợp.
- Không hardcode theme/spacing/strings trong nhiều màn; reuse design tokens khi phù hợp; **UX ưu tiên hơn việc ép các tình huống khác nhau vào một giant shared widget**.
- Không tự tạo state giả hoặc snackbar báo Saved nếu native chưa ghi được output.

---

## 4. P2 — THỰC THI CHI TIẾT: Product Shell, UI/UX, Media & Platform

### P2-A. Full-app HCI redesign, không phải chỉ sửa bug nhỏ

1. Audit từng màn **Video, Photo, Create, Edit, Settings, Library, Detail, Help**, và mọi sheet/dialog/error/permission explanatory UI.
2. Thiết kế rõ user journeys: **mở app → bắt đầu quay**, **chụp → xem ảnh**, **tìm video → mở/xử lý/chia sẻ**, **mở editor → sửa → xuất**.
3. Riêng màn Home screenshot tham chiếu: xem lại vị trí Record screen tương đối cao, tỉ lệ card chiếm không gian, Screenshot là CTA thứ cấp, thông tin `720p/30FPS/Mixed`, nội dung dài về minimize/3s delay, search/filter khi 0 items và bố cục bottom nav.
4. Xây hệ thống **visual hierarchy**: action chính dễ tìm, secondary rõ nhưng không cạnh tranh, danger actions phân biệt, icon + label đúng ngữ nghĩa.
5. HCI: Fitts (vùng chạm), Hick (lựa chọn có tổ chức), Jakob/consistency, recognition over recall, error prevention, visibility, user control, progressive disclosure. Không suy từ sách rằng app đã thuận tay nếu chưa thử thực tế.
6. Audit one-hand: tay trái, tay phải, màn 320/411dp/lớn hơn; primary tasks dễ thao tác, không che system gesture/nav; header vẫn hiểu được.
7. Tăng vùng chạm interactive controls tối thiểu **48dp**, giữ hit area lớn hơn icon size; TalkBack label/hint/role/value.
8. Nội dung ít chữ, nhất quán, hướng người mới: “Record screen”, “Screenshot”, “Saved”, “View”, “Try again”; giải thích system consent vừa đủ và **không làm permission giả**.
9. Dark Bento Studio/Manrope offline/Lucide là baseline nhận diện, nhưng có thể chỉnh palette, contrast, density, elevation, typography nếu **chứng minh UX tốt hơn**. Không cần sao chép y hệt XRecorder tham chiếu.
10. Hệ thống tokens: color roles, surfaces, spacing, radii, text styles, icon size, motion duration, semantic states; dùng theme extension nếu phù hợp.
11. Animation mục đích rõ: tactile feedback 100–160ms; micro 150–220ms; route 220–320ms nếu phù hợp; giảm chuyển động khi Reduce Motion; không replay vô cớ khi rebuild.
12. Không thêm shader/blur nặng, stagger kéo dài hoặc lạm dụng Hero gây mất state/giật khi recorder/export chạy.
13. Test text scale 100%/200%, Light/Dark, 320dp/411dp/tablet nếu có; overflow, keyboard inset, notch/status bar, landscape editor.
14. Thực hiện **before/after screenshot comparison**, đánh giá 10 task usability trên máy test; chưa có người thật thì nói rõ chưa có.
15. Không “redesign mọi thứ” nếu màn hiện đã tốt; chỉ thay đổi dựa trên lỗi hoặc lợi ích người dùng được mô tả.

### P2-B. App navigation & Create shell

- Giữ 4 tab thực: Video/Photo/Edit/Settings; Create (+) là action menu. Không thay stack hoặc route contract tùy ý.
- Tab reselect scroll-to-top; chuyển tab phù hợp thì giữ state hoặc reset theo existing requirement, kiểm tra không tạo lại controller nặng.
- Android Back/system gesture/PopScope nhất quán với trình trạng dirty/save/recording; không double-pop.
- Create menu có source/selected state; action chưa có phải cho thấy unavailable thật, không tạo fake success.
- Search/filter không ép hiển thị khi library trống nếu làm UI rối; gắn CTA phù hợp để người dùng có bước kế tiếp.
- Dialog/sheet/feedback đồng nhất nhưng khác biệt trạng thái capture thật từ P1 so với editor job P3.
- Home dynamic: Ready/Recording/Paused/Saving/Saved state đọc P1 contract; không patch CaptureController riêng.

### P2-C. F24 — Video/Photo Library

- Auto-index media app và thư mục SAF được người dùng chọn; chọn đúng permission/ownership.
- Media grid/list responsive, nhóm ngày, thumbnail đúng orientation, duration/size/time; loading placeholder lightweight.
- Sort newest/oldest/name/duration/size nếu data support; filter video/photo/folder và search local không lag.
- Pagination/lazy list và thumbnail caching; invalidation khi rename/delete/export/file changed; không scan full library mỗi frame.
- Empty states hướng hành động (0 video → Record; 0 photos → Screenshot); phân biệt empty folder, empty query và permission denied.
- Auto-update khi P1 lưu record/screenshot hoặc P3 xuất; state notifier/event refresh; không yêu cầu user đóng mở app.
- Test >100/1000 media items, image lớn/video dài, permission revoked, rapid scroll, rotate và folder switch.

### P2-D. F25 — Media viewer & details

- Video player play/pause, seek, scrub, duration/current position, mute/volume nếu phù hợp; lifecycle/background/pip chỉ khi được chọn.
- Photo preview pinch zoom/double tap/drag, orientation EXIF đúng, fit/fill hợp lý và không cắt sai.
- Fullscreen immersive giữ status/nav logic và Back; không giật khi chuyển media.
- Metadata thực: resolution, codec nếu có, duration, size, modified/created; unknown rõ ràng.
- Missing/corrupted content URI xử lý lỗi, Retry/Re-select folder; dispose texture/controller để tránh leak.
- Chuyển vào Edit bằng route/contract của P3, không tự tạo một editor thứ hai.

### P2-E. F26/F45/F46/F47 — Media actions, transfer, trash & storage

- Share chuẩn Android Sharesheet với `content://` grants, MIME đúng, revoke đúng thời điểm; không expose đường dẫn private vô cớ.
- Rename, copy, move/select folder khi Android cho phép; xử lý duplicate names/collision/unavailable URI.
- Delete có confirm phù hợp; Undo cho thao tác có thể hoàn tác; MediaStore permissions và user approval native đúng.
- Trash, restore, permanent delete, retention TTL; làm rõ app-owned vs system-managed trash. Không tùy tiện xóa file ở SAF folder.
- Storage dashboard: total used, video/photo/cache/trash sizes, available disk, tình huống 0 space; không báo số giả.
- SAF persistent grants, folder picker, SD card nếu có và Android cho phép; xử lý revoked grants + OEM differences.
- File transfer cơ bản bằng Sharesheet/Export; không xây Wi-Fi transfer/server chỉ để “đủ tính năng” khi chưa có yêu cầu sản phẩm.
- Shortcut mở Edit Video/Edit Photo và deeplink đúng media item; không cần tài khoản hoặc backend.

### P2-F. F48/F49/F50/F51 — Theme, shortcuts, Help, support

- Theme Light/Dark/System và settings persistence; không flash wrong theme lúc start, tránh thay màu media playback surface.
- Localization thật cho ngôn ngữ có resource; fallback đúng, không bịa bản dịch. RTL chỉ khi có ngôn ngữ RTL được bật.
- Settings groups rõ, recording settings UI thuộc P1 contract; editing setting options đến P3; giữ cài đặt khi process death.
- Searchable FAQ/hướng dẫn ngắn, tác vụ chính, permission/capture flow, media management, editor, export errors, troubleshooting.
- Feedback/bug report có category, typed message, optional attachment, privacy/redaction và review before share; khi không có server thì dùng explicit Android Share Intent, không giả gửi thành công.
- Open-source acknowledgements/source register để bộ phận compliance tiếp nhận; không cần tự soạn legal policy.
- Quick shortcuts/native Android integration nếu có lợi thực sự; không thêm shortcuts hỏng khi mất file.

### P2-G. Platform ownership & integration

- **P2 sở hữu duy nhất** `lib/app/`, `lib/features/home/`, phần lớn `lib/features/media/`, `lib/features/settings/`, `lib/core/` và shared UI; xem ngoại lệ ở mục Ownership.
- **P2 sở hữu** `MainActivity.kt`, AndroidManifest, Gradle, pubspec và native bridge registration; P3 muốn plugin/permission/native method thì tạo change request/hợp đồng, không sửa cùng lúc.
- Platform Channels typed argument/result/error, lifetime-safe, register/dispose đúng, không duplicate channel name.
- Ensure native media events P1/P3 cập nhật P2 Library; tránh race giữa saved event, indexing và thumbnail load.
- Integrate privacy/perms only when needed; không prompt quyền toàn bộ ngay launch chỉ vì muốn “hỏi trước”, tuân thủ system consent thực.
- Accessibility scanner + regression suite + crash/perf telemetry **local/opt-in**, không cần analytics server.

---

## 5. P3 — THỰC THI CHI TIẾT: Editing, Rendering, Export & AI

### P3-A. Project/Draft & Editing Studio — F34

- Tạo/open/delete/duplicate draft, đặt tên, recent projects, thumbnail và last modified.
- Typed project model versioning/migrations, persist/save atomic, autosave coalescing, recovery sau background/process death/crash.
- Khi rời khi có unsaved edits phải có Keep editing/Discard/Save draft hoặc tự lưu an toàn; không tạo dialog thừa khi clean.
- Guard duplicate create/open/add media/export, cancel khi picker/repository lỗi, retry không tạo project rác.
- Media source picker P3 dùng P2 `MediaScope`, không copy media scanner riêng.
- Projects tham chiếu URI, permission grant stable; missing source có relink/recovery, không crash editor.

### P3-B. Timeline engine, media composition — F27/F28

- Multi-clip timeline hỗ trợ video và still photos; import/merge/reorder/removal/duplicate.
- Playhead seek accurate, scrub smooth; thumbnails/waveform asynchronous lazy; drag handles có haptic/semantic values.
- Trim start/end; split at playhead; cut/remove segments; undo/redo deterministic; timeline snap/zoom nếu giúp thao tác.
- Normalize orientation/resolution/frame rate/audio khi mix các clip không đồng nhất; báo unsupported thay vì corrupt output.
- Still image duration và transition chỉ khi preview **và rendered output** đồng nhất.
- Project non-destructive; edits lưu thành graph/instructions, không destructive file gốc.
- Determinism: preview/export cùng transform coordinates/time semantics; kiểm sample frames và duration.

### P3-C. Video transforms & layers — F29/F30/F31/F32

- Crop/pan, rotate 90/180/270, arbitrary angle nếu engine hỗ trợ, flip H/V, fit/fill/letterbox, aspect ratios 9:16/16:9/1:1/4:5.
- Speed adjust 0.5x/1x/2x hoặc supported range; audio pitch behavior rõ và consistent.
- Text overlays: font/size/color/stroke/shadow/position, drag/resize/rotate, timing, Vietnamese font rendering.
- Sticker, pen/shape/draw on **saved video** (khác P1 drawing-over-app), opacity/layer order, snapping; animation nếu practical.
- Filters color, brightness/contrast/saturation, preset, background/blur chỉ khi render engine thực sự có.
- Duplicate and reorder clip/layer; keyframes/transitions chỉ triển khai khi có renderer thật và QA đủ.
- Không có “UI chỉ preview được” nhưng export mất hiệu ứng; nếu không hỗ trợ thì disabled giải thích rõ.
- Test portrait/landscape, rotated metadata, high resolution, slow device, very short clips, file with no audio.

### P3-D. Audio hậu kỳ — F19/F33/F40

- Import music/audio từ SAF, choose track, trim/align volume, mute original, mix several tracks, gain limits + clipping protection.
- Fade in/out và mix preview có nghe được, output phản ánh chính xác.
- Voice changer **hậu kỳ**: pitch/robot/echo/reverb presets thực tế nếu DSP support, preview A/B, giữ timestamp.
- Noise reduction **hậu kỳ**: nghiên cứu native RNNoise/other evidence, tránh xóa tiếng nói hoặc phá nhạc; có off switch.
- Không tự sửa P1 mic/internal audio realtime hoặc AudioRecord service. Nếu cần DSP share code thì tạo pure interface request cho P1.
- Kiểm audible sound thật (waveform/metadata không đủ), A/V sync, mono/stereo, no audio track, sample rates khác nhau.

### P3-E. Photo Editor — F39

- Open imported/captured image, preserve EXIF orientation and appropriate color profile.
- Crop freeform/preset ratio, rotate, flip, resize, pen/eraser/color/width, shape/arrows, text/sticker nếu engine hỗ trợ.
- Undo/Redo and dirty exit protection; direct Save copy CTA dễ chạm một tay; no original overwrite.
- Export PNG/JPEG phù hợp transparency/quality; storage and memory safe với ảnh lớn (không decode full size vô hạn).
- Use Flutter UI + native/Dart image library tùy performance; isolate cho CPU-heavy work; dispose `ui.Image`.
- Photo editor thuộc P3 dù có file cũ ở `lib/features/media/photo_tools_screen.dart`.

### P3-F. Video export job system — F35/F36

- Job queue and state transitions Preparing→Rendering→Finalizing→Saved/Failed/Cancelled; unique immutable job snapshot.
- Output MP4, correct codec/container compatible with target Android devices; choose supported resolution/FPS/bitrate, progress thật.
- Crop/rotate/speed/audio/text/filter/transitions trong output trùng preview; reject impossible combinations rõ ràng.
- Cancel during actual rendering, cleanup temp artifacts without damaging originals; finalizing không cho Cancel sai khả năng.
- Retry existing job safely, avoid duplicated output; crash/low-storage recovery, no orphaned MediaStore items.
- Save to MediaStore atomically; emit saved URI event → P2 auto refresh; View/Open/share CTA.
- Watermark của **3HRecorder tự tạo** có thể bật/tắt nếu product needs; không xử lý watermark của ứng dụng khác.
- Không làm entitlement/pro-paywall/tier; tất cả chức năng cốt lõi hoạt động không phụ thuộc thanh toán.
- Validate `ffprobe`/`ffmpeg` (nếu có trong QA env): actual duration, stream codec, dimensions, PTS monotonic, A/V sync, decode frames, audio audible, compare representative frames.

### P3-G. Compression / GIF — F37/F38

- Compression presets: balanced/quality/small-size, resolution/bitrate options, realistic estimate/actual output size; don't claim compressed if file grows unexpectedly without explanation.
- Preserve originals; progress, cancel, retry, invalid formats, low storage.
- GIF: select range/start-end, FPS, dimensions, loop count, palette/quantization; encode *animated* GIF valid, avoid out-of-memory.
- GIF source video short/long, rotated, transparent/colored background, repeated export; benchmark.

### P3-H. AI Subtitles — F41/F42

- First investigate **on-device** `whisper.cpp` + small multilingual model on supported Android; measure Vietnamese/English accuracy and real-device RAM/CPU/time/battery. Do not silently download large model.
- If on-device feasible: model opt-in download/manage/storage/progress/cancel; offline ASR; project subtitles with timestamps; avoid upload.
- If backend needed: implement clean typed `TranscriptionService` with endpoint contract and honest `not configured` state; specify backend auth/consent/retention/quota to external team. Server code only if feasible and explicitly within local app project scope; infrastructure/billing not yours.
- No fake speech-to-text; no simulated subtitles shown as real results. Test silence, no voice, mixed music, Vietnamese accents, long audio, unsupported inputs.
- Subtitle timeline editor: edit content, add/delete/split/merge segments, adjust start/end, style/layout, safe areas/overlap, readable Vietnamese fonts.
- Burn-in subtitles into MP4 with correct timing and design; optional SRT export when time allows and tests pass.
- Protect source privacy, redact logs, use user consent before network upload; never bake tokens/API keys into Flutter app.
- If dependencies unavailable, deliver adapter/test fixtures and mark as BLOCKED, not DONE.

---

## 6. Shared files, integration contracts và tránh xung đột P1

### Ownership hiện tại (xác minh lại trong working tree)

| Khu vực | Owner | Quy tắc |
| --- | --- | --- |
| `lib/features/recording/`, native `recording/` | **P1** | Read-only từ phía bạn |
| `lib/features/settings/recording_settings_form.dart`, `audio_video_settings_screen.dart` | **P1** | Xin contract trước khi đổi |
| `lib/app/`, `lib/features/home/` | **P2** | App composition, UX, shell |
| `lib/features/media/` | **P2** | Trừ `photo_tools_screen.dart` là P3 |
| `lib/features/settings/` | **P2** | Trừ P1 forms và P3 editor settings logic |
| `lib/core/`, shared widgets/design tokens | **P2** | Thay đổi domain model có review contract |
| `lib/features/editor/` | **P3** | Editor/project/export/AI |
| `lib/features/media/photo_tools_screen.dart` | **P3** | Ngoại lệ; có thể move sau PR riêng nếu an toàn |
| Native `android/.../editor/` | **P3** | Mọi native renderer/export |
| Native `android/.../media/` | **P2** | Catalog, preview, actions, URI |
| `MainActivity.kt`, Manifest, pubspec, Gradle | **P2** | P3 thay qua integration request, không cạnh tranh edit |

### Cần khóa xung đột trước khi code song song

1. `lib/core/widgets/studio_create_sheet.dart` nếu còn trộn P2 Create shell/P1 recording UI, chỉ extract một lần có review P1.
2. `lib/core/domain/models.dart`, `repositories.dart`: P2 là contract owner; không rename fields phá P1.
3. `lib/features/settings/settings_controller.dart`: P2 persistence, P1 config semantics.
4. `lib/app/app.dart`: P2 composition; sử dụng callback P1/P3 thay vì gọi native ngầm.
5. `MainActivity.kt`: P2 owner duy nhất; P3 provide method signatures + native implementation.
6. `photo_tools_screen.dart` trong media folder vẫn P3 owner, tránh sửa cùng lúc với P2 Library.

### Contract bắt buộc kiểm chứng bằng test

- `CaptureSaved(uri,type,metadata)` từ **P1** → P2 catalog refresh; không làm P1 đổi event khi chưa hỏi.
- `MediaItem(uri,type,...)` từ **P2** → P3 Editor picker/import.
- `ExportCompleted(uri,mediaType)` từ **P3** → P2 catalog refresh, view/share.
- P2 settings persistence → P3 editor/export preferences qua typed API, không direct import widget.
- P2 content URI grants → P3 native renderer đọc được khi background/resume.
- AI model or API availability → P3 feature state, P2 không cần account/billing integration.
- Error enums, cancellation, pending writes, retries đầy đủ; không swallow exceptions và báo success giả.

---

## 7. Ưu tiên & thứ tự triển khai (không làm tất cả một commit)

### M0 — Audit + baseline + guardrails

- Read docs and current tree, record git status, map done/partial/missing, create feature matrix, issue list and safe tests.
- Inventory P1 untouched paths and shared-file contracts.
- Research/reuse candidate matrix; chọn các POC có lợi ích cao.
- Exit: backlog có thứ tự, scope ownership rõ, baseline tests được ghi nhận. **Sau checkpoint tiếp tục M1.**

### M1 — P2 App-wide HCI/UI/UX redesign

- Priority: Home/Video Library, Photo/Library, Create, Edit shell, Settings, dialog, empty/loading/error states.
- UI layout/palette/tokens, one-hand CTA reach, labels, 48dp targets, haptic/animation, reduced motion, 320/411dp/scale2.
- Keep P1 capture state and P3 editor output untouched, route/lifecycle stable.
- Exit: before/after screenshot comparisons + widget/golden/accessibility tests, user flows shorter or clearer without regressions.

### M2 — P2 Media/Platform reliability

- Media catalog/search/sort/filter/preview/rename/delete/share/trash/restore/SAF/storage/shortcuts.
- Native bridge stability and P1/P3 saved-URI integration; persistence/permission/low-storage error handling.
- Exit: real test media on **dedicated test emulator**, no accidental loss, auto catalog updates, stable 1k-items scrolling.

### M3 — P3 Editor core + photo

- Projects/drafts, media import, timeline trim/split/merge, seek/speed/rotate/crop, Undo/Redo, photo annotation and saved copy.
- Fix preview vs render divergence first; dirty-exit and autosave protection.
- Exit: native editor tests, reopen drafts, process restart, real output matching project.

### M4 — P3 Advanced media + export

- Text/stickers/filter/layers/music/audio mix/voice effects/noise reduction where renderer can actually support them.
- MP4 export queue/cancel/retry, compression/GIF, watermark only if product enables it.
- Real output validation on multiple media fixtures; detailed performance/memory benchmarks.
- Exit: no silent failed export, no zero-byte files, audio sync and media outputs match preview.

### M5 — AI Subtitles integration

- On-device benchmark first; select offline engine or API adapter only with honest constraints.
- Subtitle editing, timing, burn-in export, optional SRT; privacy and errors.
- Exit: realistic multilingual audio tested, or mark external dependency BLOCKED with functional contract instead of fabricated results.

### M6 — Whole-app hardening & delivery

- Re-run full tests, integration flows, stress/perf/accessibility checks; fix crashes/leaks and UX issues.
- Final unsigned release build if possible and debug QA APK; handoff release-ready source, not Play publishing.
- Document unresolved device/OEM/AI dependency gates and P1 coordination requirements.

### Priority logic

P0 = crash/data loss/security/consent/incorrect export/corrupted media; P1 = main task cannot complete or bad one-hand UX; P2 = meaningful polish/features; P3 = optional enhancements. Tackle root causes rather than painting over symptoms.

Do not automatically start M4/M5 if M1–M3 regression is unresolved. Do not rewrite already-DONE functions without a demonstrated issue.

---

## 8. Testing & objective acceptance (not optional)

### Tooling (adapt to installed Flutter SDK/Android env)

- `dart format` changed Dart files and `flutter analyze` clean.
- `flutter test` full suite; targeted widget/unit tests for each feature and regression cases.
- Flutter integration tests on **verified dedicated AVD only**; do not use someone’s personal emulator by accident.
- Kotlin/JUnit Android tests for native modules where practical.
- Debug APK `lib/main.dart`; release build when toolchain allows, no user signing credentials required.
- Media fixtures and `ffprobe`/decode checks for actual MP4/GIF/PNG, not merely return codes.
- UI screenshot tests at 320/411dp, Light/Dark and text200%; Accessibility Scanner/TalkBack if device available.

### Must-pass product scenarios

1. Cold start → Video tab Ready; tap Record routes correctly to P1; no duplicate capture controls introduced.
2. Screenshot saved by P1 → Photo library auto shows new PNG without restarting app.
3. New video saved by P1 → Video library index/thumbnail/playback reliable.
4. 0 items → useful empty state; no fake recent videos; search/filter not obstruct primary task.
5. Browse 1,000 items → stable scroll, responsive search/sort, thumbnails not memory ballooning.
6. Open portrait/landscape/rotated video → correct orientation, seek and duration; missing URI gives recovery.
7. Rename/share/trash/restore → OS permissions valid, no unexpected deletion; remote SAF revoked case.
8. Create editor project → import 2+ clips and photo → trim/split/merge/rotate/speed → save/reopen draft.
9. Add music/text/filter → preview; export MP4; actual frame/audio matches expected transforms.
10. Rapid double tap Create/Export/Save/Share → only one action/job, no duplicate outputs or stacked dialogs.
11. Back with dirty photo/video → preserve edits or explicit discard; clean exit no unnecessary prompt.
12. Export while app background/rotate → correct lifecycle, no false success, clear recovery.
13. Cancel rendering → safe temp cleanup; no orphaned MediaStore files; original intact.
14. Low storage/unsupported codec/corrupt file/permission revoked → actionable error/retry; no crash.
15. Photo annotation/crop → Save Copy → original unchanged, saved photo appears in Photo library.
16. GIF and compressed output → decodable, correct dimensions/duration, quality and size expectations.
17. AI subtitle: if backend/model available → real transcript/edit/burn-in; otherwise explain setup blocked, no fabricated transcript.
18. Keyboard/TalkBack/text scale2/one-hand landscape/portrait → controls reachable and labeled.
19. Background/resume/process kill → settings/drafts persist; no stuck loading or cross-feature state corruption.
20. P1 recording and Facecam/regression harness remain unaffected, verified to the extent test environment allows.

### Performance and quality bar

- Aim for fluid 60Hz interaction on supported hardware; track build/raster p50/p95, jank, time-to-first-preview, editor load, export throughput.
- No business claim like “<3s” or “60fps always” without repeatable measurements; specify device and n.
- Time-consuming decoding/encoding/image processing off UI isolate/thread; avoid network request on render path.
- Caching and disposal must be bounded; no leak on 30× navigation, 20× preview/open/close, repeated export.
- Compare before/after with **same device and fixture**, report regressions candidly; emulator results don't equal physical-device guarantee.
- Profile meaningful hot paths only; do not optimize away needed accessibility or user feedback.

### Data protection

- Never overwrite originals; use atomic writes/MediaStore pending semantics and explicit output URI.
- Avoid exposing file names, PII, video thumbnails or audio in logs/report screenshots without consent.
- No cleanup of any user collection or destructive command. Native smoke on disposable test data and test AVD only.
- External upload requires consent; no background AI upload without user action.

---

## 9. Deliverables, reporting & autonomous execution

For EACH milestone provide:

1. Features touched and status before/after with IDs (e.g. F24, F27).
2. Source files changed and why; explicit proof no unauthorized P1 changes.
3. GitHub repos reused; direct links/commit tags, precise components ported, quality/reliability rationale.
4. Screenshot or evidence before/after for UI changes; real outputs for editor/export.
5. Exact tests run (commands, result), skipped cases and reason, compiler/analyzer status.
6. Benchmark/environment and any regression signals; don't claim tests not run.
7. Known limitations, OS support, blocked dependencies and next milestone.

Maintain these Markdown files:

- `docs/implementation/P2_P3_CURRENT_AUDIT.md` — baseline and feature status.
- `docs/implementation/P2_P3_MASTER_PROGRESS.md` — milestone checklist, current status, blockers, next actions.
- `docs/implementation/REUSE_REGISTER.md` — GitHub provenance, versions, integration and external license review handoff.
- `docs/implementation/P2_P3_CONTRACTS.md` — P1/P2/P3 typed APIs and ownership boundaries.
- `docs/implementation/P2_P3_TEST_EVIDENCE.md` — test commands, devices, actual outputs, performance and remaining gaps.

Use `DONE` only with reproducible source/test evidence. Mark visual-only or stub as `PARTIAL`, external service as `BLOCKED`. Do not inflate percent completion.

### Working style

- **Act, don't just advise:** after audit, implement the highest-priority safe vertical slice, verify it, and continue systematically.
- Work in small, reversible changes; inspect before editing, preserve dirty worktree, prefer apply_patch or normal project tooling.
- Respect AGENTS/local conventions and user's existing design/UX decisions; no gratuitous refactor.
- If clarification is non-blocking, choose the most user-friendly, maintainable default and record assumption.
- Stop and ask only for an actual blocker: inaccessible workspace, protected permission, irreversible destructive operation, missing proprietary credential, backend/paid service choices, incompatible external contract or a decision that materially changes product behavior.
- Do not create GitHub PR, push or publish unless user authorizes. Do not pretend Play Store, billing, ads or legal tasks were completed.
- End each working session with concise Vietnamese summary of **what actually works now**, **what remains**, **what was verified**, and **next actionable task**. If context runs short, continue via progress file rather than starting over.

### Final definition of done

The task is complete only when **every in-scope P2/P3 target feature** is one of:

- **DONE**, with source, UI, native integration, automated tests, real output and UX checks; or
- **BLOCKED/DEFERRED with explicit, verifiable reason and owner of the external dependency** (e.g. AI model/backend not available; hardware not available), not disguised as DONE.

The app must be stable and useful **without** Pro, purchases, advertising or Play publishing. The user can take the working Flutter/Android project and test APK to the deployment/compliance team. UX/human factors and media integrity win over speed, star count, package reuse for its own sake or an impressive list of unchecked features.

**BẮT ĐẦU NGAY: đọc AGENTS/spec/source, ghi baseline, audit, đánh giá GitHub candidates, triển khai P2/P3 theo M0–M6, kiểm thử và cập nhật tiến độ. Không dừng ở phần đề xuất.**
