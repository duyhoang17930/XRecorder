# TASK08 — M0 source audit và checkpoint triển khai

## Current09/11 — milestone checkpoint

Source hiệnHEAD `bad1dc30` + targeted working changes;HEAD thay bên ngoài task,
không tự commit/push. `m6_source_integrity_v2.json`:18protected hashes exact,
589initial files còn đủ,Settingsdiff/stageddiff empty,incident_image_paths.txt
103745B/SHA nguyên. Các mục08/11 bên dưới là lịch sử,không phải status cuối.

| Milestone | Kết quả hiện tại |
|---|---|
|M0|Rebaseline thực1013same rows;incident và recovery evidence giữ nguyên|
|M1|Content-key decoded-cache fix,RGBA regression và5trial/viewport;raster cải thiện,build effectINCONCLUSIVE|
|M2|3model/10min/10Tinycycles/8tracks thực;tailguard vàpreview lifecycle fixes;30reload0failure;freshGCsoak10cycles bounded images PASS|
|M3|Paging/latest matching,dedup readonly,foreign-trash safety;0..1001/restart/faults PASS;overallDATA vẫnPARTIAL|
|M4|Currentv5 API36/API34/actual16KB;2GiB actualforegroundTiny complete;physical/OEM/SDNOTRUN|
|M5|8currentv5APK build/static;4QAsignatures verified;release unsigned;no cleanup|
|M6|231Flutter/12JUnit/9safetyPASS;finalanalyze sạch;nativefinalv5 output/regression PASS;freshGC rawSHA exact;mainv5 restored/launch/integrity verified|

Current changes ngoài checkpoint trước:Native `EditorAudio/EditorComposition`
cap PCM sau mixer vàidentity timingmetadata theoMedia3,`EditorPreview` dùng chung
async drain/release cho load/dispose,guard pending/disposed/stale callbacks;
`TranscriptionBridge` page1..100,cursor(timestamp,id);dialog yêu cầu latest1.
QA/native fixtures vàvalidator/runner safety được thêm theo các defect thực.
Không đổi P1,applicationID,recording/muxer/permissions/defaults hay dependency.

Red→green quan trọng:8trackdrift80.708→30.708ms;unsupported-speed preview
metadata lỗi được actualSurface test bắt và sửa;old reload4cycles/2failures→
30cycles/0failures. Native overloading/dispose race PASS callback/no resurrection.
Full details/failed experiments: [TEST_EVIDENCE](TASK_08_TEST_EVIDENCE.md).
Current APK chỉ suffixv5;v1–v4 giữ để truy vết,không phân phối như bản cuối.

Verdict toàn task PARTIAL do QA5560 fullrecovery/physical/P1 gates;không dùng
native fixturePASS hoặc sourcehash để thay nghiệm thu capture/human.

08/11/2026, HEAD `b9aea926c1ab024dd32a139e5ab43b0e0e584908`, dirty working tree.
Task bắt đầu từ toàn bộ source TASK07 hiện có;589 file source/docs được chụp
SHA256 trong `build/verification/task08/initial_source.json`. Không có file nào
khác snapshot source cuối TASK07; hai tài liệu TASK08 là input bổ sung.
Patch unstaged/cached và status ban đầu được giữ riêng, không reset/overwrite.

## Ownership và ranh giới

18 file P1/shared được snapshot tại đầu TASK08 (`p1_before.json`), gồm toàn bộ
recording/**, hai recording settings forms, Create capture sheet, MainActivity
và shared domain models. Không sửa chúng. Settings/controller và31 dòng locale
bổ sung có trước task được giữ nguyên; không dựng file từ HEAD. Media, drafts,
model, reference, build/cache và báo cáo TASK07 không được phép dọn/xóa trong TASK08.
**Sự cố QA bên dưới vi phạm yêu cầu bảo toàn dữ liệu thiết bị; không được diễn
giải câu này là xác nhận không mất dữ liệu.**
Chỉ dùng AVD QA có tên/serial xác minh; không thao tác emulator5554.

Toolchain hiện có:Flutter3.47.8/Dart3.13.7, AGP9.1.0/Kotlin2.4.0/Gradle9.7.1,
Media3 1.11.1, whisper.cpp1.9.5; min24/target36. Không nâng dependency.

## Findings và hành động hiện tại

| Finding | Scope / hiện trạng | Hành động / bằng chứng |
|---|---|---|
| Duplicate ID trong journal bị bỏ qua |P0, `TranscriptionBridge`:putIfAbsent không kiểm kết quả; lần persist sau có thể mất record |Native fixture input2/listed1 đã tái hiện; targeted check chuyển journal sang readonly, chặn ghi; before/after PASS oracle |
| G7 library performance gate OPEN |Số lịch sử4.636/41.426→8.202/45.602ms không phải PASS TASK08 |Harness profile mới3 warmup+5 trials; freeze identity/order/timestamps/dimensions, raw frames/CPU samples |
| AVD low storage |QA API36/data còn~407–413MiB (~7%); có thể gây nhiễu môi trường |Ghi flags/disk, không xóa dữ liệu hoặc tự kết luận nguyên nhân |
| Lịch sử tăng1000+ |Hiện không còn cap20, nhưng snapshot/persist/list toàn bộ; chi phí chưa đo |M3 sẽ đo capacity/pagination/restart, không gọi giữ77 là proof1000 |
| Native resource/memory lifecycle |P2 preview/release và RAM preflight đã có, số G7 là historical |M2/M6 phải chạy lại với source TASK08 và output thật |
| ARM/OEM/SD/thermal |Không có thiết bị thật đã được chỉ định |NOT RUN, không lấy x86_64 thay thế |

P0 exception được làm trước M1 theo prompt: native test tạo journal trong một
thư mục fixture mới bằng ContextWrapper; không thay journal của77 job thật.
`m0_duplicate_before.txt` ghi FAIL2→1; `m0_duplicate_after.txt` PASS readonly,
write-reject và exact bytes. `m0_history77.json` vẫn byte-exact sau cả hai lượt.
Không tạo transcript hay giả phục hồi các job từng mất bởi writer cap20 cũ.

## Source changes TASK08 đến checkpoint này

- P2 `TranscriptionBridge.kt`:chặn duplicate identity khi restore, giữ nguyên
  file unreadable thay vì cho snapshot thiếu record ghi đè lần sau.
- `androidTest`:case duplicate fixture; runner hiện có dispatch theo
  `-e task08 history`, hành vi mặc định TASK07 accessibility được giữ lại.
- `integration_test/task08_performance_test.dart`:benchmark có corpus/metadata,
  viewport số thực, query/cache counters, CPU sampling và raw frame timings.

Failed harness attempts được giữ: AGP đã thay tên instrumentation đầu trong
manifest nhiều runner, nên chuyển sang dispatch; `flutter drive` không nhận
`--build-number`, nên build profile fixture4001 trước và drive bằng binary đó.
Analyzer ban đầu báo3 info; sửa braces/API getIsolateId rồi analyzer sạch.

## Sự cố installer QA và khôi phục

`m0_profile_320_bounded.log`: Flutter SDK gặp
`INSTALL_FAILED_INSUFFICIENT_STORAGE`, tự gọi uninstall rồi cài lại dù có
`--keep-app-running`. Flag này chỉ bảo vệ lúc kết thúc drive, không bảo vệ
nhánh install-failure. UID QA5560 đổi u0_a217→u0_a219; private/no_backup và
app-specific external bị mất. Không xảy ra trên emulator5554. Đây là lỗi thao
tác harness TASK08, không được che thành PASS hoặc cho là lỗi P1.

Đã khôi phục127 file private từ tar chụp trước task, so byte từng file, gồm
116 file project và77 speech/model job. Ba model Whisper khớp SHA256 bản gốc
host,54 external fixture khớp retained host input.1013 ảnh public giữ đúng
ID/size/revision. Chưa có checksum toàn bộ external trước sự cố; Android
persisted URI grants/ownership chưa chứng minh khôi phục, nên **full recovery
chưa được xác nhận, DATA gate FAIL/PARTIAL**. Không bịa các job bị cap20 làm
mất từ TASK07. Xem `incident_*recovery.json` và public_catalog_comparison.

Runner mới `tool/run_qa_existing_app.py` dùng update adb riêng, backup trước
install, kiểm free-space và UID, abort khi lỗi rồi attach Dart driver vào VM.
`tool/verify_ui.ps1` chuyển qua runner này, không gọi Flutter install fallback.
AVD TASK08 riêng5566/data16GiB chứa bản sao fixture; AVD5560 được giữ nguyên đĩa
sau khôi phục, trả viewport gốc và dừng để tránh tiếp tục tác động.

Baseline cũ chưa hợp lệ: lượt đầu hoàn tất assertions native nhưng host driver
timeout; phục hồi JSON gặp OOM vì function table CPU quá lớn. Lượt thứ hai dừng
ở thiếu manifest sau uninstall, không có timing hợp lệ. Evidence thất bại được
giữ đầy đủ. Harness mới chỉ giữ một trace và function table được remap đúng
sampled stack, vẫn giữ raw frames năm trials.

M0 profile baseline chưa hoàn tất. Chưa đánh dấu PERFORMANCE/MEMORY/DATA/DEVICE DONE.
Đi tiếp M1→M6 sau các checkpoint có bằng chứng, giữ mọi failure và external gate.

## Checkpoint M0/M1 sau yêu cầu safe evidence

Frame baseline320/411 hoàn tất, mỗi viewport3warmup+5trials. New QA5566 có1013
app-owned source/readback verified images; full metadata/order hash đồng nhất.
M1 decoded-content key fix có regression đỏ→xanh, analyzer clean và A/B thật:
median raster p95320:42.101→22.856ms;411:42.151→26.242ms. Xem hai report
TASK_08_PERFORMANCE_BASELINE/BEFORE_AFTER cho raw paths, limitations và corpus
chỉ17 payload khác nhau. Không sửa DateFormat hay P1 do thiếu root-cause proof.

Đối chứng baseline411 tiếp tục chạy; không restart các baseline đã hoàn tất.
M2–M6 chưa DONE. DATA vẫn FAIL/PARTIAL do SDK installer incident; không dùng
frame improvement để che mất dữ liệu/quyền QA. `incident_image_paths.txt` được
giữ nguyên103745B, SHA256657124c3…; cấm redirect overwrite, mọi artifact tương
lai dùng version riêng + exclusive create, collision phải dừng.

## Checkpoint tiếp tục 09/11 — M2 / history pagination đang triển khai

HEAD hiện tại `bad1dc3` do bên ngoài phiên implementation cập nhật; working tree
sạch khi tiếp tục. Không tự commit hoặc dựng lại source từ HEAD.18 protected
P1/shared hashes vẫn khớp snapshot TASK08; evidence cũ được giữ.

- Đối chứng drift M1 đã hoàn tất, xem BEFORE_AFTER: raster cải thiện, tác động
  riêng lên build-time INCONCLUSIVE, không kết luận60fps.
- Library Arabic/Light/font200%,10 vòng×30swipe: decoded cache15entries /
  1481248B ở cả10 vòng; retained image/provider counts sauGC ổn định. Tổng
  Dart heap tăng có profiler DTO/pointer records do harness giữ; chưa chứng
  minh toàn app leak-free. Raw `memory/library_ar_light_200_v1/`.
- Native preview trước sửa timeout release ở cả có/không PSS profiler.
  Patch drain playback looper trước release đã PASS30preview/20export-cancel:
  `memory/editor_soak_v3_offline_checkpoint_v1/emulator_verification.json`,
  active0/releaseFailures0/sourcePreserved true. Dispose median605ms,
  p954462ms,max4520ms; vẫn có latency emulator đáng kể. Không dùng peakPSS
  đơn lẻ để chứng nhận không leak; reload và physical gate còn riêng.
- Trash P0: chỉ xử lý tênUUID thuộc trash contract; foreign `.bin/.part/.json`
  không còn bị auto-cleanup. Red/green native fixture giữ tại
  `m2_trash_foreign_red_v1.txt` / `m2_trash_foreign_green_v1.txt`.
- History matrix lần đầu FAIL do fixture `.new` bị AtomicFile.openRead dọn
  trước write; đã chuyển fault injection sau restore. Chưa tính PASS.
  Bổ sung truy vấn page có cursor(timestamp,id),limit1..100; hộp phụ đề yêu
  cầu latest matching job thay vì chuyển mọi transcript. Chờ native tests.
- Bộ Whisper3model/audio13output/photo/10min input đang chạy trong một APK:
  `M2-combined-media-memory-v1.apk`, SHA256
  `fa65b841625272daf0fa8d3fab372c957ed68c6f170e267811dc76f13cf1b8c1`.
  Đây là **test-entry APK**, chưa phải bản main bàn giao. Production binary
  của APK ở HEADbad1dc3; patch pagination sau đó chưa nằm trong APK này.

Backup ADB lớn từng trả truncated payload kể cả exit0; runner từ chối trước
install bằng size/SHA/tarEOF. Không bỏ kiểm tra. Whole offline AVD checkpoint
v2 được copy sau QEMU thoát, source/copy SHA exact; bao gồm MediaStore/OS grants.
Lần boot đầu stopped-state chưa persist nên guard chặn install; đã chờ Android
persist12s rồi tạo **snapshot mới**, giữ snapshot lỗi cũ. Một lần launch trước
boot-ready cũng dừng trước install. Lượt `combined_media_memory_v3` sử dụng
`offline_checkpoint_v2_20261109T034847Z_fa387232/checkpoint_manifest_v2.json`.
Mọi evidence này nằm dưới `build/verification/task08/`; không restore snapshot,
không uninstall, không thao tác5554. DATA toàn task vẫn FAIL/PARTIAL do incident.
