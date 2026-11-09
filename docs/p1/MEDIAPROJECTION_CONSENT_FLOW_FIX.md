# MediaProjection Consent Flow Fix

Ngày: 2026-11-08. Branch `feature/capture-live`, HEAD `4ce6a53`, giữ nguyên working tree có sẵn. **FIXED & LOCALLY VERIFIED — DEVICE VERIFICATION PENDING.** Chỉ P1 Kotlin và tests; không ADB, thiết bị, emulator, instrumentation, cài app, commit hoặc push.

## Khi nào cần consent

Mỗi phiên MediaProjection mới phải xin consent hợp lệ. Android 14+ không cho dùng lại result Intent để lấy projection nhiều lần hoặc tạo nhiều VirtualDisplay từ cùng projection. Token đã dừng không dùng cho phiên mới. Không triển khai “Allow forever”. Tham chiếu [Android Developers: user consent](https://developer.android.com/media/grow/media-projection#user-consent), [MediaProjectionManager API](https://developer.android.com/reference/android/media/projection/MediaProjectionManager).

| Thao tác | Hành vi của dự án sau sửa |
|---|---|
| Start mới, kể cả sau Stop/cancel/revoke/process death | Tạo request/session mới; xin consent mới, không lấy token từ journal hoặc cache. |
| Screenshot độc lập | One-shot session mới, consent mới. Trên API34+ vẫn dùng config default display như trước. |
| Pause/Resume cùng native session còn sống | Chỉ suspend/resume encoder/audio và active timer; không tạo consent Intent, projection hoặc MP4 mới. |
| Về app / Activity hoặc Flutter controller recreate khi service còn sống | Đọc current/snapshot, nối lại session; không Start hoặc xin consent lại. |
| Process đã chết | Journal đánh dấu interrupted session failed; không phục hồi projection/token. Start tiếp theo là phiên mới. |

Dialog micro/camera/notification và trang cấp overlay là các quyền khác, không phải MediaProjection consent. Chúng vẫn phụ thuộc chức năng được chọn và trạng thái quyền thực tế.

## Kết quả kiểm tra và lỗi đã sửa

1. **Bước overlay không bắt buộc trước recording.** Trước đây video không dùng Facecam vẫn đi vào `ensureControlsPermission()`, tự mở Overlay Settings nếu chưa có quyền, dù controls chỉ được hiện khi người dùng chấp nhận xuất hiện trong video. Mỗi lần từ chối rồi Start lại có thể lặp bước này. Nay nhánh không Facecam đi thẳng tới MediaProjection sau bước audio/notification hiện có. Khi chưa có overlay, Pause/Resume/Stop qua notification tiếp tục là fallback, phụ thuộc khả năng hiển thị notification/quyền trên phiên bản Android. Facecam vẫn cần overlay/camera và giữ nguyên chuỗi quyền bắt buộc. Đây là thay đổi luồng quyền hệ thống, không sửa navigation/router/layout trong app.

2. **Request idempotent trước khi tạo Intent.** Trước đây `openActivity(intent, code)` nhận Intent đã được tạo; `CaptureRequests.launch()` mới kiểm pending và sẽ throw khi gọi lại. Nay `launchOnce()` reserve trước, rồi mới gọi factory/API launch. Cùng code/session đang pending trả về mà không tạo Intent hoặc mở permission lần hai; request khác vẫn bị chặn. Nếu factory/launch lỗi, chỉ reservation của chính request đó được giải phóng. Áp dụng cho Activity result và runtime permission.

3. **Callback ownership trước khi consume.** Trước đây callback consume pending trước khi kiểm bridge disposed hoặc requestedSession; callback không còn hợp lệ có thể làm mất ledger của receiver hiện tại. Nay `consumeFor()` kiểm receiver còn active và cùng session trước khi consume, sai request code không làm mất pending. Replacement Activity cùng session có thể nhận request; callback stale/disposed không lấy request của nó.

Cancel khi dialog còn mở là ngoại lệ cần drain: `requestedSession` đã bị clear nhưng ledger phải giữ request cũ cho đến callback. Bridge chỉ cho drain theo ID hiện tại khi native không busy; state/owner checks sau đó bỏ qua consent của phiên đã hủy. Không dùng result cũ để Start và không để ledger kẹt vô hạn sau callback hợp lệ.

Không tìm thấy đường Pause/Resume/current/lifecycle-resume gọi `createScreenCaptureIntent()` trong implementation đang có. Start đã có busy/pending/service guards; callback result cũng chỉ được consume một lần. Không có evidence thiết bị chứng minh từng xuất hiện hai dialog MediaProjection; phần idempotence là hardening cho re-entry, không phải tuyên bố đã tái hiện duplicate dialog thực tế.

## Files và phạm vi

- [CaptureBridge.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureBridge.kt): bỏ bước overlay optional khỏi Start không Facecam; lazy Intent launch; callback ownership.
- [CaptureRequests.kt](../../android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureRequests.kt): `launchOnce` và `consumeFor`; ledger chỉ giữ request code/session ID, không giữ Activity, lambda, consent Intent hoặc token.
- [CaptureRequestsTest.kt](../../android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureRequestsTest.kt): năm regression cases mới, giữ ba cases cũ.
- [mediaprojection_consent_flow_test.dart](../../test/mediaprojection_consent_flow_test.dart): lifecycle/command dispatch tests với fake service, không giả lập native consent thành PASS.

Không sửa Dart production, CaptureService, Recording Engine, MediaStore, encoder, timer, screenshot pipeline, Facecam renderer, UI/icon/style/settings layout hoặc MainActivity/Manifest/P2/P3. Đã đọc MainActivity chỉ để đối chiếu callback/cleanup integration. [Incremental native diff](test_evidence/mediaprojection_consent_flow/incremental_native_diff.patch) tách riêng các thay đổi lượt này khỏi diff có sẵn.

## Lifecycle và security đã đối chiếu trong source

- `CaptureBridge.start/screenshot` reject khi busy, pending result hoặc service vẫn tồn tại; `current` chỉ snapshot.
- `requestedSession` của bridge mới chỉ gắn với native `awaitingPermission` hiện tại; không tự launch từ constructor/reopen.
- `CaptureService.onStartCommand` lấy projection từ result mới sau foreground start; guard projection/started/ending và session/state tránh khởi tạo lại trên cùng service. Mỗi đường video hoặc screenshot tạo một VirtualDisplay; không chia lại token giữa hai đường.
- `setPaused()` giữ projection/display/encoder; pause ranges và elapsed active giữ nguyên.
- `MediaProjection.Callback.onStop()` gọi stop/finalize; release projection/display và service. Không tự restart sau revoke.
- Journal chỉ persist metadata; initialize trong cùng process có guard, không làm hỏng service còn sống khi Activity recreate. Process mới không phục hồi token của phiên interrupted.
- Không thay cơ chế Android14+ app selector/default-display screenshot hoặc thêm đường bypass/root/accessibility/permission grant.

## Tests và static checks trên Ubuntu

Evidence: [mediaprojection_consent_flow](test_evidence/mediaprojection_consent_flow/).

| Check | Result | Evidence / phạm vi |
|---|---|---|
| `flutter test --no-pub test/mediaprojection_consent_flow_test.dart test/recording_controller_test.dart test/recording_service_contract_test.dart test/recording_replay_test.dart test/recording_setup_sheet_test.dart` | **PASS — 28 tests** | [flutter_tests.log](test_evidence/mediaprojection_consent_flow/flutter_tests.log). Gồm 3 tests mới: reconnect+Pause/Resume cùng ID không Start, duplicate Start bị chặn trong các busy states, revoked session không auto-restart. |
| `./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'` từ android/ | **PASS — 29 tests / 7 suites** | [native_tests.log](test_evidence/mediaprojection_consent_flow/native_tests.log), [summary/JUnit counts](test_evidence/mediaprojection_consent_flow/summary.json). Request tests: factory chỉ gọi một lần sau reservation; callback stale/disposed/wrong code; fresh launch cho session tiếp; lỗi launch giải phóng reservation; drain result của phiên đã hủy. Các timing, screenshot packing/replay dimensions, audio/video math, bitrate và geometry tests vẫn PASS. |
| Native debug Kotlin compilation | **PASS** | Gradle unit-test build biên dịch P1 thay đổi. Không chạy instrumentation hoặc cài APK. |
| `flutter analyze --no-pub` | **PASS** | [flutter_analyze.log](test_evidence/mediaprojection_consent_flow/flutter_analyze.log), no issues. |
| `git diff --check`, hash/ownership | **PASS** | [final_validation.json](test_evidence/mediaprojection_consent_flow/final_validation.json). Chỉ 3 source/test files có sẵn đổi trong lượt này và 1 test Dart mới; không mất baseline file. |
| Số lần system dialog thực tế / MediaProjection runtime / MP4/PNG mới | **NOT RUN — DEVICE REQUIRED** | Không dùng kết quả build hoặc fake-service tests để tuyên bố native integration PASS. |

Task02–06: local regressions kiểm session dispatch, mapping audio/config, valid settings, screenshot replay, native timing/math/packing. Không có capture output mới hoặc chứng nhận lại audio/source sync/background/rotation bằng thiết bị trong lượt này.

## Device verification còn cần

1. API30 và API34+: Start → chấp thuận một MediaProjection dialog; Pause/Resume, Home/reopen không xin lại; Stop → Start phải có consent mới.
2. Recreate Activity khi consent đang mở và khi recording/paused; xác nhận request/session không mất, không mở dialog thứ hai, thời lượng và ID giữ nguyên khi native session còn sống.
3. Double Start, callback/permission denial/cancel và Start lại; không file giả hoặc phiên thứ hai. System revoke phải kết thúc phiên, không Resume bằng token cũ.
4. Không Facecam + overlay denied: không bị đưa vào Overlay Settings; recording và notification controls hoạt động. Overlay đã granted: opt-in controls hiện có vẫn hoạt động. Facecam chọn bật: quyền overlay/camera cần thiết vẫn được hỏi và denial được xử lý.
5. Screenshot fresh consent/countdown/PNG/View; recording audio modes, Pause/Resume/Stop/MP4/MediaStore và auto-stop. Android14+ one-shot restrictions phải được kiểm trên API tương ứng, không suy từ API30.

## Integration request / giới hạn

Không cần P2 sửa MainActivity/Manifest cho bản sửa này. Nếu sản phẩm muốn xin overlay cho recording controls khi chưa granted, cần **P2 phối hợp entry explicit opt-in trong luồng hiện có**; không tự mở Settings trước mọi Start hoặc dùng Facecam làm thủ thuật cấp quyền. Lượt này không thêm/sửa UI đó. Khi chưa được cấp quyền, floating controls chưa khả dụng; notification controls là fallback. Đây không phải quyền MediaProjection vĩnh viễn.

Kết luận: giảm bước xin quyền overlay thừa và harden ownership/idempotence bằng minimal diff; local tests/static checks PASS. Runtime consent count và Android14+ lifecycle còn **DEVICE VERIFICATION PENDING**, không đánh dấu toàn bộ Task02–06 DONE.
