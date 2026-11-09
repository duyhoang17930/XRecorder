# Task 01 — Recording Engine Audit (P1)

Ngày: **2026-11-07**. Branch: `feature/capture-live`; HEAD `4ce6a53` **cộng working tree chưa commit**. Audit source hiện có, không chỉ HEAD hoặc APK đang cài trên thiết bị.

**Task 01: DONE — hoàn thành audit, không có nghĩa Recording Engine đã đạt nghiệm thu runtime.** Chỉ tạo báo cáo này; không sửa source/UI, không format/pub get/build/test lại, không thao tác thiết bị, không checkout/reset/stage/commit/push. Working tree ban đầu có thay đổi từ Task 00, Recording Settings và Floating Controls; giữ nguyên và đối chiếu checksum sau audit.

## 1. Phạm vi và quy tắc bằng chứng

- Đọc trực tiếp 3 file `lib/features/recording/`, form/screen Recording Settings; 12 file native `recording/`; phần contract trong app.dart, models.dart, repositories.dart, SettingsController, MainActivity và Manifest.
- Đọc Recording/Screenshot/Facecam tests, geometry unit tests và báo cáo/artifacts P1 liên quan. Không audit implementation Media Library/Editor, không đọc Stitch hoặc quét toàn source repo.
- Mapping Feature ID lấy từ `docs/TECH_STACK_RESEARCH_VI.md:131–153,192–193`. Đây là danh mục chức năng, không phải bằng chứng app đã dùng RootEncoder: engine thực tế dùng MediaCodec/AudioRecord/MediaMuxer tự triển khai.
- `IMPLEMENTED` đòi hỏi bằng chứng phù hợp cho **source hiện tại**, không suy ra từ widget/mock/capability. `PARTIAL` có phần chức năng nhưng thiếu phần trong định nghĩa feature; `NEEDS_VERIFICATION` có đường code tương đối đầy đủ nhưng thiếu kiểm chứng cần thiết. `MISSING` là không thấy implementation trong phạm vi P1 đã kiểm tra, không tuyên bố không tồn tại trong mọi module khác.
- Với source hiện tại, tất cả feature cần Android runtime bên dưới đều **NOT VERIFIED ON DEVICE**. Có MP4 baseline từ bản trước khi sửa compact controls, chứng minh pipeline đã tạo video thật; không thay thế nghiệm thu bản hiện tại. Hạn chế cài APK/consent là hạn chế kiểm chứng, không tự gán mọi feature thành BLOCKED.

**Tổng 24 feature:** IMPLEMENTED **0** · PARTIAL **7** · MISSING **7** · NEEDS_VERIFICATION **10** · BLOCKED **0**. Số IMPLEMENTED bằng 0 theo cổng bằng chứng nghiêm ngặt trên, không có nghĩa toàn bộ code là mock hoặc chưa làm.

Quy ước đường dẫn bằng chứng: tên `.kt` trong báo cáo thuộc `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/`; `recording_service.dart`, `recording_setup_sheet.dart`, `capture_status_presentation.dart` thuộc `lib/features/recording/`; form và SettingsController thuộc `lib/features/settings/`. Số dòng tính trên working tree lúc audit.

## 2. Current Architecture

### Flutter và native session

- `AndroidRecordingService`, `recording_service.dart:13–175`: MethodChannel **com.xrecorder/capture**, EventChannel **com.xrecorder/capture/events**; một native stream chia sẻ. Lệnh capabilities/current/start/screenshot/pause/resume/stop/cancel truyền config và sessionId; PlatformException ánh xạ sang DomainFailure.io, chưa giữ phân loại lỗi native.
- `CaptureController`, `recording_service.dart:179–215,237–309,312–375,435–476`: subscribe + current snapshot, chống request đồng thời ở Flutter, lifecycle resume refresh. `_feedbackTimer` chỉ phục vụ thông báo, không điều khiển thời lượng quay.
- `CaptureBridge.kt:37–69,80–154`: validate config, busy/session guards, notification/audio/camera/overlay permissions, projection consent, khởi động service. API 34+ dùng `createConfigForDefaultDisplay()` nên **chủ động quay toàn màn hình**, chưa chọn một app. Chỉ giữ consent trong Intent cấp cho service, không journal token; Resume không xin consent mới.
- `CaptureService.kt:89–148`: foreground service trước `getMediaProjection`, register Callback.onStop, tạo một VirtualDisplay video gắn encoder surface. Callback projection bị dừng gọi stopCapture; không tái tạo token/session để tiếp tục giả sau process loss.
- `CaptureState.kt:8–31`: singleton chứa UUID, state/config, output/error, monotonic elapsed; current/onListen replay snapshot. `transition(String)` không kiểm tra một bảng chuyển trạng thái hợp lệ; tính an toàn hiện phụ thuộc guards của bridge/service.

Luồng trạng thái đang dùng:

```text
idle/completed/failed → awaitingPermission → countdown? → starting → recording
recording ↔ paused → stopping → finalizing → completed hoặc failed
permission denied/cancel sớm → idle; lỗi chuẩn bị/encoder → failed
screenshot: awaitingPermission → countdown(3s) → starting → finalizing → completed/failed
```

`preparing` có trong Dart enum (`lib/core/domain/models.dart:104`) nhưng không thấy native transition tương ứng. Cancel ở active capture đi `cancelCapture()` và abort/idle; cancel khi finalizer đã nhận output trả `too_late`. Terminal cancel là no-op. Double stop có `ending`; double start có busy guards cả Flutter/native.

### Video, audio và output

- `VideoEncoder.kt:18–58,68–120`: encoder theo tên từ capability; Surface input → MediaMuxer MP4, first-frame callback mới đánh dấu recording. Pause dùng PARAMETER_KEY_SUSPEND, giữ pause ranges System.nanoTime để trừ PTS; Resume yêu cầu sync frame. EOS có duration của phần đuôi tĩnh; chặn PTS lùi, timeout finish/join.
- `SessionAudio.kt:17–45,50–69,93–155`: PCM16 **mono 48kHz**, mic/internal/mixed; AAC-LC mono 128kbps vào file tạm. Internal dùng AudioPlaybackCapture API 29+, lọc MEDIA/GAME/UNKNOWN. Gain độc lập, cộng mẫu rồi clamp; paused vẫn đọc input nhưng bỏ mẫu, không tăng sample PTS.
- `RecordingMuxer.kt:13–58`: extract video/audio tạm, bù offset startTimeNs, interleave track theo PTS, bỏ mẫu ngoài video duration, kiểm tra hai track không rỗng. Chưa có đo A/V drift hoặc đối chiếu waveform.
- `CaptureService.kt:283–320`: Stop dừng capture, finish encoder/audio, mux nếu có audio, kiểm tra metadata duration >0 và HAS_AUDIO khi cần, rồi commit. Không kiểm tra decode tất cả frame hoặc độ bền qua crash sau publish.
- `MediaOutput.kt:18–65`: API 29+ insert pending, mở descriptor, kiểm tra size >0, đóng descriptor, publish IS_PENDING=0 phải update đúng 1 row. Legacy dùng `.pending` trong private media directory, rename rồi FileProvider URI. Abort không xóa output đã committed.
- `CaptureJournal.kt:14–60`: lưu snapshot và pending URI. Process loss lúc busy → cleanup partial → failed, yêu cầu phiên/consent mới. **Đây là cleanup journal, không phải remux/repair MP4.**

### Background, utilities và UI boundary

- Service/tick 250ms và CaptureState sở hữu timer; Activity recreation không tự tạo encoder mới. MainActivity `:34–39,81–87,105–114` register/unregister bridge/events và forward results. Chưa thực hiện Activity recreation/process-kill test trong audit.
- `FloatingRecordingControls.kt:41–102,106–165`: window WRAP_CONTENT, không FLAG_SECURE, chỉ view thường; compact/timer/buttons/bubble/drag. `CaptureService.kt:35–36,65–74,226–264`: notification mặc định; opt-in **Show controls in video** theo session, không hứa overlay biến mất khỏi output. Một window thuộc service, không timer/recorder thứ hai.
- `FacecamOverlay.kt:27–73`: Camera2 front-only, TextureView 110×147dp ở vị trí cố định, NOT_TOUCHABLE; camera preview được whole-display projection ghi cùng màn hình. Rotate/mirror texture, cleanup camera thread; không có drag/resize/switch/effects.
- Recording Setup hiện fixed header/Basic–Advanced/scroll content/fixed Start (`recording_setup_sheet.dart:23–131`). Advanced Auto-stop bind `durationSeconds`, preset 300/600/1800/3600s và bảo toàn custom value (`recording_settings_form.dart:260–293`). Screenshot action riêng, không sửa UI trong audit.

## 3. Feature Audit Matrix

Priority là thứ tự ưu tiên kỹ thuật (High/Medium/Low), không phải owner P1/P2.

| Feature ID | Feature | Status | Evidence file/line | Issue | Priority |
|---|---|---|---|---|---|
| F01 | Quay toàn màn hình | NEEDS_VERIFICATION | CaptureBridge.kt:106–146; CaptureService.kt:89–148,277–320; integration_test/recording_mvp_test.dart:25–84 | Pipeline thật, có baseline MP4 thiết bị; build hiện tại chưa được nghiệm thu Start/Stop/consent/metadata trên máy. | High |
| F02 | Chỉ quay một ứng dụng | MISSING | CaptureBridge.kt:109; CaptureService.kt:145–146,348 | API 34+ ép default display; không có app picker/onCapturedContentResize hoặc mode app-only trong config. | Medium |
| F03 | Quay một khu vực | MISSING | CaptureConfig.kt:9–21; CaptureService.kt:145–146,153–178 | Không có tọa độ vùng/crop video. Crop bitmap PNG chỉ loại row padding, không phải Region Recording. | Low |
| F04 | Mute/Mic/Internal/Mixed | NEEDS_VERIFICATION | SessionAudio.kt:17–45,93–116; CaptureBridge.kt:80–83; integration_test/recording_configuration_test.dart:25–62 | Cả bốn đường code tồn tại; API 29 gate internal/mixed. Protected playback có thể silent, không bypass. Chưa kiểm âm lượng/A-V sync/runtime đủ bốn nguồn. | High |
| F05 | Gain độc lập, mono/stereo | PARTIAL | SessionAudio.kt:17–18,65–67,113–116; recording_service.dart:147–148 | Gain riêng đã bind; chỉ mono hard-coded, chưa có stereo/channel config; có clipping khi cộng nguồn lớn. | Medium |
| F06 | Pause/Resume cùng phiên | NEEDS_VERIFICATION | CaptureService.kt:238–246; VideoEncoder.kt:32–43,77–94; integration_test/recording_controls_test.dart:28–47 | Guard/timer/PTS có code; geometry tests không chứng minh MediaCodec suspend, AAC trim hoặc sync trên OEM. | High |
| F07 | Auto-stop | NEEDS_VERIFICATION | CaptureService.kt:46–56; CaptureConfig.kt:59–60; SettingsController:205–207; form:260–293 | Native active-time limit 0–86400s, Off=null/0; không Flutter timer giả. Chưa đo stop/save thực với preset/paused/background. | High |
| F08 | Countdown | NEEDS_VERIFICATION | CaptureService.kt:108–121; CaptureBridge.kt:45; recording_service.dart:410–417 | Native countdown, screenshot cố định 3s; cancel có đường cleanup. Runtime thời điểm bắt đầu/countdown cancel chưa verify lại. | Medium |
| F09 | Auto/Portrait/Landscape | PARTIAL | CaptureConfig.kt:37–41; CaptureService.kt:145–146,348; FacecamOverlay.kt:75–83 | Chọn dimensions lúc start; không resize/rotate video display trên thay đổi orientation. Baseline có letterbox, không được coi là redaction overlay. | Medium |
| F10 | Resolution/FPS/bitrate/2K/4K, codec | NEEDS_VERIFICATION | CaptureConfig.kt:23–50,63–69; VideoEncoder.kt:46–52; form:30–51 | AVC/HEVC và tuple validation có thật; không bảo đảm encoder phần cứng, FPS thực hoặc 4K mọi máy. HEVC UI chỉ biết capability global. Chưa matrix metadata/decode/thermal. | High |
| F11 | Normal/Performance | NEEDS_VERIFICATION | CaptureConfig.kt:29–36,49; form:60–78 | Performance thực sự clamp 720p/≤30fps/≤8Mbps; thiếu đo lợi ích/perf/thermal thực tế, không chỉ nhãn nhưng chưa nghiệm thu. | Medium |
| F12 | Bóng nổi kéo/thả và cấu hình | PARTIAL | FloatingRecordingControls.kt:41–78,106–165; CaptureService.kt:65–74,226–264 | Có drag/snap/bubble compact, chưa cấu hình size/opacity/persist vị trí; output sau bỏ secure chưa verify. | High |
| F13 | Gán nút/thu nhỏ/ẩn bóng-kết quả | PARTIAL | FloatingRecordingControls.kt:52–56,90–102; CaptureService.kt:65–74; recording_service.dart:378–393 | Collapse/expand, notification hide và dismiss feedback có code; chưa gán nút/hành vi kết quả theo cấu hình. | Low |
| F14 | Notification pause/stop/công cụ | PARTIAL | CaptureService.kt:76–85,210–236 | Pause/Resume/Stop và show/hide overlay có code; chưa nhóm công cụ tùy biến và runtime permission/notification actions mới chưa verify. Có bug stale STOP (A01). | High |
| F15 | Drawing: bút/tẩy/hình/undo | MISSING | CaptureService.kt:26–45,248–264; CaptureConfig.kt:9–21 | Không có drawing overlay/canvas/tool state trong P1; không tính photo/editor drawing là realtime recording. | Low |
| F16 | Screenshot PNG/3s delay | NEEDS_VERIFICATION | CaptureBridge.kt:45,149–151; CaptureService.kt:151–201; integration_test/screenshot_native_test.dart:78–129 | ImageReader→PNG thật, compress/flush/commit, timeout/one-shot cleanup. Test pixel/delay có sẵn nhưng chưa chạy trên build hiện tại. | High |
| F17 | Facecam kéo/resize/đổi camera | PARTIAL | FacecamOverlay.kt:27–73,75–93; integration_test/facecam_test.dart:12–35 | Front preview/capture có code; fixed size/position, NOT_TOUCHABLE, không đổi camera. Test hiện có chỉ metadata, chưa chứng minh pixels Facecam. | Medium |
| F18 | Hiệu ứng Facecam | MISSING | FacecamOverlay.kt:47–51,75–83; CaptureConfig.kt:9–21 | Camera AUTO + transform/mirror không phải preset ánh sáng/contrast/filter effects. | Low |
| F20 | Noise reduction realtime | NEEDS_VERIFICATION | SessionAudio.kt:35–38; CaptureConfig.kt:57–58,65; form:185–195 | NoiseSuppressor device effect; factory có thể null mà không báo (A04). Chưa đo chất lượng hoặc xác nhận effect thực sự active. | Medium |
| F21 | Giảm tiếng game khi nói | MISSING | SessionAudio.kt:93–116 | Chỉ gain tĩnh + cộng/clamp, không voice detector/envelope/ducking realtime. | Low |
| F22 | Lắc để dừng | MISSING | SettingsController:189,237; recording_service.dart:140–155; CaptureConfig.kt:9–21 | Flag có trong settings/model nhưng adapter không gửi, native không SensorManager/threshold/debounce. | Low |
| F23 | Hiển thị cảm ứng / hướng dẫn hệ thống | NEEDS_VERIFICATION | form:220–237; SettingsController:239; recording_service.dart:140–155 | Hướng dẫn Show taps còn ở full Audio & Video form, Advanced đã ẩn theo task trước. Không tự bật system setting/quan sát touch app khác. Chưa verify flow hướng dẫn; flag không đến native. | Low |
| F52 | Giảm nguy cơ hệ thống dừng | PARTIAL | CaptureService.kt:89–110,327–348; CaptureJournal.kt:14–60 | FGS + journal/fail cleanup; START_NOT_STICKY, không phục hồi phiên đang quay. Chưa có battery/OEM survival/recreation/kill evidence đủ. Không bảo đảm tránh mọi OS kill. | High |
| F53 | Tự sửa video hỏng | MISSING | CaptureJournal.kt:29–33,43–60; RecordingMuxer.kt:13–58 | Journal xóa partial và failed; muxer chỉ ghép tracks hợp lệ sau stop, không sửa thiếu moov/truncated MP4. RecoveryCache flag chưa tạo repair engine. | Medium |

Livestream RTMP/YouTube **deferred**, không có transport/stream session trong các file P1 đã đọc; không triển khai hoặc đưa vào 24 ID trên. F19 (voice effects) không nằm trong danh sách yêu cầu Task 01 nên không thêm vào tổng.

## 4. Bug/Risk List

“Xác nhận từ code” nghĩa control flow/exception path nhìn thấy trực tiếp; không đồng nghĩa đã tái hiện trên thiết bị. Chưa phát hiện bằng chứng lỗi MediaStore đang phát Saved trước commit ở luồng bình thường.

### A01 — Stale notification STOP có thể dừng phiên mới đang chuẩn bị

- **High · xác nhận control-flow; NOT VERIFIED ON DEVICE.** `CaptureService.kt:82–88,343–346`.
- Điều kiện: intent STOP có sessionId A đến khi session B đã countdown/starting và `started=false`. ID không khớp nên rơi vào `else if (!started) stopSelf()`, thay vì bỏ qua stale command. onDestroy có thể chuyển phiên B busy sang failed; khi đang recording (`started=true`) nhánh này không xảy ra.
- Hướng tối thiểu: reject/no-op stale STOP trước mọi side effect; chỉ xử lý shutdown service không có phiên riêng biệt. Thêm native regression cho queued stale STOP ở countdown/starting, không đổi UI/signature. `recording_cancel_test.dart:53–57` chỉ kiểm stale **cancel qua bridge**, không che phủ nhánh notification STOP này.

### A02 — Cleanup khởi tạo encoder chưa bao phủ partial allocation

- **High · xác nhận exception path; chưa fault-injection.** `VideoEncoder.kt:18–20,44–58,105–109`; `CaptureService.kt:142–149,334–341`.
- MediaCodec được tạo trước constructor MediaMuxer; nếu tạo muxer throw, chưa vào try của init để release codec. Nếu createInputSurface thành công rồi codec.start throw, catch release codec/muxer nhưng không release Surface; worker chưa được tạo nên finally drain không chạy. Assignment `video = VideoEncoder(...)` chưa hoàn tất nên service không có instance để abort.
- Hướng tối thiểu: quản lý allocation trong try/finally của factory/constructor và release từng resource đã cấp, giữ pipeline/signature. Thêm lỗi giả lập đúng điểm mở muxer/start codec và kiểm số handle/surface sau lặp lỗi.

### A03 — Snapshot/command acknowledgement cũ có thể ghi đè trạng thái mới ở Flutter

- **Medium–High · race có đường code, chưa tái hiện runtime.** `recording_service.dart:237–251,305–309,319,337`; `CaptureState.kt:24–30`.
- currentSession/start result có thể hoàn tất sau event mới và `_receive` vẫn gán `session=value`. Chỉ có guard chống resurrect screenshot đã completed cùng ID; không có sequence/version guard tổng quát cho video hoặc old session. Có thể UI lùi về awaitingPermission/old terminal, busy/control feedback sai tạm thời. Native busy guard vẫn chống double recorder.
- Hướng tối thiểu: test interleaving current/event/ack trước, rồi xử lý thứ tự tại controller hoặc đề xuất sequence nếu thật sự cần shared API; không thêm sequence/model khi chưa chứng minh cần.

### A04 — Noise suppression có thể downgrade âm thầm

- **Medium · xác nhận null path, chưa xác nhận trên thiết bị.** `SessionAudio.kt:35–38`; `CaptureConfig.kt:57–58`.
- isAvailable=true không buộc `NoiseSuppressor.create` trả effect; nullable safe-call cho phép tiếp tục khi null. State/config vẫn noiseReduction=true dù không có effect instance.
- Hướng tối thiểu: kiểm allocation/enabled outcome, trả lỗi hoặc fallback có thông báo trạng thái đúng bằng contract hiện có; thử effect resource contention. Không đánh dấu đã giảm ồn chỉ vì switch đang On.

### A05 — PTS timebase và mixed PCM cần kiểm chứng thay vì suy từ timer

- **High · rủi ro có điều kiện, chưa phải lỗi output đã xác nhận.** `VideoEncoder.kt:32–43,77–94`; `SessionAudio.kt:95–116`; `RecordingMuxer.kt:35–54`.
- Video có fallback sourceStartNs nếu encoder PTS lệch monotonic >60s, nhưng phép trừ pauseRanges vẫn dùng raw encoder PTS so với System.nanoTime. OEM dùng timebase khác có thể không trừ pause đúng. Mixed lấy min(micCount,internalCount), không giữ phần dư khi hai read trả số mẫu khác nhau; code chắc chắn bỏ phần dư nếu điều kiện này xảy ra, tác động drift cần đo.
- Hướng tối thiểu: test timestamp/audio waveform trên nhiều audio modes, partial reads, pause nhiều lần, Stop lúc paused. Chỉ chuẩn hóa clock/giữ buffer dư sau khi có fixture tái hiện; không đổi encoder theo suy đoán.

### A06 — Cleanup/journal chưa bảo đảm phục hồi mọi partial

- **Medium · xác nhận phạm vi cleanup; khả năng tồn dư cần fault-injection.** `CaptureService.kt:322–325`; `MediaOutput.kt:59–65`; `CaptureJournal.kt:40–60`.
- abort/delete lỗi có thể bị nuốt hoặc delete count không được kiểm; cleanupPartial ghi error rồi transition sau đó có thể thay thông điệp này. Legacy process recovery chỉ lọc Recording_*.mp4.pending, không xử lý Screenshot_*.png.pending. save/cleared không kiểm kết quả prefs.commit. Không có MP4 repair.
- Hướng tối thiểu: kiểm kết quả delete/journal, giữ diagnostics cleanup, bổ sung recovery PNG pending legacy đúng scope. Không xóa media đã publish hoặc quét/xóa file không thuộc capture.

### A07 — Bằng chứng vùng đen là baseline cũ, không phải xác nhận bản sửa đã sạch

- **High · lỗi cũ đã có artifact; bản hiện tại chưa verify.** `docs/p1/FLOATING_CONTROLS_COMPACT_OUTPUT.md:7–41`; `build/verification/p1/compact-controls/before-analysis.json`; `FloatingRecordingControls.kt:41–45`; `CaptureService.kt:35–36,65–74`.
- Baseline 720×1280/5.853s có rectangle 277×157px nội vùng, khác letterbox mép. Code mới đã bỏ secure, dùng notification mặc định và explicit recorded-overlay opt-in. Lần cài bản mới bị INSTALL_FAILED_USER_RESTRICTED; chưa có MP4 after để kết luận hết redaction. Không gán lại lỗi này cho encoder chỉ vì có dải đen mép.
- Hướng tối thiểu: thực hiện A–E như báo cáo output khi thiết bị cho phép; giữ fallback notification, không crop/đổi resolution để che lỗi. Không cần sửa UI trong audit.

### A08 — Dedupe/URI validation không phải exactly-once toàn vòng đời

- **Low–Medium · giới hạn xác nhận từ code, chưa có bằng chứng file bị nhân đôi.** `recording_service.dart:70–72,196,260–264`; `CaptureJournal.kt:25`.
- `_savedId` chỉ nhớ ID cuối: A/B/A có thể refresh lại A; controller mới refresh completed snapshot cũng gọi onSaved lại (không feedback mới nếu snapshot đầu). URI khác null/Uri.parse không xác minh đọc được, scheme rỗng hoặc file còn tồn tại khi journal replay.
- Hướng tối thiểu: giữ refresh idempotent; thêm replay/interleaving tests. Validate URI/session ở P1 khi cần; không chuyển việc chữa event Capture sang Media Library hoặc thêm payload vô cớ.

### A09 — Capability/config không đồng nghĩa tính năng thực đã bật

- **Medium · khoảng trống code xác nhận.** `SettingsController:235–240`; `recording_service.dart:140–155`; `CaptureConfig.kt:23–25,45,63–69`; form `:43–46`.
- constantFrameRate/hardwareEncoding/shakeToStop/allowScreenOff/showTouches/recoveryCache nằm trong shared RecordingSettings nhưng không được adapter start gửi sang native. Native chọn encoder hỗ trợ tuple đầu tiên, không lọc hardware; HEVC capability global chưa mô tả tuple. Không coi các cờ đã persist là implementation feature.
- Hướng tối thiểu: ghi capability support thực và test tuple tại preflight; nối từng feature trong task riêng nếu đã được yêu cầu. Giữ native reject unsupported; chưa mở rộng shared schema trong audit.

### A10 — Permission/result lifecycle cần native recreation tests

- **Medium · rủi ro có điều kiện.** `CaptureBridge.kt:22,112–153`; `MainActivity.kt:81–87,105–114`.
- requestedSession được tái tạo từ singleton awaitingPermission, nhưng result Android không mang sessionId của request ban đầu. Cancel A rồi tạo B trước khi result A về có thể làm result cũ được xem là của B; kiểm tra hiện tại chỉ so với ID đang pending. Overlay/camera result có guard không đồng đều. Chưa tái hiện tình huống này hoặc recreation lúc mở Settings/consent.
- Hướng tối thiểu: kiểm thử queued result + cancel/new request/recreation, rồi phân biệt request generation trong P1 nếu cần. MainActivity đã forward result; không tạo request P2 đăng ký lại bridge.

## 5. Capture → Media Contract

```text
encoder.finish / PNG compress+flush
  → MediaOutput.commit thành công
  → CaptureState.output + transition(completed)
  → EventChannel/current → AndroidRecordingService.decode
  → CaptureController._receive → onSaved() → media.refresh()
```

`lib/app/app.dart:39–41` có đúng `CaptureController(AndroidRecordingService(), onSaved: media.refresh)`.

| Câu hỏi | Kết luận audit |
|---|---|
| Saved phát lúc nào? | Native completed sau commit (`CaptureService.kt:185,193–194,310–315`); Flutter đòi completed + non-null URI (`recording_service.dart:260–264`). |
| File đã commit? | Luồng bình thường có size/metadata gates và publish kiểm update=1; legacy rename/provider. Không thấy fake URI/mock success trong production. Metadata >0 không thay thế decode integrity hoặc crash durability. |
| Cancel có Saved? | Accepted cancel trước finalizer abort/idle; awaitingPermission idle. Finalizer đã nhận thì trả too_late, **không báo cancel thành công**; stop/shot trước đó vẫn có thể completed. Không cần đổi shared signature. |
| Failure có Saved? | Encoder/save exceptions đi failed + cleanup; Flutter không Saved cho failed/idle kể cả có URI trong fixture. Nếu cleanup gặp lỗi, xem A06. |
| Callback trùng? | Native ending và Dart _savedId chặn các lần lặp thông thường, không exactly-once mọi replay/interleaving. Xem A03/A08. Không có bằng chứng duplicate file do callback refresh. |
| URI hợp lệ? | Native lấy từ resolver.insert/FileProvider, không tự dựng URI thành công. Decoder không xác minh scheme/readability; journal completed có thể trỏ file đã xóa. |
| UI báo success sớm? | Feedback Saved chỉ trong nhánh completed+URI; native Toast sau commit. capture_status_presentation.dart:84 hiển thị completed theo state, không tự probe file. Không thấy đường normal báo Saved ở finalizing; vẫn cần test snapshot/ack race. |

## 6. Integration Requests / Dependencies P2

**Một request tài liệu shared còn hợp lý, không có blocker runtime mới từ P2:**

- **IR-01-01 — `lib/core/domain/repositories.dart:19–20`:** thêm comment semantics `stop`=finalize/save; `cancel`=abort trước finalizer; terminal no-op, stale ID từ chối, too_late là cancel không được chấp nhận và có thể tiếp tục nhận completed. Bằng chứng: public declarations chưa có mô tả, implementation `CaptureBridge.kt:60–69`, `CaptureService.kt:268–320`. Nghiệm thu: comment khớp hành vi, giữ signature/models/UI. Đây là cập nhật nội dung cùng nhu cầu IR-00-02, không tạo request duplicate hoặc sửa interface trong audit.

| Phần shared | Đã có / yêu cầu |
|---|---|
| MainActivity | Journal initialize + channels/events/results + teardown đã có `:34–39,81–87,105–114`; **không yêu cầu sửa**. |
| Manifest | FGS/mediaProjection/mic/camera/notifications/overlay/service/provider đã khai báo `:3–10,21–27`; **không yêu cầu thêm permission/service**. |
| Settings persistence | SettingsController serialize/restore duration, gains, mode, flags; `:159–161,194–247`. Không thấy thiếu schema cho Auto-stop/capture config hiện tại; **không yêu cầu đổi persistence**. Không audit lại toàn bộ store/injection ngoài scope. |
| Shared models | Có RecordingSession/Settings/Capabilities, `lib/core/domain/models.dart:53–164`; **không cần payload/state mới** cho refresh contract hiện tại. Các flag chưa native hỗ trợ là việc implementation P1, không phải lý do bắt P2 sửa model. |
| Capture → Media | app.dart có onSaved wiring; **không yêu cầu Media Library sửa để chữa Capture**. Catalog internals không audit lại trong task này. |
| Dependencies | Code hiện dùng Android SDK và lớp có sẵn, build debug task trước đã thành công; **không phát hiện nhu cầu dependency mới**. Không đọc/đổi Gradle/pubspec hoặc cài package trong audit. |

Owner/workplan chi tiết chưa có ngoài danh mục feature; không sửa CODEOWNERS/AGENTS hoặc đề xuất di chuyển kiến trúc. App-only capture/stereo/effects/RTMP tương lai chỉ lập integration cụ thể khi có task/consumer, không tạo yêu cầu giả định bây giờ.

## 7. Test Evidence và độ tin cậy

### Đã đọc, không chạy lại trong audit

- `test/recording_controller_test.dart:18–116`: 6 fixture tests (late dispose, permission/cancel, Saved gate/dedupe, stop failure, failed/idle with URI, completed replay). Phiên trước PASS, không phải bằng chứng encoder/MediaStore thật.
- `test/recording_setup_sheet_test.dart`: 320/360/411dp, audio display matrix, Auto-stop Off/On/presets/custom/state/Start; phiên trước 3 tests PASS. Chỉ UI/binding, không chứng minh native auto-stop.
- `test/recorder_ui_test.dart:30,94`, `test/screenshot_ux_test.dart:152–395`: state presentation, shared event subscription, feedback/replay/dispose/cancel; mock/fixture boundaries rõ.
- Geometry JUnit XML hiện có `build/app/test-results/testDebugUnitTest/TEST-com.xrecorder.xrecorder.recording.FloatingControlGeometryTest.xml`: **3 tests, 0 failures/errors**, timestamp 2026-11-07T14:27:11.840Z (21:27 giờ Việt Nam), chạy **trước** Task 01. Không chứng minh Android window hoặc native audio/video suspend.
- Native suites đã đọc: `recording_mvp_test.dart`, `recording_configuration_test.dart`, `recording_controls_test.dart`, `recording_cancel_test.dart`, `screenshot_test.dart`, các phần capture/pixel/delay của `screenshot_native_test.dart`, `facecam_test.dart`, `floating_controls_test.dart`, `floating_output_test.dart`. Có test không đồng nghĩa đã chạy PASS.
- `facecam_test.dart:29–34` kiểm config/duration, chưa pixel validation camera. Screenshot native test hard-code 1080×2400 (`:99`), không portable mọi thiết bị. recording_cancel dùng mute và catalog diff, chưa chứng minh mọi pending/cache đã xóa hoặc cancel audio path; chưa test stale notification STOP. Reconnect bằng service instance khác không phải recreate Activity/process kill.

### Artifact runtime cũ và giới hạn

- `docs/p1/FLOATING_CONTROLS_COMPACT_OUTPUT.md` + `build/verification/p1/compact-controls/before-analysis.json` ghi baseline MP4/frame thật có vùng đen trước sửa. Bài baseline bị ngắt, sample ngắn hơn 10–15s; **không tính PASS full suite**.
- Phiên trước compile/debug build/analyze PASS, nhưng after-build install bị Android từ chối. Người dùng đã chọn chỉ code/host checks. Task 01 không cài app, không xin lại consent, không tác động thiết bị hoặc video.
- Không suy rộng kết quả historical từ phase report cũ sang working tree hiện tại; không dùng artifact thuộc P2/P3 để đánh dấu P1 đã xong.

**Phiên Task 01:** `git status/branch`, đọc code/test/report và checksum **PASS**; `git diff --check` **PASS**. **NOT RUN:** unit/widget/native tests mới, analyze/build/format/pub get, full suite, release build. Không có PASS runtime mới hoặc FAIL sản phẩm mới được tuyên bố trong audit.

**Đánh giá ổn định:** nền tảng prototype có pipeline thật và gates lưu file hợp lý; chưa đủ bằng chứng để coi ổn định phát hành. Hai exception/control-flow issue High (A01/A02), race/sync chưa thử, lifecycle/kill/output-after chưa nghiệm thu và nhiều feature còn thiếu là các khoảng trống chính. Chưa có crash/leak rate hoặc device matrix để đưa ra phần trăm độ tin cậy.

## 8. Recommended Next Tasks — 5 việc ưu tiên

1. **Task tiếp theo: sửa A01 trong native notification STOP**, kèm regression stale/duplicate command ở awaiting/countdown/starting/recording/paused/finalizing. Giữ UI và channel signatures. Xác nhận stale ID không dừng phiên khác trước khi mở rộng controls.
2. **Đóng partial-allocation/resource gaps A02/A06:** factory/constructor cleanup đúng scope, error propagation rõ; fault-injection muxer/codec/surface/delete/journal và kiểm lặp lỗi không tăng resource. Không đổi pipeline đang ghi tốt hoặc xóa file người dùng.
3. **Nghiệm thu native current build trên thiết bị khi được phép:** full-screen consent/deny, Stop thật, Cancel, background/Activity recreation, compact controls A–E và decode frames before/after; xác nhận Saved chỉ sau publish. Giữ notification fallback cho output sạch, chưa bật overlay mặc định.
4. **Kiểm chứng/fix tối thiểu clock/PTS/A-V ở A05:** mute/mic/internal/mixed, partial reads, pause 3s/5s/nhiều lần, Stop lúc paused, protected audio và FPS/metadata thực; chỉ sửa clock/buffer khi có trace tái hiện.
5. **Khóa race và support truthfulness A03/A04/A09/A10:** host interleaving snapshot/event/ack + native queued consent/recreation, effect allocation failure, tuple capability và cờ unsupported. Sau đó mới ưu tiên các feature MISSING/nhánh Facecam mở rộng; RTMP/YouTube tiếp tục deferred.

Mỗi task sau cần phạm vi riêng; không kèm redesign, refactor shared hoặc dependency mới mặc định. Audit này không thực hiện bất kỳ sửa chữa nào ở trên.
