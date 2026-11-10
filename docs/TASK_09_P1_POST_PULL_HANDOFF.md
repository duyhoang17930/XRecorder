# TASK 09 — P1 Bug Handoff / Post-Pull Team Integration

**Ngày soạn:** 09/11/2026. Đây là **danh sách nghi vấn/bug đã thấy trong báo cáo post-pull**, không phải kết quả tái kiểm hiện tại. Người chạy TASK09 xác nhận bằng source và test ở HEAD mới, rồi cập nhật trạng thái. **Không tự sửa P1 protected code** khi đang chạy P2/P3 TASK09.

## Chủ sở hữu và kiểm soát

P1 (Người 1) sở hữu `lib/features/recording/**`, native recording module, `recording_settings_form.dart`, `audio_video_settings_screen.dart`, capture UI semantics trong `studio_create_sheet.dart`, P1 channels/settings. Shared P2↔P3 chỉ additive theo contract. Khi team pull, P1 code được phép thay đổi bởi Người 1; kiểm `git diff` snapshot hiện tại trước khi quy trách nhiệm.

| ID | Severity / owner | Chi tiết cần tái hiện | Expected / tiêu chí đóng |
|---|---|---|---|
| R1 | HIGH / P1 | Mở Recording Settings mà không thao tác; `_normalizeSelection` trong `didChangeDependencies` có thể gọi `settings.update` vào resolution/FPS/codec/bitrate và ghi đè cấu hình theo cap/Performance. | Open/back không mutate saved config; chỉ explicit user selection/save hợp lệ; bảo toàn setting qua relaunch; test incoming legacy/unsupported value với warning thích hợp. |
| R2 | HIGH / P1 | Portrait 720p bị disable trong UI bởi capabilities canonical landscape width>=height, trong khi native preflight kiểm normalized long/short và recorder hỗ trợ. | UI và recorder dùng cùng canonical capability mapping; portrait hợp lệ chọn được, unsupported thật vẫn bị chặn; test thiết bị portrait/landscape + config restore. |
| R4 | HIGH / P1 | Region selection gửi `cropX/cropY/width/height`, validation nhận nhưng recorder VirtualDisplay encoder không áp crop origin. | MP4 pixel oracle cho region lệch gốc chứng minh đúng vị trí crop, không chỉ crop size; test rotation, UI selection, pixel coordinates, preview/output. |
| R5 | MEDIUM / P1 | `Mp4RecoveryEngine` có unit test nhưng post-pull audit không thấy production caller trong startup/recovery journal path. | Có production hook an toàn, idempotent, durable; broken MP4 thật được detect/recover/fail đúng UI, không xóa source, không duplicate publication; test force-stop/relaunch có kiểm soát. |
| R6-P1 | MEDIUM / P1 | Optional arguments/backend cho Facecam, drawing, floating overlay/position, audio ducking và crop có thể thiếu UI toggles/persistence/action wiring. | Truy vết từng CTA→settings→native param→actual output, hoặc đánh dấu không thuộc committed feature scope với quyết định product rõ; kiểm restart/permission denied. |
| R6-INT | MEDIUM / P1+P2/P3 | Shared capture/Create và `CaptureController(onSaved: media.refresh)` có thể không thống nhất kỳ vọng permission/event/result navigation sau team pull. | Hai owner thống nhất contract, không đổi P1 channel một phía; real capture→P2 library index→P3 import/export trên máy được cấp phép. |

## Vấn đề liên quan nhưng thuộc P2/P3

| ID | Owner | Xử lý trong TASK09 |
|---|---|---|
| R3 | P3 | Test `export_screen.dart` indeterminate progress chạy `pumpAndSettle` vô hạn; xác nhận nguyên nhân và sửa harness/behavior với bounded pump, giữ Saving/finalizing/cancel guard assertions. |
| R7 | P2/P3 khi xác nhận | Preview draft với stale source hiển thị đen/ANR, GIF writer/thumbnail/progress sau pull: tái kiểm bằng QA được ủy quyền, log generation/decoder, sửa trong P2/P3 nếu reproduces. |

## Mẫu bug để Codex điền khi audit

```
ID:
HEAD / device / API / orientation:
Owner: P1 | P2 | P3 | Shared
Severity: P0 | P1 | P2 | P3
Screen / widget / handler / native channel:
Preconditions & consent:
Exact steps to reproduce:
Input & fixture source:
Expected:
Actual (log/frame/video/pixel measurement):
Root-cause hypothesis + code references:
Reproduction test / failed artifact:
Suggested minimal fix owned by Person1:
Regression acceptance (automatic + real device):
State: OPEN | VERIFIED FIXED | BLOCKED | NOT REPRODUCED
```

## Handoff policy

1. Gửi file này cho Người 1 cùng `TASK_09_P1_HANDOFF.md` cuối cùng mà Codex xuất; nếu còn issue OPEN HIGH, không bắt đầu TASK10 integration certification.
2. Người 1 sửa trong nhánh/code thuộc P1, test native, gửi commit/HEAD + P1 feature matrix + QA artifacts; P2/P3 team đọc và chỉ chỉnh phần adapters own.
3. Bất kể P1 source diff 0 hay tests xanh, không gắn FACEcam/native capture DONE khi chưa có output/device bằng chứng.
4. Sau P1 ready và TASK09 P2/P3 verified, lên TASK10 thực hiện final merged E2E + physical acceptance; giữ QA5560 recovery PARTIAL như một gate dữ liệu riêng.

## Thông điệp ngắn gửi Người 1

> Team P2/P3 đang audit full-app trên HEAD mới. Các issue R1 (Settings tự mutate), R2 (portrait capability), R4 (region origin không áp pixel), R5 (MP4 recovery chưa được gọi production), R6 (capture options UI/persistence) cần P1 xác minh/sửa. Xin gửi bug reproduction + native outputs + HEAD sau khi fix, nhất là R1/R2 trước TASK10. P2/P3 sẽ không sửa protected P1 code và sẽ giữ các contract hiện có.
