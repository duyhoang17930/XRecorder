# TASK 09 — Ma trận QA đã đối chiếu source

HEAD `9afcb124069d905dd4b285c890ca0709f5548b68`, có các sửa TASK09 chưa commit. File checklist đầu vào tại `docs/TASK_09_FULL_APP_QA_MATRIX.md` được giữ nguyên; đây là kết quả riêng. `PARTIAL` nghĩa chỉ các nhánh ghi rõ đã đạt, không phải mọi control/state của feature đều PASS. P1 chỉ audit/test và bàn giao.

Tham chiếu evidence: **H** = [full Flutter cuối](../../build/verification/task09/run_20261109T091518633188Z/final_flutter_v4.log); **N** = [6 ca backend native](../../build/verification/task09/run_20261109T091518633188Z/backend_native_v1/emulator_verification.json); **U** = [walkthrough main v3](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_2d19ec37ab3b4bab902f02d252c7e066/trace.json); **B** = [bug register](TASK_09_BUG_REGISTER.md); **P** = [handoff P1](TASK_09_P1_HANDOFF.md). Lệnh và các thử lỗi nằm tại [test evidence](TASK_09_TEST_EVIDENCE.md).

| testID | Screen / owner | Event và expected | Loại test, kết quả thực tế | Status | Evidence / bug / phần chưa chạy |
|---|---|---|---|---|---|
| NAV-01 | Startup / shared | Cold/warm launch, resume/restart, lỗi route có lối thoát | Host router + native main cold launch; state private giữ nguyên qua update | PARTIAL | H, U; không phải toàn bộ permission/process-death matrix |
| NAV-02 | Bottom nav / shared | Video/Photo/Create/Edit/Settings, reselect và giữ state | 5 target focus thật; 4 tab + Create/Back native; host reselect/search/scroll | PARTIAL | H, U, native_focus_navigation_v1.json; mọi tổ hợp loading/back-stack chưa đủ |
| NAV-03 | Create / P1/shared | Mỗi CTA đúng tác vụ, close/back và coalesce | Host Create→setup/close; native open/dismiss, không start capture | PARTIAL | H, U; capture CTA native NOT RUN |
| NAV-04 | Deep links/shortcuts / P2/P3 | Cold/warm và target identity, không capture ngoài ý muốn | 5 warm identity + 3 root exit regressions; native warm Help; static shortcut manifest | PARTIAL | H, B T09-P23-03/08; launcher pin cold/warm chưa nghiệm thu đầy đủ |
| P1-01 | Recording controls / P1 | Start/pause/resume/stop/rotation/audio/double-start | Contract/controller host và source audit; không ghi thật | NOT RUN | P; không suy mock recording thành capture runtime PASS |
| P1-02 | Setup/settings / P1 | Mọi option đúng capability, mở-only không ghi ngầm | 4 host tests FAIL; portrait probe tái hiện disabled sai | FAIL | H; R1/R2, P1 HANDOFF |
| P1-03 | Screenshot / P1→P2 | Consent/cancel/revoke, PNG thật, result delay | Host screenshot semantics/result UI; native capture không chạy | NOT RUN | P; latency 3s trên HEAD này chưa đo |
| P1-04 | Floating controls / P1 | Permission/show-hide/drag/controls/background | Source + geometry/contract JUnit; own preferences hiện hữu | PARTIAL | P R6; native overlay/capture NOT RUN |
| P1-05 | Facecam/draw / P1 | Camera permission, drag/size/persist/output | Source + geometry/stroke/bridge tests | PARTIAL | P R6; camera/output/native UI NOT RUN |
| P1-06 | Region / P1 | Crop đúng origin và pixels | Source path không thấy apply crop origin; geometry JUnit đạt | PARTIAL | R4 HANDOFF; pixel capture oracle NOT RUN |
| P1-07 | Recording recovery / P1 | Startup journal gọi recovery an toàn, không false Saved | JUnit helper đạt; production caller chưa nối | PARTIAL | R5 HANDOFF; interrupt capture runtime NOT RUN |
| MED-01 | Video Library / P2 | Empty/populated, auto-index, 5 sort/search/retention | Host các sort/state; native thấy 20 output video mới | PARTIAL | H, N, U; không chứng nhận native 1k+ hay mọi denied state |
| MED-02 | Photo Library / P2 | Thumbnail/rotation/GIF/separation/actions/RTL | Host + native tab; ảnh và GIF native xuất thực, byte checks | PARTIAL | H, N; không coi mọi item/context action đã click |
| MED-03 | Detail/preview / P2/P3 | Đúng item, play/seek, thiếu file có retry | Warm identity host; native details/SAF; missing source video/photo recovery thật | PARTIAL | B T09-P23-03/08, R7; player/TalkBack/lifecycle toàn bộ chưa đủ |
| MED-04 | Rename/Trash/Restore / P2 | Confirmation, ownership, byte exact, không double-submit | Native rename mới + invalid name/source preserved; host control guards | PARTIAL | H, N; current-head native Trash/Restore/expired/provider variants còn NOT RUN, không dùng lại PASS TASK08 |
| MED-05 | SAF / P2 | Chọn folder, copy/move, revoked grants, source-safe ordering | **Copy thật qua DocumentsUI**, folder QA mới, SHA nguồn=đích; host cancelled picker/transfer contracts | PARTIAL | saf_copy_verified_v1.json; move/revoked/disconnected/SD native chưa đủ |
| MED-06 | Library 1k+/performance / P2 | Lazy list/cache/coalescing, scroll và raster | Host bounded cache/lazy queries/late results; native thư viện nhỏ | PARTIAL | H/performance_test; native 1k+ raster profiling NOT RUN, không claim 60fps |
| EDI-01 | Projects / P3 | New/open/rename/duplicate/delete/migration/save-error | Host guards/autosave/retention + native save/find/reopen draft | PARTIAL | H, N, B root exit; kill-while-write/UI mọi trạng thái chưa đủ |
| EDI-02 | Timeline / P3 | Trim/split/reorder/merge/duplicate/relink/crop/flip/rotate/speed | Project/controller/effects host; native mixed image/video/speed output | PARTIAL | H, N; không dùng export fixture thay mọi timeline gesture |
| EDI-03 | Preview / P3 | Effect cuối hiển thị, seek giữ, lỗi nguồn/dispose recovery | Native rapid speed 2× → duration 2000 ms/frame thật; video/photo missing recovery, resource drain | PARTIAL | B T09-P3-02/R7; ANR lịch sử NOT REPRODUCED, Trash sequence chưa khép |
| EDI-04 | Audio / P3 | 8 tracks/trim/offset/fades/mix/voice/noise thực sự tác động output | Native 13 audio outputs + signal/trim/frequency/SI-SDR/AV duration/full decode | PARTIAL | decoded_outputs_v1/audio/signal_validation.json; human listening/lip-sync NOT RUN |
| EDI-05 | Layers / P3 | Text/sticker/drawing/transforms/duration/order/parity | Host validators/UI + native pixel differences đúng thời điểm | PARTIAL | H, N, audio signal layerDifferences; preview/export pixel parity mọi tổ hợp chưa đo |
| EDI-06 | Subtitles / P3 | Cues/timing/split/merge/style/long text/SRT | Host Unicode/overlap/timing; native 2× timing pixel checks/SRT/burn-in | PARTIAL | H, N, decoded_outputs_v1/photo/validation.json; clipboard/create-document từng provider chưa chạy hết |
| EDI-07 | Exports / P3 | Queue/run/finalize/cancel/retry/failed/completed, Saved sau commit | Host R3 + refresh race; native export queue/cancel/retry + mở history | PARTIAL | H, N, U, B T09-P3-01; 1001+ metadata/fault runtime chưa chạy lại |
| EDI-08 | MP4/GIF / P3 | Output thật, FPS/size/PTS/audio/source integrity | **19 MP4 + 1 GIF** full decode/strict PTS; GIF 10×200ms/loop=2, latest rapid export 2s | PARTIAL | decoded_outputs_v1/*/validation.json; input matrix/thermal/physical A/V sync chưa chạy lại |
| PHO-01 | Photo tools / P3 | Crop/rotate/flip/marks/undo-redo/save copy/dirty exit | Host pixel transforms/annotations/guards; native JPEG/EXIF + source protection | PARTIAL | H, N, B root Back; mọi tool/color/shape gesture native chưa đủ |
| PHO-02 | Photo formats / P3 | EXIF1–8, sRGB, PNG/JPEG/resize/corrupt/large | Native EXIF1–8 + wide profile pixel error 0; JPEG 480×240 giải mã độc lập | PARTIAL | N, decoded_outputs_v1/image_validation_v1.json; boundary sizes/provider variants chưa đủ |
| ASR-01 | Speech setup / P3 | Model/lang đúng, <=10min, RAM check | Native Tiny/Base/Small-q5_1, en/vi/auto; 600000ms chạy thật; 600001ms bị từ chối | PARTIAL | N, asr_metrics_v1.json; tất cả duration/device RAM boundaries chưa đủ |
| ASR-02 | Models / P3 | Import/download/hash/progress/cancel/delete/offline | 3 real models import+verify, corrupted input faults, active-model remove bị chặn, native cancellation | PARTIAL | N.speech; network download mới trên HEAD này NOT RUN, không lấy lịch sử làm mới |
| ASR-03 | Jobs / P3 | Start/progress/cancel/drain/silence/checkpoint/project match | Real inference + cancel/drain + silence không transcript; job files byte-exact qua update | PARTIAL | N, backups; process kill mid-inference/UI every state chưa chạy lại |
| ASR-04 | Edited audio→SRT/burn-in / P3 | Transcript native có timed segments, export thật | Recognized JFK SRT + audio composition/burn-in MP4; 57 cues đến 600000ms ở stress | PARTIAL | N.photo/longSpeech, output validators; corpus quality rộng/giọng vùng miền chưa chứng nhận |
| SET-01 | Settings/Help/About / shared | Mỗi row/nav/dialog/back có phản hồi đúng | Native theme/language/storage; host Help/search/Support; không ghi P1 | PARTIAL | H, U; about/licenses/reset confirm và mọi row native chưa đầy đủ |
| SET-02 | App preferences / P2/shared | Theme/locale explicit, save/restart/defaults không mất data | Settings persistence regression + locale/theme layout; native theme selected values | PARTIAL | H, U; không reset document người dùng thật; P1 R1 tách riêng |
| SET-03 | Permissions/notifications / split | Đúng timing, deny/permanent deny/revoke/settings-return | SAF consent thật chỉ trên folder QA mới; host consent/notice tests | PARTIAL | SAF evidence; capture/notification permissions native NOT RUN |
| SET-04 | Recording preferences / P1 | Mở-only không write, portrait/capability đúng | R1/R2 còn tái hiện | FAIL | H, portrait_probe_task09_v1.log; P1 HANDOFF |
| UI-01 | Dialogs/sheets / split | Confirm/cancel/back/outside/focus/validation/busy | Host Create/photo/export/Support/pickers + native Create/language/storage/SAF | PARTIAL | H, U; 86 source surface declarations không phải 86 dialog đã test |
| UI-02 | Notices/notifications / split | Warning/Retry/Saved đúng, không false delivery | Host history-warning/Saved, Support mock; native empty validation đúng sau fix | PARTIAL | H, U; native capture notifications NOT RUN |
| UI-03 | Accessibility/HCI / split | Semantics/targets/text200/contrast/reduced motion/focus | Host App language target riêng; 49 locale-size layouts; native 5 focus thật | PARTIAL | settings_support_ui_green_v1.log, native_focus_navigation_v1.json; human TalkBack/tay thuận NOT RUN |
| L10N-01 | en/vi/es/pt_BR / all | Locale/fallback/format/persistence/no overflow | ARB checker + 4 viewport host per locale; main native English walkthrough | PARTIAL | H, l10n_final_v1.log; không chứng nhận every route/dialog human translation |
| L10N-02 | fr/de/id/hi / all | Long labels/text200/system switch | 16 host viewport cases + localization unit | PARTIAL | H; native per-locale/system switch chưa đủ |
| L10N-03 | ja/ko/zh_Hans / all | CJK wrapping/fonts/filenames/subtitles | 12 host viewport cases; Unicode subtitle tests | PARTIAL | H; native CJK editing/file picker + human typography NOT RUN |
| L10N-04 | ar / all | RTL icons/focus/numerals/text200 | 4 host viewport + Arabic effect/back assertion | PARTIAL | H; human TalkBack RTL/native Arabic walkthrough NOT RUN |
| SYS-01 | Lifecycle/constraints / all | Background/restart/low RAM/storage/API coverage | Host lifecycle/cache/storage guards; native app update/relaunch; 600s ASR sampled memory | PARTIAL | H, N, backup manifests; real ENOSPC/kill mid-save/API24–35 not rerun |
| SYS-02 | Data integrity / P2/P3 | Giữ nguồn, no overwrite/false Saved/orphan, consent thật | 62 fixture SHA exact; 22 output downloads SHA; source/docs/P1 hash; private update hashes | PARTIAL | integrity/backup/output manifests; không gọi đây là crash-consistency proof mọi power-loss |
| SYS-03 | Device matrix / all | Isolated QA, ARM/OEM/SD/16KB/thermal | Native chỉ AVD TASK09 API36 x86_64, page4KB; APK static alignment đạt | PARTIAL | device_boot_verified_v1.json; physical/real16KB/camera/mic/thermal NOT RUN |
| SYS-04 | QA5560 recovery / external | Không chạm guest/grants/data cũ khi chưa được phép | Không boot/install/run-as/chmod/root/grant trên QA5560 | BLOCKED | TASK08 vẫn PARTIAL; cần snapshot gốc và ủy quyền riêng để kiểm guest/SAF |
| SYS-05 | APK/licenses / shared | Main.dart mới, 3 ABI đủ native libs/licenses, không fixture/models | Profile QA APK v4 3 ABI build; packaging/alignment checker đạt; QA update riêng | PASS | final_main_apk_v4.json và *.packaging.log; đây là QA package, không release signing/store acceptance |
| INT-01 | P1→P2→P3 / TASK10 | Record→Library→Edit/ASR→Export→Gallery thật | Chưa bắt đầu capture E2E vì P1 chưa READY | BLOCKED | R1/R2/R4/R5, P; cần Người 1 báo ready và device gate |

## Các ca thực thi mới có kết quả hẹp

| ID | Phép thử | Owner | Kết quả | Evidence |
|---|---|---|---|---|
| T09-RUN-01 | Finalizing→completed, Cancel guard, bounded frames | P3/harness | PASS | r3_bounded_green_v1.log |
| T09-RUN-02 | In-flight terminal snapshot + Retry đọc lại Running | P3 | PASS | export_surrounding_green_v1.log |
| T09-RUN-03 | Rapid effects serialize, bỏ pending stale request | P3 | PASS host/native | preview_queue_surrounding_green_v1.log; N.rapidPreview |
| T09-RUN-04 | 5 warm route identity variants | P2/P3 | PASS host | warm_route_identity_green_v2.log; H |
| T09-RUN-05 | 3 root exit variants, giữ save/discard guards | P2/P3 | PASS host | root_navigation_green_v1.log; H |
| T09-RUN-06 | Support duplicate command + empty input + diagnostics consent | Shared/P2 | PASS host; empty native | H; U |
| T09-RUN-07 | App language semantics tách Theme | Shared/P2 | PASS host/native | settings_support_ui_green_v1.log; U |
| T09-RUN-08 | Whisper benchmark/import/fault/cancel/silence | P3 | PASS trong fixture | N.speech |
| T09-RUN-09 | Audio 8 tracks/effects/layers thực | P3 | PASS native + signal oracle | N.audio; audio/signal_validation.json |
| T09-RUN-10 | Photo EXIF/sRGB/JPEG + subtitle speed/burn-in | P3 | PASS trong fixture | N.photo; photo/validation.json |
| T09-RUN-11 | Native media event/rename/draft/MP4/GIF/cancel | P2/P3 | PASS trong fixture | N.media |
| T09-RUN-12 | Stress ASR 600s, 57 cues, limit600001 reject | P3 | PASS | N.longSpeech; asr_metrics_v1.json |
| T09-RUN-13 | Missing-video→valid frame→dispose | P3 | PASS trong fixture | source_recovery_native_baseline_report_v2.json |
| T09-RUN-14 | Missing-photo→valid frame→dispose | P3 | PASS trong fixture | source_recovery_photo_native_report_v1.json |
| T09-RUN-15 | 5 nhóm main-app taps/routes/dialogs | Shared/P2/P3 | PASS native v3 | U; XML/PNG cùng thư mục |
| T09-RUN-16 | 5 native accessibility focus targets | Shared | PASS native framework | native_focus_navigation_v1.json |
| T09-RUN-17 | SAF folder mới→Allow→copy readback exact | P2 | PASS native | saf_copy_verified_v1.json |
| T09-RUN-18 | Deny QA5560/5554/recovery-name trước ADB | QA safety | PASS mock | qa_safety_final_v1.log |

Không cộng 18 dòng này với số unit test hoặc số frame để thành “tính năng đã hoàn thành”. Phần nguyên nhân/source của các dòng FAIL/PARTIAL nằm trong bug register và handoff. Các trạng thái offline, permanently denied, network failure, rotation, background, restart, text200, dark/light, RTL chỉ được ghi PASS ở nhánh có evidence cụ thể; không tự nhân thành tổ hợp đã test.

Retest APK v4 cuối: [7 ca đạt ở lượt đầu](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_e04db7be9d22450eb07058d852403f4d/trace.json) và [3 ca đạt sau sửa fixture label/DocumentUI back-stack](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_d543d5c891434102a59f98a8cf7518fe/trace.json). Tổng 10 nhóm phân biệt, không đếm retry thành case mới. Native root Editor/Photo Back và PhotoPreview đã kiểm trên bản cuối; không thực hiện move thật trong ca mock root Media Details.

Thống kê **48 nhóm checklist gốc**: 1 PASS có phạm vi QA packaging, 41 PARTIAL, 2 FAIL (hai nhóm cùng R1/R2 P1), 2 NOT RUN (capture/screenshot runtime), 2 BLOCKED (QA5560 và TASK10). Đây là số nhóm yêu cầu rộng, khác 285 host tests đạt hoặc 18 dòng kiểm cụ thể. Control mapping native bảo thủ: 13/333 declaration/helper entries; P1 0/48, P2/P3/shared 13/285. Mẫu số instance control động toàn app chưa xác định, nên không có claim 100% control coverage.
