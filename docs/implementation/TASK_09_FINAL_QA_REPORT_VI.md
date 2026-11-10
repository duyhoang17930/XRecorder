# TASK 09 — Báo cáo QA và sửa lỗi cuối phiên

**Kết luận: TASK09 full-app acceptance = PARTIAL. TASK10 READY = NO.** Đã sửa7 lỗi P2/P3 và giảm APK ARM64 từ48.54MB xuống36.37MB; còn lỗi P1 và các nhánh runtime/device chưa nghiệm thu. Không đánh dấu toàn app DONE.

HEAD đầu/cuối: `9afcb124069d905dd4b285c890ca0709f5548b68`, branch `main`; các patch chưa commit. Đã đọc ba tài liệu TASK09, source và báo cáo TASK07/08/P2/P3 có trong workspace. Giữ nguyên các tài liệu đầu vào và báo cáo cũ, không reset/restore/commit/push/merge.

## Những gì đã sửa

**7 lỗi sản phẩm P2/P3**, có red test trước sửa và green/regression sau sửa:

1. Export Retry bị snapshot Failed cũ ghi đè, không refresh lại Running.
2. Đổi effect nhanh gửi overlapping native loads, có thể bỏ lỡ composition cuối ở preview.
3. Warm route media/photo/draft/Help giữ State nội dung trước vì route key theo template.
4. Support nhận hai command khi nhấn nhanh trước frame tiếp theo.
5. Support báo lỗi attachment chung khi nội dung report trống; đã dùng thông báo validation đúng và catalog có sẵn.
6. App language accessibility target bị gộp với Theme; đã tạo semantics boundary đúng row.
7. Back từ editor/photo deep link root ném “There is nothing to pop”; Media Details sau move có cùng giả định history. Đã giữ pop khi có stack và về Library phù hợp khi là root, giữ save/discard guards.

Sửa thêm harness R3 bằng bounded pumps, vẫn giữ progress UI và Cancel guard; thêm QA tool guard từ chối5554/5560/recovery AVD trước mọi ADB. Tối ưu artifact APK bằng fresh ZIP bỏ payload orphan; verify231 live entries/ABI có SHA giữ nguyên, SDK alignment/signature và cùng debug cert đạt. Không sửa capture/recording của Người 1, MainActivity, Create capture semantics hoặc SettingsController/default/migration. Refactor hẹp: serialize/coalesce async operations và dùng chung `closeDetails` cho hai nhánh mutation exit; không đổi kiến trúc hoặc dọn/xóa tài sản người dùng.

Chi tiết source, repro, expected/actual và log đỏ/xanh: [Bug register](TASK_09_BUG_REGISTER.md).

## Kết quả thực thi

| Kiểm tra | Kết quả |
|---|---|
| Flutter analyzer | **PASS**, không issue |
| Full Flutter tests | **285 PASS / 4 FAIL**, cả4 FAIL thuộc P1 Recording Settings |
| Native JUnit thực thi lại | **137/137 PASS**, 22 suites,0 skipped |
| QA safety Python | **10/10 PASS** |
| Locale resources | **12 locales PASS** keys/Unicode/placeholders;49 host layout cases đạt trong phạm vi test |
| Native backend AVD mới | **6 ca đạt**: speech/audio/photo/media/rapid-preview/ASR600s |
| Kiểm output độc lập | **22 output SHA exact**, gồm19MP4+1GIF full decode/PTS đạt và1PNG+1JPEG |
| Main app | **10/10 nhóm walkthrough v4 đạt sau sửa fixture**,12/13 screen types được chạm native; compact v5 cùng payload và thêm3/3 smoke đạt |
| Native accessibility focus | **5/5 target đạt**, chưa có human TalkBack acceptance |
| SAF copy | **Copy thật qua DocumentsUI**, nguồn/đích3285B khớp byte; không move/delete nguồn |
| Dữ liệu QA update cuối | UID giữ nguyên;97/97 private file hashes exact ngay sau install; sau UI vẫn97 file,0 mất |

Whisper chạy thật on-device Tiny/Base/Small-q5_1, vi/en/auto; không paid API/server/transcript giả. Stress600s có57 cue đến600000ms, elapsed268423ms. WER trên **một** Vietnamese utterance: Tiny47.83%, Base17.39%, Small0%; không phải độ chính xác tổng quát. Audio validator chứng minh trim/fades/volume/mix8tracks/voice/noise/layers tác động file xuất; SI-SDR cải thiện8.04dB trong fixture. Sai lệch **thời lượng** A/V khoảng31ms không chứng nhận lip-sync bằng người thật.

Native missing-video/photo báo lỗi rồi phục hồi real preview frame, drain resources=0 lỗi. **R7 ANR lịch sử chưa tái hiện**, nên không ghi đã fix stale-draft/Trash/OEM ANR. GIF writer có file10frame/2s/loop2 giải mã được; mọi thumbnail/provider/progress combination chưa được nghiệm thu.

## Phạm vi coverage và phần còn mở

- Inventory hiện tại: **419 Dart entries** (292 control/semantics declarations,41 helper calls,86 surfaces) +26 điểm native/system; không coi là tổng nút runtime. Có13/333 interaction/helper source entries gắn tap native trực tiếp; P1 0/48, P2/P3/shared13/285. Không có mẫu số mọi dynamic instance đã xác minh để nói100% control coverage.
- 48 nhóm checklist rộng: **1 PASS / 41 PARTIAL / 2 FAIL / 2 NOT RUN / 2 BLOCKED**. Hai FAIL cùng liên quan R1/R2 P1; không phải hai bug mới. Các scoped tests đạt không tự khép mọi variant của một nhóm.
- **P1 PARTIAL**: R1 mở Settings ghi ngầm, R2 portrait disabled sai, R4 region origin chưa có pixel proof, R5 production MP4 recovery chưa nối, R6 advanced shared UI/model còn thiếu. [Bàn giao Người1](TASK_09_P1_HANDOFF.md) có source/repro/hướng sửa/acceptance; không sửa thay P1.
- **P2/P3 PARTIAL về acceptance toàn bộ**:7 lỗi xác nhận đã sửa; native Trash/Restore/expired/revoked/disconnected/SD, model download network mới,1001+ history/native1k library, kill giữa save/export, mọi effect/parity/timeline gesture còn chưa chạy hết trên HEAD này. Bằng chứng TASK08 giữ làm lịch sử, không đổi thành PASS mới.
- **Performance chưa đạt gate phát hành**: có native measurements/output correctness và memory samples; chưa có controlled Flutter raster A/B hoặc chứng nhận60fps. HWUI AVD SwiftShader ghi16/17 native frames janky (p95=150ms), mẫu nhỏ khác Flutter raster timing; đã giữ raw log, không che hoặc biến thành cải thiện hiệu năng. Peak sampled PSS toàn backend suite khoảng528.4MiB; chưa chứng minh leak-free/thermal trên máy thật.
- **Device gates**: chỉ AVD TASK09 API36 x86_64/page4KB; physical ARM/OEM/camera/mic/SD/real16KB/battery/thermal/human TalkBack chưa chạy. Static alignment APK không thay16KB runtime.
- **QA5560/TASK08 vẫn PARTIAL**: không boot/install/clear/run-as/root/chmod/grant hoặc sửa data. Cần snapshot gốc/quyền kiểm guest cụ thể; không tạo lại transcript hoặc metadata thiếu.

## QA APK và bảo toàn

APK bàn giao **compact v5** lấy toàn bộ live payload từ build **`lib/main.dart` v4**, profile QA.231/231 entry/ABI giữ SHA; SDK zipalign và cùng debug certificate đã verify. Đây không phải integration-test entrypoint hoặc APK TASK08 cũ, không có production/release signing:

| ABI | APK | Download bytes |
|---|---|---:|
| arm64-v8a | [QA APK ARM64 v5](../../build/verification/task09/run_20261109T091518633188Z/compact_qa_v1_30c4fe01e8834da983f97937d07a2074/TASK09-main-compact-v5-app-arm64-v8a-profile.apk) | 36,368,722 |
| armeabi-v7a | [QA APK ARMv7 v5](../../build/verification/task09/run_20261109T091518633188Z/compact_qa_v1_30c4fe01e8834da983f97937d07a2074/TASK09-main-compact-v5-app-armeabi-v7a-profile.apk) | 33,386,844 |
| x86_64 | [QA APK x86_64 v5](../../build/verification/task09/run_20261109T091518633188Z/compact_qa_v1_30c4fe01e8834da983f97937d07a2074/TASK09-main-compact-v5-app-x86_64-profile.apk) | 38,170,947 |

3 ABI qua libs/licenses/asset/ZIP+ELF alignment checks; runtime test chỉ x86_64. ARM64 giảm25.07%, ARMv7 giảm28.49%, x86_64 giảm24.37% so raw incremental v4; không có claim tăng FPS từ giảm ZIP bytes. [Manifest/recipe](../../build/verification/task09/run_20261109T091518633188Z/compact_qa_v1_30c4fe01e8834da983f97937d07a2074/manifest.json). Raw APK giữ nguyên; incremental cache có thể tạo orphan lại, nên dùng fresh packaging/recipe trước phân phối QA.

Installed compact v5 SHA khớp manifest; main UID10217/test UID10218 giữ nguyên. Installed APK allocation37128KiB; private QA844612KiB gồm models/import fixtures/evidence, không phải download size. Workspace/build/cache/AVD không được gộp thành dung lượng app.

Khi backup truyền thiếu, runner dừng trước install; giữ partial/log. Update cuối chỉ thực hiện sau backup97/97 file được xác minh bằng SHA với archive và các bản host giữ lại. Sau walkthrough chỉ framework `profileInstalled` đổi; không mất file. Source protection: snapshot33 file P1/shared so SHA;5 tài liệu untracked ban đầu giữ nguyên; không có xóa media/draft/evidence để dọn workspace. Native test không chạy lên5554/QA5560.

## Hồ sơ bàn giao

1. [Screen/control inventory](TASK_09_SCREEN_CONTROL_INVENTORY.md).
2. [Full-app QA matrix](TASK_09_FULL_APP_QA_MATRIX.md).
3. [Bug register](TASK_09_BUG_REGISTER.md).
4. [P1 handoff](TASK_09_P1_HANDOFF.md).
5. [HCI/accessibility](TASK_09_HCI_ACCESSIBILITY_REPORT.md).
6. [Commands/test evidence/failed attempts](TASK_09_TEST_EVIDENCE.md).
7. Báo cáo cuối này.

**TASK09: PARTIAL; P1: PARTIAL; P2/P3: PARTIAL (các fix có scoped PASS); TASK10: chưa bắt đầu.** Chỉ mở TASK10 khi Người1 xác nhận ready, R1/R2/R4/R5 được xử lý/kiểm lại và phạm vi thiết bị được xác nhận. Cần chạy merged capture→MediaStore→Library→Editor/ASR→export→Gallery trên HEAD đó; không dùng synthetic editor media để chứng nhận recording E2E.
