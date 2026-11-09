# TASK08 — Bàn giao chất lượng / hiệu năng

**TASK08 VERDICT: PARTIAL.** Đã triển khai và kiểm thử các sửa lỗi P2/P3 có
bằng chứng; không đánh dấu toàn bộ app DONE. Gate máy thật/P1 và khôi phục đầy
đủ trạng thái QA5560 còn mở. M0→M6 đã đi qua, bao gồm quay lại sửa regression
được phát hiện trong native QA thay vì chỉ ghi báo cáo.

## Source và phần đã sửa

HEAD `bad1dc30` + working changes TASK08; HEAD được cập nhật bên ngoài phiên
implementation, không phải commit do task này tạo. Không commit/push/signrelease
hoặc cleanup.18 hash P1/shared khớp snapshot đầu TASK08;589file ban đầu còn đủ,
Settings và stageddiff không đổi. Bằng chứng: `m6_source_integrity_v2.json`.

1. Thumbnail dùng key theo nội dung,giữ collision equality/size/revision
   semantics;không tăng cache vô hạn hoặc giảm chất lượng ảnh.
2. History không làm mất duplicate-ID khi restore; journal bất thường readonly.
   Thêm page/cursor ổn định,lọc project/source trước khi serialize;hộp phụ đề chỉ
   yêu cầu latest matching job. Không thêm retention cap hay đổi schema dữ liệu.
3. Trash chỉ cleanup tênUUID thuộc contract,giữ foreign model/input `.bin/.part`
   và JSON;red/green test thực,không xóa trash/media thật để test.
4. PCM sau trộn giữ đúng điểm kết thúc timeline;fix80.708→30.708ms A/V duration
   ở8tracks,có RNNoise/fades/voice/offset. Không nới tolerance hoặc bỏ effect.
5. Refactor chung vòng đời preview:drain playback looper rồi release cho cả
   reload/dispose,không tạo player sau disposed,chặn overlapping load và lỗi
   stale player. Trước sửa4reload thì2release failures;sau sửa30reload/seek thật
   PASS,0active/0failures. Sửa compatibility metadata với Media3 sau native
   preview phát hiện regression của endpoint guard.
6. Runner chỉ update install-r sau backup/margin/UID checks;không dùng SDK
   uninstall fallback. Evidence exclusive/versioned,tarSHA/EOF validation và
   snapshot one-use;reports không ghi đè khi chạy lại.

## Đo trước → sửa → đo lại

| Metric | Trước | Sau | Phạm vi |
|---|---:|---:|---|
|Library raster p95,320dp|42.101ms|22.856ms|Median5trials,1013same rows,3warmup|
|Library raster p95,411.43dp|42.151ms|26.242ms|Same corpus/order/viewport/profile|
|Decoded image cache|1000/~76.2MB|15/1481248B|17distinct controlled payloads,not all user libraries|
|History response1001jobs→latest|440628B|444B|Real StandardMessageCodec,metadata-only fixtures|
|8-track A/V duration difference|80.708ms|30.708ms|Actual MP4 decode;limit80ms unchanged|
|Reload release errors|2after4cycles|0after30cycles|Actual16KB/3GiB/8tracks/SurfaceView|

Build-time riêng INCONCLUSIVE vì baseline tự drift;không gọi toàn bộ cải thiện
build là do code. Raster vẫn vượt16.67ms ởp95 trên SwiftShader,không chứng nhận
60fps. Load→frame+seek30reload median1165.5ms,p952972ms vẫn là latency emulator,
không coi đã đạt tốc độ mong muốn trên điện thoại. Xem
[PERFORMANCE_BEFORE_AFTER](TASK_08_PERFORMANCE_BEFORE_AFTER.md).

## AI / audio / dữ liệu

-9inference Tiny/Base/Small EN/VI/Auto thật,model/cancel/import fault cases PASS.
  Tiny10cycles PSS boundary~80–82MiB,native allocated~5.7MB ổn định.
-Library finalGCsoak10vòng×30swipe,Arabic/Light/textScale2.0 thực:decoded16/
  1557056B không tăng;retained image classes giữ nguyên. Đưa full profilerDTO ra
  file giảm observer retention;heap21.77→22.73MB còn gồm compact summaries và
  testpointer records,không gọi whole-app leak-free hoặc production speed A/B.
-600s repeated real FLEURS:57cues,lastEnd600000ms,inference166443ms;không phải
  accuracy test cho hội thoại10min tự nhiên.2GiB/16KB foreground thực hoàn tất
  Tiny11s,inference3354ms. Cold-boot cached-process LMK và failure TASK07 giữ
  nguyên;không chứng nhận mọi2GiB máy đều an toàn.
-Finalv5:13audio MP4 full-decode/strictPTS/signals/pixels PASS;RNNoise SI-SDR
  tăng8.040dB;flash/tone cùng1.000s.4photo/subtitle/mixed MP4,EXIF1–8/P3/JPEG/
  speed-subtitle pixels PASS;edited-composition ASR được chạy lại trênv5.
-0/20/21/77/100/1001 metadata fixture jobs giữ đủ qua checkpoint/process
  restart,cursor ties/legacy/Unicode/fault cases PASS.19real global jobs API36,
  11legacy API34,5legacy16KB byte-exact ở integrity checks;không bịa transcript
  khôi phục. History registry vẫn load theo kích thước dữ liệu,không tuyên bố
  đã có disk-lazy indexing cho mọi history cực lớn.

**DATA toàn TASK08 vẫn FAIL/PARTIAL:** SDK installer trước đó uninstall QA5560
do thiếu storage.127privatefiles,77jobs,3models và54known external inputs đã
khôi phục có SHA/bytes evidence;không đủ pre-incident OS permission/ownership
backup để chứng minh full recovery. Các job cap20 làm mất từTASK07 không được
tái tạo giả. Cần người dùng kiểm/cấp lại quyềnSAF phù hợp và xác minh draft cũ;
không root/chmod/ép ownership. Xem [DATA_SAFETY](TASK_08_DATA_SAFETY_REPORT.md).

## Kiểm thử và APK bàn giao

Analyzer sạch;**231Flutter /12JUnit /9safety tests PASS** ở source cuối.
API36,API34 vàactual16KBx64 đã kiểm runtime currentv5;5navigation focus thực
PASS. Không gọi framework focus là human TalkBack/usability.ARM/OEM/SD/thermal
thật NOT RUN;P1 capture integration OPEN. Chi tiết
[TEST_EVIDENCE](TASK_08_TEST_EVIDENCE.md),[DEVICE_MATRIX](TASK_08_DEVICE_MATRIX.md),
[MEMORY](TASK_08_MEMORY_THERMAL_REPORT.md).

Main QA: `build/verification/task08/apk_v1/3HRecorder-TASK08-QA-profile-v5.apk`,
**89.774143MiB**,SHA256
`54501d9c54cdea939eb2a60ee2d1d2ad0ad015e1a4b0247c425b805f33748845`.
Đây là main.dart,SDK debug certificate,không phải integration-test entrypoint.
Sau final memorysoak,API36 đã update vềmainv5 bằng safe runner và mở kiểm lại;
19job journal/62source-model files còn SHA nguyên. Cả3QAAVD dùngmainv5.
Native locale cache đồng bộ ar→en theo main/system;app Settings document vẫn
không tồn tại trước/sau,không restore/overwrite Settings thủ công.
True x64 QA36.960357MiB;unsigned universal release66.580554MiB/arm64split
23.746024MiB.8APK static/64bit16KB/licenses PASS,4QA signatures verified;
release unsigned không được coi đã nghiệm thu runtime release.

Workspace106.963GiB logical chủ yếu backups/AVD/cache/evidence;không phải app
install size. Không xóa file/docs/fixtures trong TASK08 theo ràng buộc bảo toàn.
Xem [STORAGE_SIZE](TASK_08_STORAGE_SIZE_REPORT.md).

## Gate cần đầu vào ngoài task

| Gate | Cần gì để đóng |
|---|---|
|ARM64/ARMv7/OEM/SD/real16KB ARM|Thiết bị được cấp quyền;không mượn x64 làm PASS|
|Physical FPS/thermal/battery/TalkBack/HCI|Phone thật và phiên kiểm nghe/tương tác của người dùng|
|QA5560 full recovery|Kiểm quyềnURI/SAF/draft thực tế;không có đủ snapshotOS trước sự cố để tự tuyên bố khôi phục|
|P1 end-to-end|Person1 báo ready và người dùng bắt đầu nghiệm thu tích hợp|
|Whole-app leak certificate|Final harness đã đưa full profilerDTO ra file;vẫn cần native allocations/all flows/thiết bị thật;scoped cache/player/JNI checks không thay tất cả flows|

Tiếp theo:TASK09 Full Functional + HCI QA theo các evidence/limitations này;
TASK10 tích hợp P1 khi sẵn sàng. Giữ nguyên các failure logs và data checkpoints.
