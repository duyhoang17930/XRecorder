# Task 00 — P1 Ownership & Capture → Media Contract

Ngày kiểm tra: 2026-11-06. Baseline: `5cdda32`.
Trạng thái: **PARTIAL** — đã kiểm tra và lập tài liệu; các quyết định ownership và cancel còn Pending.

## 1. Git và nguồn phân công

- Branch hiện tại: `main`; `git status --short` ban đầu rỗng.
- `git branch -a` chỉ có `main`, `remotes/origin/main`; chưa có `feature/capture-live` trong refs local/remote-tracking. Không fetch nên chưa xác minh refs trực tiếp trên server.
- Không checkout, reset, discard hoặc push. Yêu cầu trực tiếp trong chat cho phép `git add`/commit local sau mỗi đợt thay đổi, thay cho điều khoản không commit trong đề bài đính kèm.
- Không tìm thấy `AGENTS.md`, `CODEOWNERS` hay `3HRecorder_FULL_XRecorder_3_PERSON_WORKPLAN.md` trong danh sách file repository; không thấy AGENTS ở các thư mục cha. `.agents/`, `.codex/`, `.github/` không có file hướng dẫn được tìm thấy.
- Ownership dưới đây lấy từ Task 00 được cung cấp; chưa thay thế xác nhận của P2/P3.
- Sau khi commit và working tree sạch, cách chuyển an toàn: `git switch -c feature/capture-live` nếu vẫn chưa có branch. Nếu đã có local dùng `git switch feature/capture-live`; nếu có remote mới, fetch rồi tạo tracking branch tương ứng. Nếu tree bẩn, commit riêng phần việc đang làm trước. Không tự thực hiện chuyển branch trong Task 00.

## 2. Ownership và shared files

| Phạm vi | Owner / cách phối hợp |
| --- | --- |
| `lib/features/recording/` | P1: service/controller, setup sheet, status presentation |
| `lib/features/settings/recording_settings_form.dart`, `audio_video_settings_screen.dart` | P1; phụ thuộc SettingsController do P2 quản lý |
| `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/` | P1: CaptureBridge, CaptureService, CaptureState, CaptureJournal, CaptureConfig, MediaOutput, VideoEncoder, SessionAudio, RecordingMuxer, FacecamOverlay |
| `lib/app/`, `lib/core/domain/models.dart`, `repositories.dart`, `lib/core/widgets/studio_create_sheet.dart` | P2 theo đề bài; P1 chỉ đọc |
| `lib/features/settings/settings_controller.dart` | P2; P1 không tự sửa persistence/schema |
| Native `MainActivity.kt`, `AndroidManifest.xml`; pubspec/lock và Gradle | P2; bridge registration, permissions, dependencies cần phối hợp |
| `lib/features/media/`, native `media/` | Phía Media Library/P2 theo contract; cần xác nhận chính thức vì thiếu workplan |
| `lib/main.dart`, `lib/core/persistence/settings_store.dart`, native `res/xml/media_paths.xml` | Shared, đề xuất P2 xác nhận ownership; lần này chỉ đọc |
| `test/recording_controller_test.dart`, `test/fixtures/recorder.dart`, `integration_test/recording_*.dart`, tài liệu P1, CODEOWNERS | Chưa có phân công chính thức cho tests/docs; đề xuất P1 phụ trách capture tests/docs, P2 quản lý CODEOWNERS |
| Editor/export/photo tools và model dùng chung | Chưa xác nhận ranh giới P2/P3; không sửa, không suy diễn ownership toàn bộ editor từ tên thư mục |

Rủi ro conflict: settings UI P1 dùng controller P2; capture dựa vào models/repositories, app wiring, native registration và manifest P2. MediaOutput phải khớp đường dẫn/provider và truy vấn catalog. P3 có thể dùng chung MediaOutput/model trong tương lai: cần thống nhất trước khi đổi signature. Xem IR-00-01.

## 3. Contract hiện tại và bằng chứng code

```text
CaptureService → encoder / PNG compress → MediaOutput.commit()
  → CaptureState(outputUri, completed) → EventChannel / current snapshot
  → AndroidRecordingService.decode → CaptureController._receive
  → onSaved() → media.refresh() → Media Library reload/index
```

Điểm kiểm tra chính:

- `recording/CaptureService.kt`: `startEncoder`, `captureImage`, `stopCapture`, `fail`.
- `recording/VideoEncoder.kt`: MediaCodec + MediaMuxer MPEG-4; `RecordingMuxer.kt`: kết hợp track video/audio thật.
- `recording/MediaOutput.kt`: `open`, `commit`, `abort`.
- `recording/CaptureBridge.kt`: command `current/start/screenshot/stop/cancel`, consent và session ID guards.
- `recording/CaptureState.kt`: snapshot, transition, replay khi onListen; `CaptureJournal.kt`: initialize/cleanup.
- `lib/features/recording/recording_service.dart`: decode, `_receive`, refresh, cancelScreenshot.
- Shared chỉ đọc: models/repositories, app/router/create sheet, settings controller/store/main, MainActivity/manifest/media_paths, pubspec/lock và Gradle; MediaCatalog.list và media_repository.refresh.

| Câu hỏi | Kết quả kiểm tra |
| --- | --- |
| MP4 thật? | Có đường ghi MediaCodec/MediaMuxer, kiểm tra duration > 0 bằng MediaMetadataRetriever trước commit; khi có audio yêu cầu HAS_AUDIO. Không có placeholder trong đường production đã đọc. Runtime lần này: **Not Verified**. |
| PNG thật? | ImageReader → bitmap crop → `compress(PNG)` phải trả true, stream flush/close rồi commit. Runtime lần này: **Not Verified**. |
| Commit trước Saved? | API 29+: descriptor size > 0, close, update `IS_PENDING=0` phải trả 1; sau commit mới gán output và transition completed. API 24–28: rename file private và FileProvider URI, không phải MediaStore commit; catalog có nhánh đọc thư mục private tương ứng. |
| Cancel có Saved? | Deny consent/awaitingPermission → idle, không output; countdown chưa started → cleanup/idle. **Lỗ hổng contract:** native gom `stop` và `cancel`, nên cancel ở recording/paused gọi stopCapture và có thể completed + Saved. UI cancelScreenshot chỉ mở ở countdown, nhưng public API không giới hạn tương tự. IR-00-02 Pending. |
| Encoder/save fail có Saved? | Đường exception chuyển failed và abort output; `_receive` chỉ gọi onSaved khi completed + outputUri khác null. Chưa fault-injection native: **Not Verified**. |
| Double callback? | `_savedId` chặn completion lặp liên tiếp của cùng ID trong một controller; native `ending` chặn finalizer lặp. Không phải exactly-once toàn vòng đời: controller mới có thể refresh lại completed snapshot; chuỗi A/B/A cũng không được một `_savedId` bảo vệ. Callback refresh hiện tại có debounce và có thể lặp an toàn; native media observer cũng phát refresh độc lập. |
| Activity recreation? | State singleton/service độc lập Activity, current/onListen trả snapshot; MainActivity đăng ký lại bridge, cleanup bỏ sink. Journal phục hồi process loss thành failed cho session đang busy, không giả tiếp tục consent. Activity recreation thực, consent pending, process kill: **Not Verified** lần này. |
| URI/metadata đủ? | RecordingSession có ID, state, outputUri, configSnapshot, elapsedActive, startedAt, screenshot, error. Native snapshot có kích thước/fps/bitrate; decoder dùng config và chưa chuyển actual width/height thành metadata riêng. VoidCallback không mang payload; catalog truy vấn URI/size/MIME/duration/dimensions từ native nên đủ cho refresh/index hiện tại. Chưa cần mở rộng model. |

## 4. Giới hạn và API đã đủ

- Không phát hiện code production tự tạo fake URI: URI đến từ insert MediaStore hoặc FileProvider. Flutter chỉ kiểm tra URI khác null, `Uri.parse` chưa chứng minh URI đọc được; journal replay completed cũng chưa revalidate file đã bị xóa. Điều này có thể refresh lại catalog nhưng không tạo file giả. Không coi non-null URI là bằng chứng runtime.
- File nonempty và metadata duration/compress thành công là kiểm tra hiện có, chưa đảm bảo decode mọi frame hoặc độ bền qua process death ngay lúc publish. Cửa sổ publish → completed/journal vẫn cần kiểm thử.
- `onSaved: media.refresh` còn tồn tại trong `lib/app/app.dart`. P1 không trực tiếp cập nhật UI Media Library. `media.refresh` phát changes sau debounce 250 ms, hoãn khi background; catalog API 29+ lọc `is_pending=0` và owner_package_name, legacy chỉ nhận đuôi media hợp lệ.
- MainActivity đã register capture MethodChannel/EventChannel và chuyển permission/activity results; Manifest có service mediaProjection/microphone/camera, permissions và FileProvider đúng paths. Routes có settings/audio-video và redirect recording/completed về videos.
- `lib/main.dart` inject AndroidSettingsStore, restore trước runApp; SettingsController serialize bản v2, native write commit trên worker. Không phát hiện cần dependency mới cho contract hiện tại. Các cờ settings chưa truyền hết sang native không được xem là tính năng đã hỗ trợ.
- API hiện tại đủ cho refresh/index. P2 chưa cần sửa models/router/app/Media Library để thêm payload; mở rộng metadata chỉ khi có consumer yêu cầu thực tế.

## 5. Kiểm chứng

- **PASS:** `flutter test --no-pub test/recording_controller_test.dart` — 4 tests: disposed late completion, consent/cancel không fake saved, completed có output và dedupe, stop error giữ state. Tests dùng fixture, không chạy encoder/MediaStore thật.
- **PASS:** `git diff --check` và kiểm tra staged diff cho hai tài liệu trước commit.
- **NOT RUN:** dart format/flutter analyze (không sửa Dart); Android build và full integration suite (ngoài phạm vi audit tài liệu).
- **Not Verified trong phiên này:** runtime MP4/PNG, native fault injection, full Activity recreation/process kill và thiết bị thật. Không thực hiện native integration trong Task 00.
- Bằng chứng lịch sử, không phải test vừa chạy: `docs/xrecorder/phase_3_validation.md` ghi API 36 MP4 125.916156 s, ffprobe/ffmpeg; `phase_6_validation.md` ghi screenshot integration và inspect pixels; `phase_5_validation.md` ghi pause/reconnect/repeated-stop và liệt kê recreation/kill còn thiếu. Chưa tái kiểm tra artifact hoặc áp dụng kết quả lịch sử cho mọi thiết bị/HEAD hiện tại.

## 6. P1 có thể tiếp tục độc lập và bàn giao

P1 có thể chuẩn bị regression cases cancel/fail/duplicate/reconnect trong capture scope, kiểm thử đọc lại MP4/PNG sau commit, và làm rõ native lifecycle mà không đổi public signature. Sửa cancel khi đang quay cần thống nhất semantics trước vì thay đổi hành vi engine; chưa thực hiện trong audit này. Không mở rộng livestream/floating ball/drawing hoặc dependencies trong Task 00.

- [x] Xác định branch, working tree và refs hiện có; giữ nguyên branch.
- [x] Ghi ownership được cung cấp và mọi phạm vi chưa rõ đã nhận diện.
- [x] Trace capture → commit → completed → refresh; ghi fake URI/double callback/cancel/failure risks.
- [x] Tạo integration requests; không sửa file P2/P3 hay Recording Engine.
- [x] Chạy host capture tests và kiểm tra diff; phân biệt code/historical/runtime evidence.
- [ ] P2/P3 xác nhận ownership, branch workflow và tests/docs scope (IR-00-01).
- [ ] P2 thống nhất cancel contract, P1 sửa và verify native (IR-00-02).
- [ ] Native lifecycle/fault-injection còn thiếu được kiểm chứng trước khi tuyên bố contract hoàn tất.

**Task 00: PARTIAL**, không tự đánh dấu DONE khi cancel contract và ownership còn Pending.
