# TASK 09B — Source và tương tác runtime

Checkpoint: `main`, HEAD `9afcb124069d905dd4b285c890ca0709f5548b68`, cùng các thay đổi TASK09/TASK09B chưa commit. Không reset, merge, commit hoặc push. Đây là inventory có giới hạn quan sát, không phải chứng nhận mọi nút của app.

Evidence mới nằm trong [run TASK09B](../../build/verification/task09b/run_20261109T113727956224Z_f64203/). Xem [CSV chi tiết](TASK_09B_INTERACTION_COVERAGE.csv), [matrix](TASK_09B_SCENARIO_MATRIX.md) và [báo cáo cuối](TASK_09B_FINAL_REPORT_VI.md).

## Route graph đối chiếu source hiện tại

Router có **16 GoRoute declarations**: 2 redirect, 14 builder cho 13 loại screen; thêm errorBuilder. Create là action sheet, không phải tab/route độc lập.

```mermaid
flowchart TD
  Launch[Launcher / shortcut] --> Videos[/videos]
  Root["/"] --> Videos
  Completed[/recording/completed] --> Videos
  Shell[StatefulShell indexedStack] --> Videos
  Shell --> Photos[/photos]
  Shell --> Editing[/editor]
  Shell --> Settings[/settings]
  Videos --> Empty[/videos/empty]
  Videos --> Details["/media/:id"]
  Photos --> Photo["/photo-preview/:id"]
  Photo --> Tools["/photo-tools/:id"]
  Editing --> Project["/editor/project/:id"]
  Settings --> CaptureSettings[/settings/audio-video — P1]
  Settings --> Help[/help?topic=...]
  Settings --> Support[/support]
  Settings --> Trash[/trash]
  Settings --> Exports[/exports]
  Project --> Exports
  Create[Create sheet] --> Project
  Create --> Capture[P1 recording / screenshot consent]
  Unknown[Unknown route] --> Error[errorBuilder]
  Error --> Videos
```

Các cạnh là đường vào màn hình/flow, không thay thế toàn bộ stack pop/push. Năm route có identity theo tham số giữ nguyên patch TASK09: project, photo preview, photo tools, media details và Help topic.

| Surface | Owner | State/action đã có evidence | Phần chưa được suy thành PASS |
|---|---|---|---|
| Video/Photo Library | P2; capture hero P1 | Native 1.013 ảnh thật, search, 4 sort ảnh/5 sort video, giữ query qua tab; empty host; semantics động | Mọi provider/OEM và capture hero |
| Media Details/Photo Preview | P2 | Rename invalid/Cancel/Unicode; Copy qua DocumentsUI; Move Cancel; Trash/Restore; ảnh preview có pixel thật | Mọi tổ hợp seek/share, quyền app ngoài, mọi OS chooser |
| Editing Hub/project | P3 | Host draft/route/back; native drawing, subtitle/AI dialog, paused still preview; export native | Mọi tổ hợp timeline/layer/gesture |
| Photo Tools | P3 | Rotate, Undo, Keep editing, save JPEG 360×480, nguồn giữ nguyên; 12 locale/history labels | Human usability; mọi ICC/profile trên máy thật |
| Exports | P3 | Host lịch sử 0/20/21/77/100/1001; native journal recovery, explicit retry sau process kill | 1.001 lần encode thật; tự vá MP4 dở dang |
| Settings | Shared/P2; recording row P1 | Theme/language/storage/privacy/About/Help/Support/exports/trash; double-action guards | P1 preference semantics; mọi switch của capture |
| Help/Support | Shared/P2 | Route/topic regression, double tap, empty-report validation | Gửi báo cáo thật ra bên ngoài, xác nhận người nhận |
| Create | Shared + P1 | Open/Back/dismiss; host menu guards | MediaProjection/Facecam/capture acceptance |
| Trash | P2 | Native mới tạo: Trash/Restore byte exact; permanent Delete chỉ Cancel | Xóa media thật, expired user data cleanup |
| System surfaces | Android/P2/P3 | DocumentsUI Copy/Allow/Cancel; ACTION_CREATE_DOCUMENT Cancel/Save; persisted SAF grant sau process death | OEM/SD card; revoked grant trên dữ liệu người dùng |

## Mẫu số và giới hạn đếm

TASK09 có **419 source entries**: 292 declaration control/semantics + 41 helper callsites + 86 surfaces; native có 26 declaration/system entries. [AST source hiện tại](../../build/verification/task09b/run_20261109T113727956224Z_f64203/source_inventory_final_v3.json) kiểm lại vẫn đúng419/292/41/86, không parse diagnostic; owner P1=55, P2=62, P3=206, Shared/P2=96. Đây không phải419nút runtime. Mẫu số interaction/helper lịch sử là333. Không dùng tỷ lệ tap/source để kết luận toàn app.

[CSV TASK09B](TASK_09B_INTERACTION_COVERAGE.csv) có **15.156 dòng**:

- 251 dòng action group có assertion, **241 group duy nhất** theo ID/route/modality/viewport; một group có thể chứa nhiều thao tác. Retries không cộng thành tính năng mới.
- 12.098 Flutter semantic node-state observations, 2.802 Android interactive node-state observations từ 435 XML, và 5 dòng gate.
- Các node chỉ quan sát mang `OBSERVED / individual-node action mapping NOT VERIFIED`. Không gọi chúng là đã click hoặc đạt acceptance.
- Không có mẫu số “mọi logical control-state của toàn app” đã chứng minh đầy đủ. Vì vậy **không công bố % full-app coverage**. Unreachable/untested không được gộp thành PASS; xem matrix cho owner/cách đóng.

Locator CSV giữ node ID/key/label/role, bounds, route/state, modality, expected/actual và evidence. Flutter semantics có cả wrapper/passive nodes; Android XML là snapshot theo state, có thể lặp một control qua nhiều ảnh. Global probe ghi active URI; một số probe cũ dùng tên flow, phải đọc steps/assertions để hiểu route thật.

CSV là snapshot trước final package smoke. Smoke APK main bổ sung actual Android keyboard Help no-match/warm topic, Reset Cancel/preferences byte exact, launcher pin dialog Cancel và Photo Preview pixel/root Back. Những ca bổ sung có XML/PNG/trace riêng ở [test evidence](TASK_09B_TEST_EVIDENCE.md), không được tự cộng vào241groups của CSV hoặc ghi đè snapshot CSV.

Sau đó bổ sung2flow Photo/Video **Pin Confirm→actual Home icon→warm/cold launch** PASS; PID cold đổi, đúng Photo Library/Editing Studio, preferences byte exact. Giữ hai icon QA mới; không tạo lại icon khi harness Home-transition retry. Đây là native launcher evidence riêng, không chỉ gọi method-channel/mock.

## State/persistence và ownership

Settings document v2/migrations/defaults thuộc controller hiện tại; **settings_controller.dart không sửa**. Language chọn từ UI được read-back bằng controller mới; cold restart mọi locale riêng lẻ chưa có bằng chứng. Library dùng MediaScope/repository/MediaStore observer và SAF grants; source bytes được so với snapshot trước workload. Draft/export/ASR có journal riêng; fault test mới dùng queue context riêng và production draft mới, không thay live history.

P1 read-only gồm recording Dart/Kotlin, recording settings forms, MainActivity và Create capture semantics. `models.dart` chỉ đổi helper P3 `_immutableEditorValue` để giữ null separator trong drawing; không đổi field/default/capture semantics. Các file này được kiểm preservation riêng, xem evidence cuối.

Input thiếu cho nghiệm thu toàn app: Người 1 xác nhận/fix R1/R2/R4/R5/R6; QA người thật; ARM/OEM/SD/real16KB và capture consent trên thiết bị được phép. QA5560 giữ offline; emulator cá nhân 5554 không được target.
