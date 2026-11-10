# Task 09 — P1 follow-up requests

Ngày: 2026-11-10. HEAD thực tế `64e84ec`; không sửa source P2/P3 trong lượt P1 này.

## IR-09-P1-01 — Shared bottom-sheet contract sau merge làm ba tests P1 fail

- Owner: P2 shared UI/theme, phối hợp P1 QA.
- Files liên quan: `lib/core/ui/components/bottom_sheets/studio_bottom_sheet.dart`, `lib/core/ui/theme/app_theme.dart`; consumer test `test/recording_setup_sheet_test.dart`.
- Actual: theme mới từ commit `b46fc7b` dùng drag handle40×3; test gốc tìm Container36×4/gap22. Các tests320/360/411dp fail tại finder trước assertion tuple, cả baseline và sau R1/R2 fix.
- Evidence: [baseline](test_evidence/task09_handoff_fix/baseline_settings.log), [after](test_evidence/task09_handoff_fix/settings_after.log). Không kết luận handle không render.
- Minimal requested action: xác nhận layout/handle contract nào được duyệt. Nếu phải giữ contract cũ, P2 sửa shared component theo ownership; nếu thiết kế mới đã được duyệt, bàn giao contract/finder ổn định để P1 cập nhật tests trong task được cho phép. Lượt này không đổi expected/skip test để xanh.
- Acceptance: cả320/360/411dp qua các geometry/action-pinned/overflow và tuple assertions, vẫn kiểm đầy đủ controls và explicit state semantics; không bỏ assertion chức năng.

## IR-09-P1-02 — Advanced capture schema chưa được ban hành cho P2/P3

- Owners: P1 API/capture trước, P2 shared `lib/core/domain/models.dart`, `repositories.dart`, SettingsController và UI sau khi có contract.
- Actual evidence: backend bridge/service có Facecam/Drawing/Floating runtime APIs; AndroidRecordingService có optional crop/ducking/floating args nhưng shared RecordingSettings/RecordingService chưa mô tả đủ. Native floating preferences riêng đã có, không được gọi là chưa persist.
- Decision hiện tại: giữ API public đang merge; chưa expose crop khi R4 chưa có pixel acceptance; chưa thêm fields/shared UI theo concrete args. Không đổi source shared trong lượt này.
- Minimal next handoff: P1 chốt schema typed, units/range/default, feature capabilities/denied semantics, runtime hay next-session apply, persist/relaunch và snapshot/event mapping. P2 chỉ triển khai binding/persistence/UI sau handoff đó; không tự đặt field hoặc giả sử backend helper là feature hoàn chỉnh.
- Acceptance: typed request → native effective config → event/UI đồng nhất; no silent preference writes; output/runtime gates từng feature và ownership được test. Task10 vẫn NO khi R4/R5 và capture acceptance còn mở.

Chi tiết R1/R2 fix và R4/R5/R6 status: [P1 result](TASK_09_P1_HANDOFF_FIX_RESULT.md). Không gửi email/chat hoặc tạo issue từ tài khoản người dùng.
