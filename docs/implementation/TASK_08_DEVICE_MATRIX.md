# TASK08 — Device matrix

09/11/2026. Chỉ xác nhận các flow đã thực thi; không gọi cả thiết bị/app DONE.
Tất cả Android runtime dưới đây là x86_64/SwiftShader, không phải ARM/phone FPS.
Current delivery source: QA **v5**, Media3 1.11.1,whisper.cpp1.9.5.
Final API36 main restore/launch/source-model-journal integrity:
`m6_api36_main_restore_v1/main_integrity_v2.json`;main screenshot inspected.
API34/16KB vàAPI36 đều kết thúc với mainv5,không để integration entrypoint.

| Device / configuredRAM / page | Actual checks | Verdict / evidence |
|---|---|---|
|API36 TASK08,5566,3GiB/4096B|M0/M1 controlled1013-image trials;final10library cycles textScale2.0;3-model EN/VI/Auto;10min actual inference;13audio+4photo outputs;main universalv5,preview pending/dispose,edited-ASR,5 navigation focus|PASS scoped; `performance/`, `memory/library_ar_light_200_v2/`, `memory/combined_media_memory_v3/`, `m6_api36_final_v1/`|
|API34 clone,5562,3GiB/4096B|Currentv5 main;realTiny foreground,8-track RNNoise MP4 decode/PTS/signal;preview/dispose/overlap;history0–1001,reopen;11 legacy jobs exact|PASS scoped; `m6_api34_final_v1/device_validation_v1.json`, `m4_api34_native_v1/`|
|API37.1 actual16KB,5564,3GiB/16384B|JNI Tiny,8-track MP4,history0–1001/reopen,foreign-trash;v5 actual30preview reload/seek and race checks;foregroundTiny;5 legacy jobs exact|PASS scoped; `m4_16kb_native_v1/`, `m2_preview_reload_16kb_v4_report.json`, `m6_preview_dispose_race_v1_report.json`|
|Same16KB,2GiB configured,OS2061701120B|Foreground Flutter verified;realTiny English11s,load339ms/inference3354ms,old5jobs exact|Controlled inference PASS; `m4_16kb_foreground_2g_v2_report.json`|
|ARM64 physical4/6/8GiB;ARM64 actual16KB|No authorized hardware|NOT RUN; static packaging is separate|
|ARMv7/API24–33 runtime|No available authorized target|NOT RUN; packaged ARMv7 is not runtime proof|
|OEM/SD/removable provider/disconnect|No actual removable/OEM target|NOT RUN|
|Physical FPS,heat,battery,spoken TalkBack,human HCI|No physical/human session|NOT RUN|

2GiB preflight observed949915648B available vs765475328B required,then real
inference completed; không phải simulated RAM/mocked transcript. Lượt cold-boot
đầu bị OS LOW_MEMORY khi instrumentation process còn cached importance400,
RSS130MB, trước tạo speech fixture/model inference. Logs/exit-info giữ nguyên;
test đổi thứ tự đưa Activity foreground trước UiAutomation, sau boot đã ổn định.
Warm success không xóa cold-boot failure hoặc chứng nhận mọi2GiB workflow.
LOW_MEMORY foreground316MB trong TASK07 cũng vẫn là failure lịch sử riêng.

Source/fixture roots tách khỏi user state; legacy19(API36),11(API34),5(16KB)
giữ nguyên bytes ở các integrity checkpoints. Update chỉ install-r sau backup/
margin/UID guard; không uninstall/clear/wipe/root/chmod.5554 không bị thao tác;
QA cũ5560 được giữ sau recovery, không dùng làm delivery acceptance.

`m4_nav_five_api36_v1/` và final navigation log kiểm focus framework đủ5 labels,
không phải nghe TalkBack hoặc user testing. Oracle cũ tìm4clickables có thể lấy
nhầm media card; TASK08 thêm mode lọc5navigationlabels, giữ log cũ để thấy giới
hạn.16KB main Arabic/RTL render có screenshot thật; phần English thuộc P1
giữ nguyên theo [P1 i18n handoff](TASK_07_P1_I18N_HANDOFF.md), không tự sửa.

P1 capture→Library→Editor→Export integration **OPEN** đến khi P1 ready và người
dùng khởi động nghiệm thu tích hợp; các pass độc lập không thay gate đó.
