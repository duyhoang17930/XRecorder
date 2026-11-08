# P2/P3 — báo cáo chất lượng cuối

Ngày07/11/2026. Tiếp tục implementation từ `b9aea926c1ab024dd32a139e5ab43b0e0e584908`.
Không commit/push; không sửa Người1, không xóa media/draft/model/reference.

**DONE:** các sửa implementation và automated/native QA nêu dưới.
**PARTIAL:** nghiệm thu sản phẩm trên mọi thiết bị/giọng nói.
**NOT RUN / external gate:** máy thật, người thử/TalkBack, SD/OEM và full P1
integration; đầu vào cần thiết ghi rõ ở bảng cuối. Không có engine giả hoặc
backend P2/P3 bị chặn chỉ vì chờ Người1.

## Kết luận hiện tại

Đã sửa các lỗi tái hiện về preview, ASR queue/cancellation, metadata ảnh và giảm
chi phí raster của Library. Các backend P2/P3 có native output thật; **chưa chứng
nhận production-ready**. Kiểm thử máy thật, human listening/usability/TalkBack
gesture và full P1→P2→P3 còn mở. Native checks đã chạy trên AVD API36 và thêm
subset API34; APK `main.dart` debug và unsigned release đã build/kiểm packaging.

## Implemented and verified now

| Hạng mục | Sửa thực tế và bằng chứng |
|---|---|
| Library | Bỏ outer card clip dư, giữ thumbnail/ripple shape. Ba lượt cùng corpus mỗi phía: median raster p95 43,711→40,515ms, khoảng7,3%; cache không tăng. Vẫn quá budget60fps trên SwiftShader. |
| Native preview | Tái hiện khung đen dù player chạy; transparent shutter không sửa được nên bỏ. SurfaceView hybrid fallback hiện đúng video. Portrait theo display metadata/crop/rotation, giới hạn40% chiều cao viewport; bỏ kết quả poll/metadata cũ. |
| Preview lifecycle | Log soak lộ release timeout mà assertion activeViews0 trước đây bỏ sót. Lazy player allocation, pause+stop trước detach/release; chạy lại30 preview và20 export-cancel, releaseFailures0, median/max dispose489,5/741ms. |
| Audio/layers |12 output H.264/AAC thực, full decode/PTS/fade/mix/pitch/RNNoise/saturation/pixel PASS. Preview thực so file xuất tại800/1800/2500/3500ms; layer mask parity đạt với tolerance2px ở320×180, không tuyên bố bit-identical. |
| Input matrix |24/30/60fps, VFR, mono48k/stereo44,1k, rotation90, không audio, clip200ms; thêm H.264 và upstream HEVC B-frames. File xuất decode được. Flash/tone ở0,5/3/5,5s lệch0–10ms trên các fixture có audio. Stereo440/880Hz giữ riêng kênh;60→24 cap đúng. |
| Photo/subtitle |EXIF1–8 pixel và catalog display dimensions thống nhất; DisplayP3→sRGB, alpha/JPEG resize480×240, mixed image/video, long styled text, speed2 timing, edited audio→Whisper→SRT/burn-in PASS. Legacy GIF discovery có implementation/JUnit riêng. |
| Offline AI |38 native jobs trên12 stimuli,35 actual inferences; vi/en/noise/silence/music, timed cues bounds PASS. Invalid URI không còn giữ queued slot vĩnh viễn. JNI đo load/inference thật; completed trả đủ elapsed; restore đúng model/language. |
| AI cancellation |Đo worker drain+next silence decode9616→518ms, Cancel request2→8ms; callback được truyền vào CPU graph nodes bằng patch nhỏ có provenance. Sau patch9 vi/en/auto jobs trên cả ba model PASS; model cũ còn verified sau invalid/cancelled import. |
| Export recovery |Mô phỏng finalizing checkpoint của một job QA đã publish, rồi force-stop/restart thật: khôi phục cùng URI, không thêm output, draft/source bytes giữ nguyên. Không giả thành kill chính xác tại MediaStore commit instruction. |

Chi tiết: [baseline](P2_P3_FINAL_QA_BASELINE.md),
[performance before/after](P2_P3_PERFORMANCE_BEFORE_AFTER.md),
[AI evaluation](P2_P3_AI_SUBTITLE_EVALUATION.md),
[test evidence](P2_P3_TEST_EVIDENCE.md), [device matrix](P2_P3_DEVICE_MATRIX.md).

Default AI mới Base/VI: trên sáu utterance Việt sạch CER Tiny/Base/Small là
32,67/17,35/7,70%, median RTF0,614/1,646/3,405. Nếu chỉ Tiny đã cài, dialog dùng
Tiny. Corpus nhỏ, không annotate vùng miền, không đồng nghĩa accuracy chung.
Small tạo “(Bell)” trên music control; kết quả luôn cần review.

## Implemented but not independently verified

- Real pipeline/backend tồn tại, nhưng mọi OEM, codec profile,10-minute speech,
  long-form lip sync, pin/SAF provider và SD card chưa được bao phủ.
- RMS/spectral/SI-SDR/pixel checks không thay human listening hoặc subtitle review.
- Debug soak/native counters và heap inspection không chứng nhận không leak trên
  mọi máy. Không gọi PSS tăng là leak nếu chưa phân loại allocator/debug sources.
- Các test capture P1 trong host suite không thay runtime recording signoff.

## Not implemented trong đợt này

Không tạo renderer mới, accent classifier, paid/server fallback hoặc production
accuracy guarantee. Không mở lại chức năng livestream/Pro ngoài phạm vi prompt.
Không sửa capture để làm đẹp metric. Không thêm UI placeholder.

## External gates và điều kiện đóng

| Gate | Trạng thái / cần gì |
|---|---|
| ARM/OEM/32bit/legacy APIs chưa có image |NOT RUN: cần thiết bị hoặc AVD QA đúng API/ABI được cấp quyền. |
|60Hz/thermal/battery/10-minute AI |NOT RUN: cần máy thật và speech fixture dài được phép dùng. |
| Listening/usability/TalkBack gestures |NOT RUN: cần người thử với hai cỡ máy, tay trái/phải; dùng10 tác vụ trong docs/ui/USABILITY_TEST_VI.md. ADB taps không thay người dùng. |
| SD/disconnect/revoked provider ngoài QA |NOT RUN: cần SD/provider thật và grant hợp lệ; không bypass permission. |
| P1→P2→P3 |OPEN: cần bản capture của Người1 sẵn sàng và chạy end-to-end riêng. |
| Actual ENOSPC/power loss/exact mid-commit kill |NOT RUN: dùng bounded fault injection, không lấp ổ đĩa người dùng. Checkpoint replay đã chạy không đóng các ca này. |

## Checks, refactor và gói bàn giao

Checkpoint cuối: analyze sạch3,7s,143 unit/widget PASS26s;3 Android JUnit PASS,
không skip. Native suites và output validation ở các mục trên. API34 bổ sung
catalog/export/codec và6 VI/EN/auto Tiny/Base jobs, silence/cancel PASS. Attempts
lỗi/harness và System UI ANR giữ trong evidence, phân biệt với app failure.

| APK từ lib/main.dart | Bytes | SHA256 |
|---|---:|---|
| [QA debug](../../build/verification/final_p2_p3/apk/3HRecorder-QA-debug.apk) |192045080|`22a18591d30a949abf9daebed09a14a26cc50a4cfe3bc15cc4e482bd1c447a7e`|
| [Unsigned release](../../build/verification/final_p2_p3/apk/3HRecorder-QA-unsigned-release.apk) |64954063|`c53ebfa6023750d766a757b79a2ca4ed0be7b2037a599cfe9a74c0ffce6170cf`|

min24/target36; armv7/arm64/x86_64, JNI/libc++ đủ, MIT/BSD notices khớp source,
không bundle speech models; ELF/ZIP16KB và SDK zipalign PASS. Debug dùng certificate
debug chuẩn SDK; release unsigned, không dùng release signing credentials/publish.
Release không có integration-test plugin; debug có dev plugin nhưng kernel dùng
main.dart, không chứa marker test. Normal Flutter build đã sửa registrant stale
của attempt `--no-pub` đầu. Font warning Cupertino không dùng vẫn xuất hiện;
app dùng Lucide/Material đã package, không thêm dependency chỉ để giấu warning.
Release runtime chưa chạy vì đây là artifact unsigned theo yêu cầu; runtime QA
dùng debug APK. R8 giữ tên hai JNI classes; không lấy packaging PASS thay runtime
trên máy ARM/32bit hoặc thiết bị có page size16KB.

[APK verification](../../build/verification/final_p2_p3/apk/verification.json)
và raw logs nằm trong cùng thư mục. Không dùng APK integration làm APK bàn giao.

APK chính đã được cài lại bằng `install -r` trên AVD QA API34 và API36. Main APK
API36 đã mở đúng Video Library, Photo Library, Editing Studio và Settings qua
route thật; không gọi capture. Xem [main smoke](../../build/verification/final_p2_p3/main_smoke.json).
Read-back-verified finalizing checkpoint còn được replay trên chính main APK:
queue khởi tạo khi mở Export queue, trả lại cùng URI; mọi job khác, row count,
source và draft giữ nguyên ([proof](../../build/verification/final_p2_p3/publication/readback_replay.json)).

Refactor trong phạm vi: lifecycle preview rõ ownership; stage/timing ASR và queue
validation tập trung tại bridge; công cụ corpus/evaluator/sampler dùng chung,
không phụ thuộc artifacts benchmark cũ ở mode mới. Chỉ dọn report/generator cũ
trùng nội dung (`P2_P3_IMPLEMENTATION_REPORT_VI.html`, `tool/write_p2_p3_report.py`);
giữ prompts, canonical contracts/progress/evidence/reuse và dữ liệu. Năm file báo
cáo mới là outputs bắt buộc của prompt; evidence cũ được rút gọn và index lại.

16 file P1 được so SHA256 với baseline của chính nhiệm vụ này; MainActivity và
callback P1 giữ nguyên. Apparent code704 overlap dùng hai callback namespaces
khác nhau (permission vs activity result), không có bằng chứng cần sửa P1.
[Source integrity](../../build/verification/final_p2_p3/source_integrity.json)
ghi hash/code scope và hai file stale đã xóa. Tất cả source/media/model/draft
fixtures được giữ; API34 QA đã dừng giữ data, API36 QA đang chạy APK chính.
