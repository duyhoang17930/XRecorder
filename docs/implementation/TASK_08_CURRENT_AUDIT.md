# TASK08 — M0 source audit và checkpoint triển khai

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
