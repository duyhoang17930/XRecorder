# TASK 09B — Acceptance scenario matrix

Đối chiếu đủ 35 hàng [checklist](../TASK_09B_ACCEPTANCE_CHECKLIST.md). Status ở đây là **toàn yêu cầu của hàng**, không phải từng happy path. PASS hẹp nằm trong actual/evidence; PARTIAL vẫn giữ các trạng thái chưa kiểm. P1 không được sửa, dữ liệu/evidence cũ không xóa.

Evidence mới: [run TASK09B](../../build/verification/task09b/run_20261109T113727956224Z_f64203/); evidence reuse: [TASK09](TASK_09_TEST_EVIDENCE.md). Mỗi test source/probe giữ preconditions, fixture, steps/assertions, expected/actual và finally/report; [CSV](TASK_09B_INTERACTION_COVERAGE.csv) gắn modality/locator/state. Không cộng retries và screenshot thành số acceptance cases.

| Case / owner | Status | Actual đã kiểm / evidence | Còn thiếu và cách đóng |
|---|---|---|---|
| S-01 Shared/P1 | PARTIAL | G1 host/native About/Help/storage/privacy/language/theme; controller read-back; persistence regression full suite; final main Reset Cancel giữ preferences byte exact | Mọi Settings recording control thuộc P1; notification/permission-manager mọi OS trạng thái chưa full |
| S-02 P1 | FAIL | Bốn Flutter test đỏ vẫn xuất hiện; R1 source giữ nguyên, R2 reuse khi P1 hash exact | Người 1 sửa và đưa regression evidence; không skip test |
| N-01 Shared | PARTIAL | Route identity/back/state host; 4 tab/Create nhiều locale; library query retention native | Toàn bộ interrupted navigation/reselect/resume permutations chưa test |
| N-02 P2/P3 | PARTIAL | Warm route/root Back/Save guards host + TASK09 native Help; paused still native mới; Photo/Video launcher Pin Confirm→tap actual Home icon warm/cold đều PASS, Cancel riêng PASS | OS stack restoration và cold entry Draft/Help mọi save/discard state còn NOT RUN |
| N-03 Shared/P2 | PARTIAL | Empty Support localized; rapid About/Help guard red→green; old Support busy/attachment host regression | Gửi báo cáo thật/share target receipt không được yêu cầu; native mọi attachment permission lỗi chưa đủ |
| N-04 each owner | PARTIAL | Dialog native G1/G3; Rename invalid/Cancel, Move Cancel, Trash Cancel/Confirm, Delete Cancel, JPEG Keep editing, SRT picker Cancel/Save | Không có exhaustive all-dialog/all-state acceptance; destructive user-data confirmations không chạy |
| M-01 P2 | PARTIAL | 1.013 real MediaStore PNG; 4 sort ảnh/5 sort video/search/tab retention; empty/one-item host; real new output | Folder/observer/provider mọi permission trạng thái chưa hết |
| M-02 P2/P3 | PARTIAL | Native Unicode Rename/Copy/Trash/Restore; paused preview pixel; source exact; old Details move-exit host | Mọi seek/share/screenshot/cross-app item ở native chưa full |
| M-03 P2 | PARTIAL | Native synthetic PNG+video Trash/Restore byte exact G2; UI Cancel/Confirm/Restore; no foreign cleanup | Expiry/missing/external OEM mọi UI state; permanent Delete chỉ Cancel có chủ đích |
| M-04 P2 | PARTIAL | Real DocumentsUI Cancel/Allow Copy; target/source SHA exact; backend negative/rollback host/native reuse | Revoked real grant/disconnected SD trên provider khác NOT RUN; chỉ fixture khi có thiết bị/grant |
| M-05 P2 | PARTIAL | G2 real Move qua actual grant, target verify trước source removal; process-death test giữ tree grant và read-back target SHA | Revoke/disconnect khi copy đang chạy trên physical/OEM chưa có máy |
| M-06 P2 | PARTIAL | 1.013 distinct source hashes/full PNG decode; controls run native PASS; controlled 320/411/font200 profile A/B ở G5 | SwiftShader raster không chứng nhận 60FPS/phone; số đo cuối tại evidence |
| D-01 P3 | PARTIAL | Host draft/trim/split/speed/history regression; production draft mới byte exact qua process kill | UI 50 Undo/Redo + mọi relink/merge/mixed permutations chưa đủ |
| D-02 P3 | PARTIAL | TASK09 actual native rapid preview/resource test; TASK09B paused still READY và screenshot pixel100% vùng oracle; active previews drain | Historic R7 ANR chưa reproduce; mọi SurfaceView race/human scrub chưa chứng minh |
| D-03 P3 | PARTIAL | Reuse TASK09 actual8tracks/13audio variants, voice presets/RNNoise signal oracles + new full regression | Nghe thật/A-V perception trên phone BLOCKED human; không dùng silence fixture làm audible sync |
| D-04 P3 | PARTIAL | Add drawing crash + null snapshot fixed; native gesture→draft→export; 480px pixel/PTS oracle; old timed overlays outputs | Mọi transform/z-order composition/time boundary chưa exhaustive native UI |
| D-05 P3 | PARTIAL | EXIF/ICC/photo backend reuse; native UI Rotate/KeepEditing/JPEG360×480, corner RGB/full decode/source bytes exact | Máy thật wide gamut/OEM và mọi quality/marks combination chưa đủ |
| D-06 P3 | PARTIAL | Native Unicode manual cue→Save SRT ACTION_CREATE_DOCUMENT Cancel/Save→verified read-back→Apply; old burn-in/retime tests | Mọi overlap/long text/style/timing edit UI state chưa full native |
| X-01 P3 | PARTIAL | Native journal recovery không Saved giả; queued/running process kill→Failed→explicitRetry→one published URI; host state/race/cancel | Power loss từng commit boundary và mọi UI finalizing/cancel interleaving chưa đủ |
| X-02 P3 | PARTIAL | Old22outputs/19MP4+GIF decode reuse; new60s640×480MP4 full decode/PTS/3time pixel, drift0,033401s | Encoder/FPS/bitrate toàn thiết bị và audible sync chưa đủ |
| X-03 P3 | PASS (fixture scope) | Real native journal sizes0/20/21/77/100/1001 restore/reopen + 6 ExportScreen mocked-bridge UI cases; retry correct ID/oldest reachable | Đây là history fixtures, **không phải1.001lần encode**; production provider-scale khác chưa claim |
| X-04 P3 | PARTIAL | 11native recovery cases incl malformed/corrupt/AtomicFile obstruction; actual process kill mid-encode on5570→retry; draft/source/main histories exact | Real disk fill/power loss và process kill từng save phase không làm để tránh rủi ro |
| A-01 P3 | PARTIAL | Wrong-model checksum reject; tiny import/remove/reimport; busy remove guard; download/cancel progress; giữ retained models | Full model download trên AVD BLOCKED DNS; local tiny/base/small benchmarks reuse, không upload/server |
| A-02 P3 | PARTIAL | Reuse real tiny/base/small vi/en/auto/silence/600s57cues + job retention/SRT/burn-in source; full regression | Music/timeout tất cả models và human accuracy corpus chưa đủ; không fake transcript |
| L-01 each owner | PARTIAL | 12locale realUI 320+411/font200; 4locale landscape; persisted preference fresh-controller read-back | Cold process restart từng locale, mọi plural/date unit state chưa full |
| L-02 each owner | PARTIAL | ar RTL native, ja/ko/zh runtime, Unicode/emoji Rename+SAF+SRT thật | Human bidi caret/selection/TalkBack order, native IME mọi scripts chưa đủ |
| H-01 each owner | PARTIAL | Semantics/labels/state, native XML/bounds, widget hit-test/validation, Light/Dark runtime | Full touch-area/contrast/focus audit chưa chứng nhận; small clipped XML bounds không tự làbug |
| H-02 External | BLOCKED human | Không có người thử/sign-off; emulator no-audio | Người thật TalkBack/gestures/one-hand/listening/scrub trên phone |
| P-01 P1 | BLOCKED P1 | Không capture; R1/R2 FAIL và R4/R5/R6 handoff | Người 1 readiness + QA capture consent được cấp |
| P-02 TASK10 | BLOCKED P1/device | P2/P3 synthetic flows không thay real capture E2E | P1 fix evidence + authorized phone/permission plan |
| Q-01 Entire task | PASS (audited scope) | Exclusive new artifacts, safe update/backups, source/fixture hashes; only new synthetic items mutate; no uninstall/wipe/clear | Không claim khôi phục lịch sử QA5560; final preservation manifest trong evidence |
| Q-02 External | BLOCKED device | APK ELF/ZIP16KB chỉ static packaging | ARM64/ARMv7/OEM/SD/real16KB/physical FPS/thermal/battery cần máy |
| Q-03 each owner | PARTIAL | Latest full Flutter317PASS/4P1FAIL; native137/137; Python12PASS; analyzer no issues ở checkpoint | Full app suite vẫn đỏ do P1; final commands/exit codes ghi riêng |
| Q-04 P2/P3 | PASS (QA package scope) | Fresh main.dart3ABIs,231payload hashes mỗi APK, debug cert/zipalign/ELF64 16KB/licenses verified; safe update5570 và6nhóm native main smoke đạt | ARM/runtime16KB/physical gates thuộc Q-02; không release signing |
| Q-05 External | BLOCKED | QA5560 offline, chỉ đọc hồ sơ host; recovery vẫn PARTIAL | Original snapshot/manifest còn thiếu và task cấp phép SAF manual reauthorization riêng |

## Gate và thứ tự

G1→G2→G3→G4 có các vòng native thực, fixes và regression tương ứng; G5 đã đo A/B, giữ tối ưu thumbnail nhỏ và build/verify/smoke main APK. Các row PARTIAL không được biến thành all-state PASS vì có screenshot hay backend test. Không có “FULL APP PASS”; điều kiện TASK10 hiện chưa đạt. Xem [báo cáo cuối](TASK_09B_FINAL_REPORT_VI.md) cho checkpoint và phần coverage còn thiếu.
