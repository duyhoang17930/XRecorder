# Post-pull — Audit tích hợp P1/P2/P3, chỉ đọc

Ngày 09/11/2026. HEAD **`9afcb124069d905dd4b285c890ca0709f5548b68`**, branch **main**. Đây là audit source + host validation; không capture, install/reinstall, instrumentation hoặc thay đổi P1.

## Kết luận chính

- **TASK08: PARTIAL** — dữ liệu backup/known inputs đã được đối chiếu lại; QA5560 grants/draft usability/full recovery chưa chứng minh. Xem [data recovery final status](TASK_08_DATA_RECOVERY_FINAL_STATUS.md).
- **P1: PARTIAL** — basic native capture và saved contract có implementation; có kết quả thiết bị lịch sử, nhưng source mới có lỗi Settings/capability và nhiều API/helper chưa được tích hợp/kiểm runtime.
- **P2/P3 compatibility: PARTIAL** — bridge/URI/schema chính còn tương thích theo source và nhiều host tests; không phải PASS toàn bộ, bộ Flutter hiện có 5 test lỗi.
- **TASK09 có thể bắt đầu:** Có, cho QA độc lập, xử lý các finding và media hợp lệ trên môi trường riêng khi được giao task; giữ các gate mở. Không xem audit này là nghiệm thu app.
- **TASK10 full native end-to-end integration:** Chưa sẵn sàng. Cần đóng ít nhất R1/R2, phối hợp P1 về phần còn thiếu và build/verify mới từ HEAD sau sửa. Có thể chuẩn bị fixture/case cho basic capture→Library→Editor→Export; không chạy capture trong audit này.

## Git và provenance

| Mục | Trạng thái lúc bắt đầu |
|---|---|
|Branch / HEAD|main / `9afcb124069d905dd4b285c890ca0709f5548b68`|
|Local tracking refs|origin/main và origin/HEAD trỏ cùng HEAD; không fetch hoặc ghi remote|
|Working tree / index|Sạch; unstaged, staged và untracked đều rỗng|
|Unmerged / conflict markers|`git ls-files -u` rỗng; không có unresolved Git conflict trong index|
|TASK08 verified checkpoint|`bad1dc305f10bb4679888bff9271c4b007c85ccc` + SHA working changes trong `m6_source_integrity_v2.json`|
|Bảo toàn checkpoint|29/29 file đã sửa ở checkpoint khớp SHA hiện tại; không bị pull ghi mất|
|New tree delta|510 file so với commit bad1dc3, gồm rất nhiều P1 test evidence; 26 production files thuộc recording/P1 settings có delta|
|P1 protected snapshot cũ|12/18 file đổi bởi code nhóm đã commit, 6/18 giữ nguyên; không lấy proof “18 exact” cũ áp cho HEAD mới|

[Git/evidence snapshot](../../build/verification/task08/followup_20261109T063823024767Z/) chứa branch/head/status, full staged/unstaged diffs, untracked/unmerged, range commits/name-status/diff và SHA của 1.075 tracked files trước audit. Không reset/checkout/restore/merge/commit/push. Các báo cáo cũ được giữ nguyên; hai báo cáo follow-up là file mới.

### Các commit xuất hiện kể từ checkpoint

| Commit | Nội dung / tác động xác minh |
|---|---|
|`8754acb`|Bổ sung P1 capture/audio/overlay/facecam/region/reliability, tests và báo cáo thiết bị/local fixes|
|`954ab93`|GIF writer buffered/scaled decode, thumbnail GIF direct-decode, progress running≤99; thêm auto-normalization RecordingSettings và manual status report|
|`8412c51`|Merge feature/capture-live với main; giữ cả P1 validator/capabilities và auto-normalization từ nhánh kia, tạo các mâu thuẫn semantics R1/R2|
|`4f8fbca`|Đưa checkpoint TASK08 vào Git, bao gồm code/tests/docs; 29 file từ working checkpoint vẫn byte-exact. Không phải commit do audit này tạo|
|`9afcb12`|Merge main, HEAD hiện tại|
|`4ce6a53`, `903689e`, `6b3a68e`|Các commit lịch sử nhánh P1 nay vào ancestry; ngày tạo cũ hơn, không coi tất cả là code vừa viết sau TASK08|

Các nguồn: [checkpoint comparison](../../build/verification/task08/followup_20261109T063823024767Z/checkpoint_comparison.json), [range commits](../../build/verification/task08/followup_20261109T063823024767Z/range_commits.txt), [P1 boundary hashes](../../build/verification/task08/followup_20261109T063823024767Z/pulled_p1_boundary_hashes.json).

## Findings cần xử lý

| ID / mức độ | Bằng chứng và tác động | Owner / yêu cầu đóng |
|---|---|---|
|**R1 — HIGH: tự đổi/persist recording preferences khi mở form**|`RecordingSettingsForm.didChangeDependencies` gọi `_normalizeSelection` (dòng23–27); dòng68 gọi `settings.update`, sửa resolution/FPS/codec/bitrate khi chưa có lựa chọn người dùng. Không phân biệt default với preference đã lưu. Cũng không áp Performance ceiling trong vòng tìm tuple. Test stale-selection nhận720p thay1080p; ba test320/360/411dp nhận1920×1080/60 thay1280×720/30 sau thao tác qua form.|P1-owned form + người sửa commit954ab93, phối hợp P2 policy Settings. Mâu thuẫn [IR-00-06-01](../p1/TASK_00_06_P2_FIX_REQUESTS.md) “giữ lựa chọn, không silently clamp”. Chưa sửa trong audit.|
|**R2 — HIGH: capability tuple portrait không đồng nhất**|`CaptureBridge` gọi `CaptureConfig.capabilities(activity)`; overload này chỉ trả canonical landscape w≥h (dòng155–169). Form `_normalizeSelection`/`supports` lại so cặp width/height đã xoay portrait. `validateRecordingSelection` dùng long/short edge nên chấp nhận cùng tuple. Host diagnostic với native-shaped1280×720/30: portrait chip720p disabled, landscape enabled, start-validator chấp nhận cả hai.|P1 CaptureConfig + P1 settings form. Thống nhất contract canonical/display dimensions và kiểm portrait/landscape/Auto; chưa lấy emulator capture làm bằng chứng.|
|**R3 — MEDIUM: test finalizing không còn settle**|`export_screen.dart:171` thêm indeterminate LinearProgressIndicator. Test `ux_interaction_test.dart:227` dùng pumpAndSettle nên timeout. Đây là mismatch test/animation đã xác định; **không phải bằng chứng backend export bị treo**.|P3/test owner dùng bounded pumps và assert Saving/no Cancel; kiểm backend completion riêng. Không bỏ assertion hay sửa test trong audit.|
|**R4 — HIGH feature gap: region mới có size/config, chưa thấy crop origin trong renderer**|cropX/Y/Width/Height được validate/truyền; nhưng production cropX/Y chỉ được dùng trong CaptureConfig. `CaptureService:205` tạo VirtualDisplay trực tiếp lên encoder surface; `VideoEncoder` không nhận crop origin hay compositor. Đổi dimensions không chứng minh đã cắt đúng vị trí màn hình.|P1 phải xác minh/hoàn thiện real crop/composition trước pixel-perfect acceptance; P2 shared model/UI là request riêng, không đủ để tự đóng backend gap.|
|**R5 — MEDIUM feature gap: recovery engine chưa nối lifecycle**|`Mp4RecoveryEngine` có parser/conditional helper và JVM tests; tìm production references không thấy caller ngoài khai báo. `CaptureJournal.initialize/cleanup` vẫn đi nhánh interrupted cleanup, không gọi engine.|P1 xác nhận thiết kế và nối recovery nếu thuộc requirement; không gọi F53 production DONE từ helper tests. Không chạy cleanup/recovery trên dữ liệu thật trong audit.|
|**R6 — MEDIUM: shared advanced features chưa nối UI/persistence**|crop/floating/audioDucking mới là optional args trên concrete AndroidRecordingService; shared RecordingService/RecordingSettings vẫn giữ API cũ. Drawing/facecam controls có bridge nhưng thiếu shared UI/persistence/selection theo requests P1.|P1/P2 chốt additive schema và UX ở task implementation được giao. Không tự sửa Settings/MainActivity/Create.|
|**R7 — runtime risk cần retest**|Manual report sau pull ghi stale-source draft black preview/ANR; GIF writer/thumbnail/progress mới chưa có runtime đo lại ở HEAD này. Những kết quả TASK08v5 không phủ code GIF/P1 mới.|TASK09 tái hiện trên clone/fixtures riêng, giữ source/media và logs; không mở hàng loạt draft QA5560.|

Diagnostic R2: [probe v2](../../build/verification/task08/followup_20261109T063823024767Z/portrait_contract_probe_v2.log), hai observations đạt đúng oracle tái hiện lỗi; không ghi thành hai feature acceptance PASS. Lượt probe đầu sai tên fixture member `changes`; đã tạo file v2 dùng `events`, giữ nguyên source/log v1, không chạm production.

## Kiểm tra từng boundary

| Boundary | Kết quả source / host | Giới hạn |
|---|---|---|
|Recording/capture pipeline|Có encoder MediaCodec, MediaProjection, audio PCM/AAC, muxer, output pending→commit→completed; stop/cancel tách semantics, token guard/atomic ending, fresh consent requests.|Host không chứng minh real codec/audio/consent/revoke/background behavior ở HEAD mới.|
|CaptureController / onSaved|MethodChannel `com.xrecorder/capture`, EventChannel `/events` giữ nguyên. Native cancel vềidle, không thêm state ngoài enum. `onSaved` vẫn chỉ khi completed+outputUri; set `_savedIds` chống lặp trong controller. App vẫn `onSaved: media.refresh`.|Set không phải durable exactly-once qua mọi process; URI nonnull không tự chứng minh còn đọc được.|
|MainActivity|Byte-exact với checkpoint. Capture/media/editor/settings registrations và forwarding callbacks vẫn có.|Không tự thêm registration để che lỗi module khác.|
|Permission/request codes|P1 cũ702–706, thêm707 cho controls overlay; P2/P3 vẫn1701–1705. Support activity704 và P1 permission704 thuộc callback namespaces khác nhau. Manifest/service permissions không đổi.|707 additive; actual permission denial/recreation/revoke cần native retest.|
|Create / navigation|`studio_create_sheet.dart`, app router và app scope không đổi. Create vẫn mở recording setup; P2 Edit/Photo shortcuts không đổi capture flow.|Setup UI bên trong đã đổi Basic/Advanced và normalization; UX/a11y/runtime chưa ký nghiệm thu.|
|Settings shared|Controller/store/model document v2, defaults/migrations không đổi theo diff. New form vẫn dùng controller chung.|R1 chứng minh caller có thể ghi preferences dù controller file không đổi; không được báo “semantics giữ nguyên” chỉ bằng hash controller.|
|MediaScope / repository|App/MediaScope/CatalogRepository không đổi; refresh/coalescing, MediaStore event channel còn nguyên.|P1 saved events và MediaStore observation chưa chạy E2E mới; no duplicate/missing row cần kiểm thực tế.|
|MediaStore/FileProvider|P1 MediaOutput không đổi: API29+ Movies/Pictures XRecorder, IS_PENDING trước publish; legacy `.files/media/` URI. Application ID/provider authority giữ nguyên.|Old UID/grants QA5560 là gate recovery riêng, không do schema mới giải quyết.|
|MediaCatalog/GIF|Diff đổi thumbnail GIF sang decode trực tiếp, MIME lấy trước fallback. TASK08 content-key ThumbnailImage/cache vẫn nguyên.|Cần fresh GIF thumbnail/performance/large-image runtime regression; không mang benchmark cũ làm PASS code mới.|
|P3 editor/ASR/draft|TASK08 EditorAudio/Composition/Preview/TranscriptionBridge và dialog khớp working checkpoint; additive paging và PCM endpoint còn nguyên. Shared project schema không đổi.|GIF/export UI có delta riêng; audio/ASR v5 evidence là historical, chưa chạy native current HEAD.|

## P1 feature implementation status

| Nhóm | Hiện có trong source | Readiness |
|---|---|---|
|Basic video/screenshot, consent, cancel, Pause/Resume/Stop|Native pipeline và Dart controller đã nối; screenshot replay dimensions/bounds fallback, request ownership/one-shot guards được bổ sung.|Có thể chuẩn bị basic integration sau R1/R2; current runtime NOT VERIFIED.|
|Audio/mix/noise|Mic/internal/mixed/mute, gain, NoiseSuppressor khi thiết bị có; AudioDuckingEngine được SessionAudio gọi khi mixed+audioDucking.|P1 capture noise khác DSP RNNoise cho file P3; ducking option chưa nằm trong shared settings/UI. Real audible/source/A-V kiểm sau.|
|Quality/countdown/auto-stop/notification|Exact tuple preflight, display-fit gate; CaptureTiming, NotificationPolicy, storage thresholds128MiB trước start/64MiB periodic stop.|Core wired; FPS/thermal/source cadence/low-storage interruption cần runtime; không suy từ math tests.|
|Floating controls/customization|Production overlay, live timer/pause/stop có service wiring; customization optional payload/API.|Default/persistence/UI nâng cao còn integration requests; hide/exclude overlay khỏi recorded pixels chưa chứng minh.|
|Facecam|Camera2 overlay, geometry/rotation, switch/effect/scale APIs và service lifecycle.|Backend/API có; hardware effects/camera switching/rotation và pixels trong output cần device. UI selector/persistence chưa xong. Một số setter trả true dù overlay chưa có, cần consumer kiểm getState.|
|Drawing|DrawingOverlay/StrokeEngine và bridge được service gọi; giới hạn input/chế độ overlay.|Thiếu shared tool palette; Android overlay/capture parity chưa runtime current HEAD.|
|Region|Geometry/validation/optional payload; thiếu shared model/UI và thiếu evidence áp crop origin R4.|PARTIAL; không chỉ chờ UI.|
|Shake / touches|ShakeDetector nối sensor service. ShowTouches truyền config; TouchIndicatorEngine không có production caller được tìm thấy.|Shake cần sensor thật; touch helper không chứng minh in-app/cross-app indicators đã tích hợp. System Show taps guidance không phải implementation nhận touch từ app khác.|
|Reliability / MP4 recovery|Atomic/idempotent release + owned pending cleanup có source; parser/conditional recovery helper có unit tests.|F52 cần fault/runtime; F53 PARTIAL, helper chưa được gọi trong restart path R5.|

Requests còn liên quan: [region](../p1/TASK_08_P2_INTEGRATION_REQUESTS.md), [floating options](../p1/TASK_10_P2_INTEGRATION_REQUESTS.md), [drawing](../p1/TASK_11_P2_INTEGRATION_REQUESTS.md), [facecam](../p1/TASK_12_P2_INTEGRATION_REQUESTS.md), [ducking](../p1/TASK_14_P2_INTEGRATION_REQUESTS.md), [recovery](../p1/TASK_15_P2_INTEGRATION_REQUESTS.md). Các requests là đề nghị kiến trúc/UI, không phải bằng chứng chức năng đã chạy.

## Kiểm thử đã chạy tại HEAD này

| Lệnh/check | Kết quả | Evidence / phạm vi |
|---|---|---|
|`flutter analyze --no-pub`|PASS, no issues,3.8s|[analyze.log](../../build/verification/task08/followup_20261109T063823024767Z/analyze.log)|
|`flutter test --no-pub --reporter expanded`|**271 PASS /5 FAIL**,56s,exit1|[flutter_tests.log](../../build/verification/task08/followup_20261109T063823024767Z/flutter_tests.log);4RecordingSetup +1export finalizing, chi tiết R1/R3|
|`gradlew -p android :app:testDebugUnitTest --offline`|**137 PASS**,22suites,0skip/failure/error; native compile thành công|[native log](../../build/verification/task08/followup_20261109T063823024767Z/native_unit_tests.log), [JUnit summary](../../build/verification/task08/followup_20261109T063823024767Z/junit/summary.json); JVM, không instrumentation|
|Portrait/canonical tuple diagnostic host|Tái hiện khác biệt portrait/landscape,2observations|[probe v2](../../build/verification/task08/followup_20261109T063823024767Z/portrait_contract_probe_v2.log); negative behavior confirmed, không acceptance|
|Git/source/evidence integrity|Đối chiếu toàn bộ tracked files và incident evidence ở cuối audit|[final preservation](../../build/verification/task08/followup_20261109T063823024767Z/final_preservation.json)|

Không cài, build APK phát hành, capture hay mở app trên thiết bị. Gradle/Flutter chỉ tạo build/cache host bình thường. APK TASK08 mainv5 là artifact **trước pull**, không chứa đủ P1/GIF hiện tại; không coi nó là APK đã QA cho HEAD9afcb12.

## Phân biệt bằng chứng lịch sử với readiness hiện tại

P1 có [báo cáo OPPO API30](../p1/TASK_00_06_REAL_DEVICE_TEST_REPORT.md):55PASS/1FAIL/29NOT RUN/8UNSUPPORTED, branch4ce6a53+dirty source. [Local fixes](../p1/TASK_00_06_LOCAL_FIX_REPORT.md) sửa replay/validation/finder sau đó nhưng còn native Cancel/Replay/semantics pending. Đây là tiến bộ thực và được giữ nguyên; không chứng nhận bản merge mới đã vượt các gate đó. Phiên follow-up không sử dụng điện thoại hay emulator cá nhân.

P2/P3 core có thể tiếp tục QA độc lập với synthetic/licensed media, không phải chờ P1 hoàn tất. Basic P1 handoff giữ contract nên có thể chuẩn bị các case stop-save MP4, screenshot PNG, cancel-no-Saved, Library refresh rồi Editor/export. Các advanced features region/floating customization/drawing/facecam UI/ducking/recovery cần chốt request, backend gap và device tests; không đánh dấu DONE bằng UI/API/helper tests.

Để vào full TASK10: P1/team xử lý R1/R2, host regression đạt; xác nhận phạm vi P1 ready, chuẩn bị build mới từ source đã chốt trên QA riêng có backup và margin; sau đó mới chạy consent/capture/output/URI/preview/export E2E khi được giao task. Giữ QA5560 recovery gate độc lập, không chặn TASK09 vô thời hạn.

**Verdict cuối:** TASK08 **PARTIAL** · P1 **PARTIAL** · P2/P3 compatibility **PARTIAL** · TASK09 **có thể bắt đầu với các finding trên** · TASK10 full integration **chưa sẵn sàng**.
