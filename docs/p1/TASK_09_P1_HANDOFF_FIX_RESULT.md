# Task 09 — P1 handoff fix result

Ngày: 2026-11-10. **PARTIAL; TASK10 READY: NO.**

Hồ sơ bàn giao tham chiếu `9afcb124069d905dd4b285c890ca0709f5548b68`. Checkout thực tế khi bắt đầu là `main`, HEAD `64e84ec0f952c4e28063488812933010f05bfa7d`, working tree sạch. Không checkout/reset hoặc ghi đè thay đổi của team. Các log `build/verification/task09/run_20261109T091518633188Z/` không có trong checkout này; đã tái hiện tại HEAD hiện tại, không coi số 285 PASS/4 FAIL cũ là kết quả mới.

Chỉ sửa logic P1 và thêm tests; không ADB, điện thoại, emulator, capture mới, commit hoặc push. Không sửa shared UI/theme/router, SettingsController, MainActivity, Manifest, model P2/P3, encoder hoặc crop pixel pipeline.

## Kết quả theo issue

| Issue | Kết quả | Acceptance còn thiếu |
|---|---|---|
| R1 — mở Settings tự thay preference | **FIXED & LOCALLY VERIFIED** ở logic. Bỏ `_selectionNormalized`, `_normalizeSelection` và mutation trong callback capabilities. Open/close chỉ đọc. Disabled selected option vẫn giữ nguyên; Start validation chặn tuple không hỗ trợ và dùng error flow/tooltip hiện có. | Ba test layout 320/360/411dp đang vướng shared handle sau merge; không tuyên bố toàn bộ acceptance R1 PASS. |
| R2 — Portrait disabled sai | **FIXED & LOCALLY VERIFIED.** UI chips và Start dùng cùng helper canonical long/short edge, codec/FPS và Performance policy; bỏ phép so axes phụ thuộc Portrait/MediaQuery của form. | Encoder/output thật và orientation trên thiết bị được phép vẫn là gate riêng, NOT RUN. |
| R4 — crop origin chưa vào pixel pipeline | **P1 HANDOFF / NOT VERIFIED.** Không sửa encoder/VirtualDisplay, không quay mới theo phạm vi bàn giao. | Pixel oracle hai origin cùng size, rotation, biên, cancel/consent và A/V sync. Geometry tests không thay thế output pixels. |
| R5 — recovery chưa nối production | **CONFIRMED STATIC GAP / NOT FIXED.** Caller search vẫn chỉ thấy định nghĩa engine; initialize của journal đi cleanup. Không nối helper cấu trúc container vào Saved/publish để coi là recovery production. | Journal → recovery/retention → validated output, failure/cancel/no-space, full MP4 decode và A/V timeline. Cần thiết kế checkpoint/retention trước cleanup. |
| R6 — advanced capture contract/UI | **PARTIAL.** Xác nhận backend/caller và own floating preferences; không thêm UI hoặc fields shared ngoài ownership. | Shared typed contract, persistence/semantics và native output acceptance tương ứng từng feature. |

## R1/R2 — implementation và semantics

- [RecordingSettingsForm](../../lib/features/settings/recording_settings_form.dart): capabilities future chỉ phục vụ validation/build; không gọi `settings.update` khi future hoàn tất. Các callback explicit của người dùng được giữ nguyên. Không tự đổi resolution/FPS/codec/bitrate khi mở màn hình hoặc chuyển Basic/Advanced.
- [recording_selection.dart](../../lib/features/recording/recording_selection.dart): helper thuần `supportsRecordingTuple` dùng chung với `validateRecordingSelection`. Canonical hóa kích thước cả request và advertised tuple; vẫn yêu cầu đúng codec/FPS/size và kiểm Performance ceiling. Không fallback sang một tuple khác khi validation thất bại.
- [RecordingSetupSheet](../../lib/features/recording/recording_setup_sheet.dart): import/re-export validator để giữ API import cũ; Start callback và widget tree không đổi.
- Native `CaptureConfig.capabilities(activity)` đang advertise canonical presets chỉ khi encoder nhận cả hai axes, đúng codec/FPS, alignment/surface và display bound. `CaptureBridge` gọi overload có activity. `CaptureConfig.from` vẫn resolve orientation và preflight actual size/rate/bitrate trên encoder. Không sửa/native-advertise thêm tuple unsupported. Overload không context không được dùng làm lý do suy hardware support trong kết quả này.
- Lựa chọn đang invalid vẫn hiện selected/disabled; không được áp dụng bằng Start. Khi người dùng chọn resolution hợp lệ, callback hiện có chỉ điều chỉnh FPS nếu FPS cũ không hỗ trợ, rồi persist qua SettingsController. Chọn Performance rõ ràng vẫn giữ semantics preset đã có; chỉ đọc một preference Performance invalid không tự hạ cấu hình. Bitrate vượt policy vẫn bị Start guard từ chối.

## Test trước/sau trên Ubuntu

Evidence: [task09_handoff_fix](test_evidence/task09_handoff_fix/).

| Lượt chạy | Kết quả thực tế | Evidence |
|---|---|---|
| Test gốc `flutter test --no-pub test/recording_setup_sheet_test.dart` trước sửa | **1 PASS / 4 FAIL**. Stale selection bị đổi 1080p → 720p; ba layout tests lỗi finder handle. | [baseline_settings.log](test_evidence/task09_handoff_fix/baseline_settings.log) |
| 7 regression mới trước sửa | **2 PASS / 5 FAIL**: bốn open/close/no-write cases và Portrait fail; Landscape/Auto Sensor trong viewport test này pass. | [baseline_new_regressions.log](test_evidence/task09_handoff_fix/baseline_new_regressions.log) |
| Test gốc + 7 regression sau sửa | **9 PASS / 3 FAIL**. Stale selection test gốc đã PASS; ba layout failures giữ nguyên. | [settings_after.log](test_evidence/task09_handoff_fix/settings_after.log) |
| Final targeted regression, gồm 9 cases R1/R2 | **37 PASS** | [regression_local.log](test_evidence/task09_handoff_fix/regression_local.log) |
| `flutter analyze --no-pub` | **PASS, no issues**. Một lint braces ở helper mới trong iteration đầu đã sửa. | [analyze_final.log](test_evidence/task09_handoff_fix/analyze_final.log) |
| `./gradlew :app:testDebugUnitTest --tests 'com.xrecorder.xrecorder.recording.*'` từ android/ | **125 PASS / 16 suites**, native debug compilation thành công. Không phải instrumentation/capture acceptance. | [native_regression.log](test_evidence/task09_handoff_fix/native_regression.log), [JUnit summary](test_evidence/task09_handoff_fix/native_summary.json) |
| `git diff --check`, source ownership/hash | **PASS** | [final_validation.json](test_evidence/task09_handoff_fix/final_validation.json) |

Lệnh final Dart regression:

```sh
flutter test --no-pub test/recording_settings_capability_test.dart test/mediaprojection_consent_flow_test.dart test/recording_controller_test.dart test/recording_service_contract_test.dart test/recording_replay_test.dart test/settings_persistence_test.dart
```

Test mới [recording_settings_capability_test.dart](../../test/recording_settings_capability_test.dart) kiểm:

- Full settings và setup, Normal/Performance, mở/đóng hai lần: write count bằng 0, document byte-for-byte không đổi, restore controller mới vẫn giữ 1080p/60/24Mbps.
- Explicit supported choice mới tạo đúng một write, tuple 720p/30 được restore và reopen không ghi thêm.
- Portrait/Landscape/Auto Sensor: cùng advertised 1280×720/30/AVC bật đúng chips và qua cùng Start validator.
- Resolution/FPS/codec không advertise vẫn disabled/rejected; Performance không nhận tuple cao hơn policy dù Normal hỗ trợ.

Không bỏ test gốc, không đổi expected, không skip hoặc gọi diagnostic triệu chứng là fix. Không chạy lại full Flutter suite của repository; 37 PASS không phải kết quả full suite. Capture/consent dispatch và mapping/replay local đã retest; native consent/dialog/MP4/PNG runtime chưa retest.

## Blocker mới tại HEAD hiện tại: layout test/shared contract

Commit `b46fc7b` sau mốc bàn giao đã đưa vào shared bottom-sheet/theme mới. Theme hiện có `showDragHandle: true`, `dragHandleSize: Size(40, 3)`; test gốc tìm `Container` có constraints 36×4 và kiểm gap22px. Finder không tìm thấy widget nên ba test dừng trước assertion recording tuple. Không kết luận handle không hiển thị; đây là mismatch giữa finder/contract cũ và shared component mới.

Lỗi này tồn tại cả trước và sau bản sửa R1/R2 trên HEAD64e84ec. Không sửa shared UI hoặc đổi expected để làm xanh. Xem [P2 follow-up](TASK_09_P1_FOLLOWUP_REQUESTS.md), IR-09-P1-01.

## R5 — lý do chưa bật production recovery

Các nhận xét sau là source analysis, không phải recovery runtime PASS:

1. `CaptureJournal.initialize → cleanup` kiểm pending item thuộc app và xử lý cache theo session ID. Hiện không gọi `Mp4RecoveryEngine` hoặc giữ checkpoint phục hồi trước cleanup; đây vẫn là gap thật.
2. `inspect` của helper chỉ kiểm top-level MP4 boxes. Các fixtures JUnit dùng moov/mdat giả lập cấu trúc, không chứng minh sample tables/codec frames có thể decode.
3. `SessionCheckpoint.canRecover` mới yêu cầu video file tồn tại/non-empty. Chưa có durable sample index cho moov bị thiếu; chưa thấy checkpoint timeline đủ để phục hồi chính xác audio offset và pause ranges.
4. Default recovery path copy video từ checkpoint; không tự kết hợp audio chỉ vì `hasAudio=true`. Promotion hiện có nhánh xóa/overwrite target đã tồn tại. Không đưa đường đó vào startup publish khi chưa chặn overwrite, validate track/decode/timeline và giải quyết ownership/failure/no-space.

Thiết kế cần làm tiếp thuộc P1: giữ input/manifest của đúng session trước destructive cleanup; không scan media người dùng; inspect/eligibility → isolated recovery candidate → validate actual tracks/decode/A-V → publish một lần hoặc giữ nguồn/diagnostic nếu không đủ điều kiện. Permission/token của phiên cũ không được hồi sinh. Không tạo Saved giả cho file thiếu moov/0 byte hoặc candidate chưa validate. Đây là kế hoạch cần triển khai/test, **chưa phải code đã nối production**.

Không dùng dữ liệu QA5560, không gây process interruption hoặc thử no-space trên thiết bị trong lượt này.

## R6 — contract decision trước Task10

Giữ nguyên shared `RecordingService.start(RecordingSettings)` và commands/events/`onSaved → media.refresh` hiện có. Lượt này **không ban hành shared advanced capture schema mới**; P2/P3 không tự thêm fields bằng suy luận từ optional concrete args. Chưa được coi Task10 ready.

| Nhánh | Xác nhận trong source | Gate còn thiếu |
|---|---|---|
| Facecam | Overlay + permission/camera guard; bridge/service có switch camera, effect, scale, state APIs. | Typed UI/model/persist contract; deny/no camera/relaunch và output parity. |
| Drawing | DrawingOverlay/StrokeEngine và bridge enable/clear/undo/style/state, service caller. | Palette/width/erase/exit UI; touch pass-through và output pixel semantics. |
| Floating controls | Có own prefs `3hrecorder_floating_ball`: x/y ratio, scale, opacity; applyCustomization/persist đường riêng. | Shared Settings binding/schema với ownership rõ ràng. Không ghi là thiếu toàn bộ persistence. |
| Ducking/crop | Concrete AndroidRecordingService args và CaptureConfig có parsing/sanitize. | Chưa là fields shared RecordingSettings cho capture; crop output gate R4. Không expose bằng UI trước pixel acceptance. |
| Show touches/shake | Shake có sensor/service caller. `TouchIndicatorEngine` trong recording source mới thấy định nghĩa. | Không gọi helper-only là feature DONE; phải xác nhận actual input/caller và semantics. |

Các field crop của editor ClipRange không phải crop contract của native recording. Trước khi P2 thêm UI/shared fields, P1 cần chốt tên/units/defaults/persistence, runtime vs next-session apply, denied/unsupported handling và snapshot/event mapping; xem IR-09-P1-02.

## UI/Git freeze và kết luận

Chỉ hai source có sẵn đổi: form capabilities logic và nơi định nghĩa validator. Hai file mới: helper P1 và regression test. Widget tree/render phần còn lại, UI/icon/theme/navigation, source native/SettingsController/MainActivity và tests gốc không đổi. [Hash inventory](test_evidence/task09_handoff_fix/source_inventory.json), [UI freeze check](test_evidence/task09_handoff_fix/ui_freeze.json).

R1/R2 có fix + local evidence. Ba layout failures cần P2 xác nhận contract; R4/R5/R6 và native capture acceptance còn mở. **P1 PARTIAL / TASK10 READY: NO.** Không nâng NOT VERIFIED thành PASS từ unit tests.
