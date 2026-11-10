# TASK 09B — Cập nhật bàn giao Người 1

P1 **PARTIAL**; **TASK10 READY: NO**. HEAD `9afcb124069d905dd4b285c890ca0709f5548b68` vẫn là checkpoint hiện tại. Không có commit mới của Người 1 trong phiên này. Không sửa recording/capture/MainActivity/recording settings semantics, không chạy capture thử và không gửi thông báo ra dịch vụ bên ngoài.

Full Flutter regression TASK09B: **317 PASS, 4 FAIL**. Bốn test vẫn đỏ, không skip/xóa/đổi expected:

1. `a stale selection is rejected until the user selects a supported tuple`
2. `Setup pins actions and preserves controls at 320.0dp`
3. `Setup pins actions and preserves controls at 360.0dp`
4. `Setup pins actions and preserves controls at 411.0dp`

[Raw result](../../build/verification/task09b/run_20261109T113727956224Z_f64203/flutter_full_v3_boundary_candidate.jsonl), [summary](../../build/verification/task09b/run_20261109T113727956224Z_f64203/flutter_full_summary_v3.json). 137 JUnit PASS không hủy bốn lỗi Flutter này.

| Issue | Repro / nguyên nhân và source | Bằng chứng / bước đóng thuộc P1 |
|---|---|---|
| R1 HIGH | [RecordingSettingsForm](../../lib/features/settings/recording_settings_form.dart) didChangeDependencies → normalize → settings.update. Mở với stale/unsupported tuple, chờ capabilities, không chọn gì; persisted selection bị đổi | Bốn test đỏ nêu trên, source P1 giữ nguyên. Tách validation khỏi mutation; mở/Back không write; chỉ lựa chọn rõ ràng mới persist; regression 320/360/411dp |
| R2 HIGH | Portrait 720p với advertised 1280×720/30/AVC: validator nhận nhưng chip bị disabled; UI và preflight so tuple khác quy ước | [Probe TASK09](../../build/verification/task09/run_20261109T091518633188Z/portrait_probe_task09_v1.log) được reuse vì source P1 hash không đổi. Dùng validator/canonical orientation thống nhất và kiểm encoder trên thiết bị được phép |
| R4 HIGH / native NOT RUN | CaptureConfig nhận crop origin; VirtualDisplay/VideoEncoder hiện chưa chứng minh áp offset vào pixel pipeline | Dựng fixture bốn góc; record hai vùng cùng size khác origin, kiểm pixel/rotation/A-V. Geometry unit test không chứng minh capture crop thật |
| R5 MEDIUM / production NOT VERIFIED | Mp4RecoveryEngine có helper nhưng chưa thấy production caller; startup cleanup journal không phải bằng chứng recovery engine được gọi | P1 fault test production capture journal→recovery/publish trên QA riêng, giữ input không đủ điều kiện; decode thật. P3 explicit export retry trong TASK09B **không đóng R5** |
| R6 MEDIUM / PARTIAL | Facecam/drawing có native engines/bridge; advanced UI/shared Settings và output parity chưa đầy đủ; floating controls **có own preferences** | Xác nhận camera permission/camera/layout, drawing palette/undo/pass-through, scale/opacity/position relaunch, ducking/crop/show touches/shake production callers |

Xem [handoff TASK09](TASK_09_P1_HANDOFF.md) để giữ toàn bộ repro/acceptance ban đầu. Không suy static R4 thành output đã đo lỗi, cũng không suy helper PASS thành feature DONE.

## Interface compatibility và việc có thể tích hợp

Không đổi capture method-channel/event/request-code/MediaStore contract. CaptureController onSaved → media refresh vẫn là đường source hiện có; recording URI → Library chưa được thử bằng real capture trong TASK09B. P2/P3 có thể dùng synthetic/native app-owned media để kiểm Copy/Move/Trash, draft, preview, ASR và export độc lập.

TASK09B đã kiểm real P3 export → MediaStore publication → đọc/decode độc lập, persisted SAF grant sau process death và production draft byte exact. Đây là P2/P3 evidence; không thay real P1 capture → editor E2E.

`models.dart` có một thay đổi shared file chỉ trong helper `_immutableEditorValue`: giữ null separator của drawing và deep-freeze dữ liệu P3. Field/settings/default/capture semantics ngoài helper phải khớp snapshot, được kiểm riêng. Các file bảo vệ còn lại byte exact; xem preservation manifest cuối trong [evidence](TASK_09B_TEST_EVIDENCE.md).

## Điều kiện chuyển TASK10

Người 1 cung cấp source/fix evidence R1/R2 và quyết định/acceptance R4/R5/R6; merge checkpoint ổn định không chồng dirty work; được cấp máy và permission plan cho MediaProjection/camera/microphone. Sau đó mới chạy real capture → Library → Editor/ASR → Export → Gallery, cùng ARM/OEM/physical QA. TASK09B không tự chờ hay sửa P1 để biến gate thành xanh.
