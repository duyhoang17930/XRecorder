# TASK 09B — Kết quả triển khai, G4 và G5

**Checkpoint ngày10/11/2026: G4 automated native đã hoàn tất; G5 có A/B performance, regression và QA APK chính. TASK09B / full-app acceptance vẫn PARTIAL, TASK10 READY: NO.** Không đánh dấu toàn app DONE khi P1, human/device và coverage còn thiếu bằng chứng.

HEAD `9afcb124069d905dd4b285c890ca0709f5548b68`, branch `main`, giữ dirty work. Không commit/push/merge/reset/restore. Không target emulator5554 hoặc QA5560. Native chỉ trên QA riêng5570/API36/x86_64; QA5560 recovery vẫn PARTIAL theo hồ sơ trước, không có guest thao tác mới.

## Kết quả thực tế

- **Sửa8lỗi P2/P3 có red→green**: duplicate About, duplicate Help, Add drawing intrinsic-layout failure, drawing null separators làm hỏng snapshot, export recovery báo Saved với published file rỗng, malformed recovery URI làm init export list thất bại, Undo/Redo translations trùng/sai nghĩa và crop translations sai domain. Sửa117values/13ARB; không đổi recording defaults/persistence/migrations.
- Native real UI: Rename/Copy/Trash/Restore, DocumentsUI grant/Cancel, Unicode SRT Save/Cancel/read-back, Photo Rotate/KeepEditing/JPEG save copy, drawing gesture→draft→export, paused preview pixel; model checksum import/remove/reimport/busy guard. Không fake backend/transcript hoặc paid API.
- **Process kill khi encoder thật đang chạy** → reopen failed/noURI → explicit Retry → đúng1publication; production draft/source và live journals giữ bytes. MP460s640×480 full decode/PTS/three-time pixels PASS; JPEG360×480 full decode/rotation colors PASS. Đây không phải partialMP4repair hoặc P1 capture recovery.
- Giữ toàn bộ7patch TASK09; thêm guard đồng bộ/modal helper/probe/reveal/frames dùng lại. Bỏ1driver screenshot mới không dùng sau archive/hash; không xóa docs/evidence/test cần thiết hoặc file có sẵn để giảm số lượng thay đổi.

## G4 riêng: ngôn ngữ, layout, accessibility

Đã hoàn tất **12locales ở320dp và411dp/font200**, thêm landscape920×411 cho en/vi/ja/ar, trên app/native bridges thật. Có actual tab/dialog/edit controls, persistence read-back, XML/PNG và assertions; failed harness attempts vẫn giữ, chỉ completed per-locale được tính. [G4 report](TASK_09B_GLOBAL_HCI_REPORT.md) ghi rõ từng run/locale/viewport.

**G4 không gộp với G5**: G4 đo runtime layout/interactions; G5 đo performance/build/regression sau đó. Cùng báo cáo cuối không có nghĩa cùng workload đo. Human TalkBack/listening/one-hand, bidi caret/selection và native-speaker linguistic review chưa có sign-off. Không ghi automated semantics thành human PASS.

## G5 riêng: performance và kiểm thử

Cùng corpus1.013PNG thật, cùng profile/SwiftShader/font200,2warmups+3trials mỗi viewport, mỗi trial30swipes. Thumbnail row thêm RepaintBoundary; giữ hình ảnh/quality/ripple factory và source bytes. [A/B raw](../../build/verification/task09b/run_20261109T113727956224Z_f64203/profile_ab_summary_v1.json), [decision/memory](../../build/verification/task09b/run_20261109T113727956224Z_f64203/profile_ab_decision_v1.json).

| Metric | 320dp trước→sau | 411dp trước→sau |
|---|---|---|
| Median raster p95 | **19,437→18,572ms (−4,45%)** | **19,985→19,248ms (−3,69%)** |
| Median build p95 | 4,809→4,542ms | 4,651→4,503ms |
| Raster frames >16,67ms | 173/1.874→146/1.839 | 222/1.786→180/1.844 |
| PSS sampled max | 190,64→187,47MiB | 192,75→187,81MiB |

Giữ patch nhỏ vì có cải thiện quan sát và không tăng memory trong workload. **Chưa đạt raster16,67ms, không claim60FPS**, không suy emulator thành physical GPU. Fixed-order/3trials không có randomized confidence interval; PSS samples không chứng minh không leak.

Startup đo thêm bằng `am start -W`, tách khỏi Flutter raster: [TASK09/current A/B](../../build/verification/task09b/run_20261109T113727956224Z_f64203/main_startup_ab_e0f130a1d7d448c88a1972f1e90153a3/startup_ab.json) median5.375/5.502ms,3samples mỗi bản, variance lớn. Startup vẫn chậm trên AVD; chưa chứng minh regression mới hoặc root cause, **không ghi startup optimized**. Backup mỗi install-r, same version/cert, Settings/draft/history hashes giữ nguyên; current main APK đã được trả lại.

| Kiểm tra | Kết quả |
|---|---|
| Full Flutter suite candidate được giữ | **317 PASS /4 FAIL P1**; không skip/đổi expected |
| Final analyzer | **No issues**, exit0 |
| Native JUnit fresh rerun | **137/137**,22suites,0skip/fail/error |
| Python installer/evidence safety | **12 PASS** |
| Focused locale/widget/layout | **80 PASS** |
| Main APK native package smoke | **6nhóm PASS**: cold launch, tabs/Create/Back, actual photo pixels/root Back, Reset Cancel/prefs exact, Android keyboard Help/warm topic, launcher shortcut dialog Cancel |
| Launcher shortcut bổ sung | **2flows PASS**: Photo/Video Pin Confirm→Home icon→warm/cold đúng màn hình, PID cold đổi, preferences exact; shortcut QA giữ lại |

Bốn Flutter FAIL là stale selection và Setup320/360/411dp thuộc P1. Analyzer lần đầu có braces lint trong harness mới, đã sửa/chạy lại; AST tool dùng package config sai đã sửa sang analyzer có sẵn trong SDK. Raw failed logs không xóa. Chỉ sửa braces của harness sau full suite, không đổi product behavior sau candidate317/4.

## APK QA để đọc/kiểm

Fresh `lib/main.dart`, profile/debug QA signing,3ABI. Mỗi APK231payload entries SHA exact sau compact, giấy phép/core libs/cert/zipalign/ELF64 16KB đều verified. Đây không phải release signing hoặc chứng nhận runtime16KB/ARM phone.

- [QA ARM64 APK](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-arm64-v8a.apk),36.438.354B.
- [QA ARMv7 APK](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-armeabi-v7a.apk),33.390.940B.
- [QA x86_64 APK](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-x86_64.apk),38.175.043B; current main được giữ cài trên5570.
- [Manifest/SHA/certificate](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/manifest.json), [build recipe](../../build/verification/task09b/run_20261109T113727956224Z_f64203/final_main_build_v3.py), [compact recipe](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_main_qa_v1.py).

## Coverage, dữ liệu và giới hạn

Source AST hiện tại vẫn419entries, không parse diagnostic. [Coverage CSV](TASK_09B_INTERACTION_COVERAGE.csv) giữ15.156rows, **241unique asserted action groups** và các observations tách riêng. Không phải15.156buttons đã test; không có exhaustive runtime denominator để công bố full-app %. Final package smoke có trace riêng, không ghi đè CSV snapshot.

[Preservation](../../build/verification/task09b/run_20261109T113727956224Z_f64203/preservation_final_v1_8a2a65dc5c05469daf3e38dfa69559e3.json): không mất file nào trong1.095original files;569oldTASK09evidence/2.548.967.105B và60host fixtures hash exact;32/33protected files byte exact, shared models.dart chỉ helper P3 drawing và mọi text ngoài helper exact. SettingsController giữ nguyên. Staged/conflicts rỗng ở checkpoint. Không suy host hashes thành đã phục hồi đủ QA5560.

[Matrix35requirements](TASK_09B_SCENARIO_MATRIX.md): **3PASS trong scope hẹp,26PARTIAL,1FAIL P1,5BLOCKED**. Matrix khác taxonomy TASK09, không so số row trực tiếp để tính tiến bộ. PARTIAL giữ rõ các tổ hợp UI/permission/restart chưa kiểm; không đổi thành PASS từ backend/screenshot đơn lẻ.

| Còn mở | Owner / cách đóng |
|---|---|
| R1/R2 +4tests; R4/R5/R6 capture contracts/runtime | Người 1: fix evidence/readiness; TASK09B không sửa P1 |
| Every-control/all-state UI completeness,50undo/relink/mixed combinations, mỗi locale cold restart | QA tiếp theo theo từng gap matrix; hiện **NOT RUN/PARTIAL**, không gọi external blocker giả |
| Model full download | AVD DNS HuggingFace lỗi sau attempts; checksum local import hoạt động; cần mạng/host/model được phép, không server upload |
| Revoked/disconnected SAF mọi provider,SD/OEM,ARM/real16KB/thermal/battery/physical FPS | Thiết bị/provider QA được cấp và permission plan; không dùng QA5560/5554 |
| Human TalkBack/gestures/one-hand/listening/scrub, linguistic review | Người thử/phone/sign-off; automated không thay thế |
| Startup5–8sAVD, historic R7 ANR | Profiling sâu/repro có trace; chưa quy root cause hoặc nói đã sửa |
| QA5560 historical data recovery | Hồ sơ vẫn PARTIAL; original snapshot/manifest và task SAF manual reauthorization riêng, không tự thao tác guest |

## Bộ tài liệu bàn giao

| Tài liệu | Nội dung |
|---|---|
| [Source/runtime inventory](TASK_09B_SOURCE_AND_RUNTIME_INVENTORY.md) | Route graph, ownership, phương pháp đếm và reachability |
| [Interaction coverage CSV](TASK_09B_INTERACTION_COVERAGE.csv) | Locators/states/modality/assertions/observations/evidence |
| [Scenario matrix](TASK_09B_SCENARIO_MATRIX.md) | Đủ35checklist rows, PASS/FAIL/PARTIAL/BLOCKED và phần chưa kiểm |
| [Bug register](TASK_09B_BUG_REGISTER.md) |8product fixes red→green, harness failures và open observations |
| [P1 handoff](TASK_09B_P1_HANDOFF_UPDATE.md) | Exact repro/source/4test names, interface và TASK10 gate |
| [Global/HCI](TASK_09B_GLOBAL_HCI_REPORT.md) |12locale runtime, viewport/theme/RTL và human gates |
| [Test evidence](TASK_09B_TEST_EVIDENCE.md) | Commands/results/output hashes/performance/APK/failed attempts |
| Báo cáo này | Kết quả tổng hợp và giới hạn nghiệm thu |

**Kết luận:** automated cases đã chạy đạt trong scope trừ4P1fail;8new P2/P3 defects tái hiện được đã sửa và regression đạt. **TASK09B: PARTIAL; P1: PARTIAL; P2/P3 tested-scope compatibility: PASS, full acceptance: PARTIAL; TASK10 READY: NO.** Chưa có real capture P1→Library→Editor/ASR→Export→Gallery hoặc human/device sign-off để đổi gate.

Kiểm cuối sau startup A/B và pin shortcuts: [preservation mới](../../build/verification/task09b/run_20261109T113727956224Z_f64203/preservation_final_v1_7929eb3d28a54024a61c275b8bdec6c9.json) vẫn PASS, HEAD/staged/conflict không đổi. Bộ8deliverables đọc UTF-8 hợp lệ, CSV có BOM cho Excel, đủ35checklist IDs và không có broken link ở lần validation. Không biến kết quả đọc UTF-8 thành chứng nhận font/phần mềm xem tài liệu trên máy người dùng.
