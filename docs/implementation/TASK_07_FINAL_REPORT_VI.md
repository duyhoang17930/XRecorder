# TASK 07 — Báo cáo triển khai và kiểm thử P2/P3

Ngày08/11/2026. Working tree chưa commit trên HEAD
`b9aea926c1ab024dd32a139e5ab43b0e0e584908`. **G0–G5 đã thực hiện; G6 còn
gate hiệu năng OPEN; APK main và native accessibility đã kiểm. Không tuyên bố toàn app DONE.**

## 1) Đã làm

| Phần | Kết quả thực tế | Bằng chứng |
|---|---|---|
| G0 | Đọc yêu cầu/source, lưu working tree và17 hash P1; phân quyền ownership | [Baseline](TASK_07_BASELINE_AUDIT.md) |
| G1 | Flutter gen_l10n/intl,12 locale, Follow system/fallback English; UI và ASR language độc lập, persistence additive | [Matrix](TASK_07_GLOBALIZATION_MATRIX.md), `test/localization_test.dart` |
| G2 | Catalog đúng engine/model,99 mã khả dụng; Auto cho job mới, Base khuyến nghị; nhận dạng offline thật, không dịch sang English ngầm | [ASR contract/benchmark](TASK_07_ASR_CONTRACT_AND_BENCHMARK.md) |
| G3 | Unicode grapheme/split/merge/control validation, SRT UTF8, font fallback/cache, burn-in và preview thật |12 MP4/24 Android captures, `g3_outputs/` |
| G4 | Sửa overflow Trash/header, đơn vị lặp, native labels; đổi locale giữ editor/playhead/drafts/jobs |49 widget checks,108 actual Android screenshots |
| G5 | APK universal/split/AOT đo thật; phát hiện và từ chối partial ABI; không nhúng Whisper weights/corpus | [Size report](TASK_07_SIZE_REPORT.md) |
| G6 implementation | Sửa mất lịch sử quá20 job, journal readonly/corrupt/future, lưu lỗi có cảnh báo/retry; sửa startup race và preview seek/reload/black frame; RAM preflight có Android reserve | [Test evidence](TASK_07_TEST_EVIDENCE.md) |

Các backend editor/audio/photo/export hiện có được giữ lại và kiểm thử thực tế,
không dựng UI/mock thay export.12 file audio/layer xuất ra được giải mã và đo
gain/fade/mix/voice/noise/layer timing. EXIF1–8, ICC/sRGB/JPEG resize, mixed media,
speed-adjusted subtitle và ASR burn-in đều có file output kiểm tra độc lập.

## 2) Cái gì chưa

- **Hiệu năng không hồi quy: OPEN.** Cùng1013 mục gốc, p95 nearest-rank baseline
  build/raster4.636/41.426ms; trung vị ba lượt cuối8.202/45.602ms. Cache đúng giới
  hạn. Host dùng chung/SwiftShader và query thực tế1015 hàng chưa cô lập được
  nguyên nhân. Không ghi cải thiện full-library hay cam kết60fps.
- Human translation review, nghe âm thanh thực tế, usability/TalkBack với người
  dùng và đánh giá shaping bởi người đọc bản ngữ: **NOT RUN/PENDING**.
- Physical ARM/OEM/SD/thermal/long-running/16KB: **NOT RUN**. Runtime16KB x86_64
  đã chạy thật, không thay kết quả ARM bằng static alignment.
- Capture P1→editor→export: **P1 INTEGRATION OPEN**, chờ bản P1-ready bàn giao.
- Không fill volume hoặc xóa media để tạo low-storage test. Native capacity tests
  và real journal I/O-fault đã chạy; full-device ENOSPC chưa chứng nhận.

## 3) Có thay P1 không

**Không thay17 file P1/protected so với snapshot TASK07.** Bao gồm recording/**,
hai recording settings forms, Create sheet và MainActivity. Hash kiểm lại ở
`g6_delivery_integrity.json` lúc10:16. Không gọi capture để tự nghiệm thu P1.

`settings_controller.dart` được đọc từ working tree, sửa bằng targeted patches:
31 dòng bổ sung locale/speech preference; cached diff rỗng. Giữ fields, defaults,
migrations, corruption protection và recordingSnapshot. Không retry thao tác
overwrite bị từ chối, không lấy nguyên file từ HEAD, không reset/restore/checkout.
[P1 i18n handoff](TASK_07_P1_I18N_HANDOFF.md) ghi phần text thuộc Người1.

Không xóa source ban đầu, media, draft, model hay reference. Lưu ý riêng: writer
ASR cũ tự giữ20 job đã làm mất lịch sử QA API36 trong benchmark G2 trước khi được
phát hiện/sửa. **Không tuyên bố các job đã mất được khôi phục.** Media/draft/model
không bị xóa; API34 clone kiểm được11 job legacy thật là một dataset độc lập.

## 4) 12 locales thực trạng

`en`, `vi`, `es`, `pt_BR`, `fr`, `de`, `id`, `ja`, `ko`, `zh_Hans`, `hi`, `ar`:
resources/key/placeholders và layout matrix đã kiểm tự động; manual/generated
subtitle preview/SRT/MP4 đều chạy. Arabic navigation RTL, media/timeline/canvas
giữ LTR. Technical timestamps giữ ASCII, nhập số locale có parser kiểm thử.

English là source/fallback;11 bản dịch còn lại **REVIEW PENDING**. Draft translation
được tạo trên host, có provenance/license/glossary, không gửi media người dùng
lên dịch vụ và không được coi là bản dịch đã nghiệm thu. Chi tiết theo locale:
[globalization matrix](TASK_07_GLOBALIZATION_MATRIX.md).

## 5) ASR language coverage

Reuse whisper.cpp1.9.5 offline, Tiny/Base/Small-q5_1 multilingual. Catalog engine
100 mã,99 khả dụng với các model hiện tại; `yue` bị reject có chủ đích.12 ngôn ngữ
được chạy trên lời nói FLEURS có nguồn/license/reference, fixed và Auto.87 ngôn
ngữ khác có contract validation nhưng chất lượng **NOT VERIFIED**.

G2:41 scenario trước/sau;32/32 real transcript không đổi; noise/chord/silence có
text giảm4/9→0/9. Không suy bộ lọc RNNoise loại được mọi bản nhạc. Hindi/Base
trả Urdu-script trên mẫu này là lỗi accuracy thực, giữ nguyên output; Small có
Devanagari nhưng không chứng nhận luôn chính xác hơn. Chinese có thể Traditional.

G6 mới nhất:17 benchmark jobs/8 inference, cộng override/cancel/drain; cả3 model
EN/VI PASS, Base Auto PASS; cancel+drain543ms, job-list max116ms.77 job hiện tại,
57 job cũ giữ nội dung/metadata (technical restore phase và missing→null additive
field được ghi rõ). API34 clone11/11 genuine pre-TASK07 jobs giữ nguyên,6 payload
khớp benchmark cũ; không replay hoặc transcript giả.

Một lần2GiB/16KB bị Android LOW_MEMORY kill được giữ là thất bại. Đã sửa admission
budget; quan sát thực tế cả reject trước JNI và Tiny inference khi đủ RAM.3GiB/
16KB inference6351ms, storage retry/restart/Unicode export PASS. Không bảo đảm mọi
thiết bị2GB hoặc ngăn được mọi OS kill. [Benchmark và giới hạn](TASK_07_ASR_CONTRACT_AND_BENCHMARK.md).

## 6) File size

G6 release unsigned universal66.456MiB so với61.945MiB baseline (+7.282%);
true arm64 split23.746MiB. QA profile universal91.463MiB/arm64 split35.148MiB.
Font bundle compressed70031 bytes không tăng; không nhúng models/corpus.
[Size report](TASK_07_SIZE_REPORT.md) và `g6_artifact_manifest.json` ghi bytes,
SHA256, ABI/versionCode của từng artifact. Workspace/AVD/host models không phải
installed size. Tất cả8 artifact qua static packaging16KB/full ABI;3 release
split có DEX/AOT/Whisper khớp final universal.

## 7) Test evidence

Evidence local: `build/verification/task07/` (Git-ignored, vẫn giữ để đọc lại).

- Flutter:228 tests PASS1m51s; analyzer clean. Native:10 JUnit PASS46s.
- ARB validator12 locale PASS;49 layout checks;108 actual Android captures.
- Audio/layers:12 MP4 full decode/signal PASS; noise SI-SDR−5.003→3.037dB.
  Actual preview parity có negative control bắt black frame; chỉ loại outline
  ngoài cùng1px bằng option rõ ràng, kiểm layer trong khung; không chứng nhận
  pixel ngoài phần loại trừ hoặc human listening.
- Photo/subtitles:4 MP4 full decode;2x subtitle timing; EXIF1–8/JPEG/ICC PASS.
- Unicode:12 language SRT/MP4; SAF3494 UTF8 bytes read-back exact; native13 glyph
  probes không thiếu;16KB flash/tone A/V difference10ms, captions đúng on/off.
- Speech history:41-job restart;11 legacy API34 jobs;16KB five-job/settings
  restart; malformedJSON/UTF8/version99 readonly; write-failure/retry thật PASS.
- Native accessibility:4 nút Arabic nhận đúng framework accessibility focus,
  TalkBack còn bound/touch exploration enabled,4 screenshot có focus rectangle;
  quyền/flags và5 job giữ nguyên. Test dùng public API không suppress service,
  không coi gesture ADB/human listening là PASS.
- SAF mới:copy1474 bytes exact, disconnect rồi move bị reject trước publication,
  journal không đổi, giữ nguồn/bản sao. System UI ANR/Wait và UIAutomator137 của
  lượt này được lưu riêng; không giấu thành app PASS.

Lệnh/paths/failures/retests và giới hạn đều có trong
[TASK_07_TEST_EVIDENCE.md](TASK_07_TEST_EVIDENCE.md). Không lấy unit/screenshot làm
physical/human verification, không đổi lịch sử FAIL thành PASS.

## 8) QA APK

Đã build final `lib/main.dart` profile universal và true ABI splits, unsigned
release và true splits. Bản QA dùng SDK debug certificate, không phải production
signing. Integration fixtures/analysis partial-ABI không phải APK bàn giao.

- [QA universal91.463MiB](../../build/verification/task07/apk/3HRecorder-TASK07-QA-profile.apk).
- [QA arm64 nhỏ hơn35.148MiB](../../build/verification/task07/apk/3HRecorder-TASK07-QA-arm64-v8a-profile.apk).
- [Unsigned release66.456MiB](../../build/verification/task07/apk/3HRecorder-TASK07-release-unsigned.apk) chỉ để review packaging/size, chưa phải APK cài nghiệm thu.

QA5560 thiếu storage nên universal install bị từ chối; không xóa dữ liệu.
QA x64 split cài `install -r` thành công:77 job và116 project files byte-exact.
Universal cài/mở thật trên API34 và16KB:11 job legacy API34 và5 job16KB byte-exact,
giao diện Arabic trên16KB. Test native
focus4 nút với TalkBack hoạt động đã PASS; các lượt harness/gesture ADB thất bại
được giữ riêng. Không coi kết quả tự động là screen-reader usability với người dùng.

## 9) Blockers và giới hạn

| Gate | Trạng thái / cần gì |
|---|---|
| Same-corpus performance |OPEN: số đo cao hơn baseline; cần profiling cô lập/stable host và ARM thực để xác định/chốt |
| P1 end-to-end |EXTERNAL: cần P1-ready build; không chỉnh recording để vượt gate |
| Human translations/usability/audio |PENDING: người review bản ngữ, người dùng TalkBack và nghe file thật |
| Physical ARM/OEM/SD/thermal |NOT RUN: cần thiết bị phù hợp, không phải thiếu backend ASR |
| Old primary QA jobs pruned by former20-cap |Không có snapshot đủ để phục hồi toàn bộ; không dựng lại ID/transcript giả |

Approval quota trước đây đã reset và lệnh QA hiện chạy bình thường. Không bypass
approval hoặc xin quyền destructive. ASR/native implementation không bị ghi
BLOCKED giả vì chờ P1 hay vì chỉ thiếu human/physical acceptance.

## 10) Next task và refactor/cleanup

APK main G6 có size/checksum/runtime và native focus evidence; giữ performance
gate mở vì chưa có bằng chứng hết hồi quy. TASK08/09 tiếp nhận ARM/OEM/SD/thermal,
profiling ổn định và human language/accessibility/audio; TASK10 nghiệm thu luồng
capture thật sau P1-ready.

Đã gộp formatter benchmark vào harness library hiện có, chạy PASS rồi xóa test
standalone trùng của TASK07; bỏ nhánh legacy replay không dùng vì đã có dữ liệu
legacy thật. Đã xóa13 script migration dùng một lần của TASK07, giữ manifest
path/bytes/hash; xóa3 APK alias byte-identical đặt tên version không đúng, giữ
canonical artifacts. Native runner được giữ trong `tool/verify_task07_accessibility.py`
để tái chạy, có guard job/capture và output mới không đè bằng chứng cũ; xóa bản
runner trùng trong build. Generated localization/cache/log/APK giữ Git-ignored. Bảy tài liệu
TASK07 là yêu cầu bàn giao bắt buộc, không xóa để giảm số file. Các deletion HTML/
report generator có trước TASK07 được giữ nguyên, không tính là cleanup task này.
Không commit/push.

Checkpoint cuối: `git diff --check` PASS;17 hash P1 không đổi, không thiếu file
ban đầu, cached Settings diff rỗng, Settings31 dòng bổ sung. Main entry point đã
được cài lại trên cả ba AVD QA dùng trong task; đã dừng chúng giữ dữ liệu. AVD cá
nhân5554 không bị thao tác. Workspace logical40.922GiB (build35.499GiB,
`.dart_tool`4.799GiB), không phải dung lượng APK/cài đặt.
