# TASK 09B — Full-App Interaction Coverage Completion & P2/P3 Fixes

**For Codex Astra, high/extra-high reasoning.** Soạn 09/11/2026. Tiếp nối TASK09, **không phải khởi động lại project**.

## 0. Sứ mệnh

TASK09 đã có 7 P2/P3 product fixes, R3 harness fix, 285 Flutter PASS/4 FAIL P1, 137/137 JUnit, isolated x86_64 AVD integration, và APK compact. **TASK09 vẫn PARTIAL**, `TASK10 READY = NO`.

TASK09B phải (1) lấp các khoảng trống kiểm thử tương tác chức năng thực tế của **toàn app**, (2) **sửa ngay lỗi P2/P3 đã tái hiện** và chứng minh red→green, (3) kiểm tra P1 read-only và cập nhật tài liệu handoff, (4) tách bạch test có thể làm ngay với gate thiết bị/người thử/P1. Đừng biến nhiệm vụ thành báo cáo tổng hợp log cũ hoặc tuyên bố nút/flow PASS từ việc widget được build.

**Đích ưu tiên:** không còn **lỗi P0/P1 thuộc P2/P3** chưa sửa, coverage tất cả control và screen *có thể tiếp cận an toàn trên QA được cấp phép* có interaction evidence; các `BLOCKED/NOT RUN` còn lại có lý do, owner và cách đóng. `TASK09B DONE` nghĩa là đã hoàn tất công việc được phép, **không có nghĩa toàn app đã nghiệm thu/Task10 READY=YES**.

## 1. Đọc và khóa baseline

Đọc toàn bộ `AGENTS.md`, các file TASK09 (`TASK_09_FINAL_QA_REPORT_VI.md`, `TASK_09_SCREEN_CONTROL_INVENTORY.md`, `TASK_09_FULL_APP_QA_MATRIX.md`, `TASK_09_BUG_REGISTER.md`, `TASK_09_P1_HANDOFF.md`, `TASK_09_HCI_ACCESSIBILITY_REPORT.md`, `TASK_09_TEST_EVIDENCE.md`), `POST_PULL_TEAM_INTEGRATION_AUDIT.md`, `P2_P3_CONTRACTS.md`, báo cáo TASK08 data safety, bản QA runner và QA output. Không bịa path; nếu thiếu file ghi `MISSING INPUT`.

Record branch/HEAD/status, `git diff --stat`/staged/untracked và content hashes của **toàn bộ TASK09 working patches**, docs, model, media/evidence; không copy từ HEAD để thay thế dirty code. Source HEAD TASK09 được báo là `9afcb124069d905dd4b285c890ca0709f5548b68` với **uncommitted patches**: kiểm thật chứ không giả định còn đúng. Tránh edit vào file cả team đang sửa; nâng blocker nếu chồng lấn không an toàn.

Baseline lịch sử từ báo cáo TASK09 (KHÔNG phải fresh PASS): 285 Flutter PASS/4 P1 FAIL, 137/137 JUnit, 12 locale resource keys, 22 file outputs, 12/13 screen types native-touched, 13/333 interaction/helper entries linked to direct native tap, matrix 1 PASS /41 PARTIAL /2 FAIL /2 NOT RUN /2 BLOCKED. Hai FAIL matrix xuất phát R1/R2 P1. **Không dùng 333 declarations làm mẫu số 'mọi nút runtime'.**

## 2. Ownership, máy QA, dữ liệu — giới hạn không được vượt

**P1 READ ONLY:** `lib/features/recording/**`, `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**`, `lib/features/settings/recording_settings_form.dart`, `lib/features/settings/audio_video_settings_screen.dart`, capture semantics trong `lib/core/widgets/studio_create_sheet.dart`; P1 channel trong `MainActivity`. P1 R1/R2/R4/R5/R6 chỉ audit/reproduce/handoff; 4 Flutter test P1 đỏ không được skip/xóa/chỉnh test để biến thành PASS. Nếu người 1 đã sửa code mới, verify lại và đính kèm evidence.

**P2/P3:** được phép sửa sản phẩm và test trong ownership sau khi xác định root cause; không sửa P1 semantics để fix P2/P3 symptom. 7 fixes TASK09 và compact APK phải bảo toàn. Xem lại code team mới và chỉ thêm patch có scope rõ.

**QA hardware/data:**

- **QA5560/ThreeHRecorder_Task021** đang offline và có data recovery incident; tuyệt đối không boot, install(-r), uninstall, clear/wipe, chạy shell `run-as`, mount, root/chmod hay tự cấp grants. Chỉ đọc hồ sơ host/evidence có sẵn nếu cần; guest recovery cần ủy quyền task riêng.
- **Emulator5554 cá nhân**: cấm gửi bất cứ lệnh ADB, Flutter install, UI test vào đây.
- Native tests **chỉ trên AVD/QA phone tách riêng mà người dùng đã cho phép**, nhận diện serial/AVD/name/UID/backup/storage margin trước mỗi install. Không fallback tự động khi thiếu dung lượng, uninstall SDK hay đổi package để né blocker. Chỉ truy vấn thiết bị khác ở mức read-only inventory khi được phép; không chạm data người dùng.
- Không tạo fault test bằng cách fill disk thật, xóa user MediaStore, move user media, root grant hoặc scan ngoài phạm vi. Dùng **fixture synthetic/disposable**, journal simulator hoặc sandbox test app riêng.
- Evidence cho TASK09B nằm trong `build/verification/task09b/<unique-run-id>` tạo mới **không overwrite** output TASK07/TASK08/TASK09. Giữ red logs và incident data; không `git clean`, `git restore`, `git reset --hard`, file overwrite `>` lên evidence có sẵn, commit/push/PR/sign-release/publish.

## 3. Phân loại coverage đúng cách — phải làm trước khi test

Từ source hiện tại, tạo **route graph** và **screen-state inventory**. Tại mỗi active route/render state, enumerate interactive controls bằng widget/semantics (id/key/label/tooltip/role, enabled state, handler/navigation target), system Activities, overlays, dialogs, menus. Lấy mẫu màn hình tương ứng trên QA thật/AVD được phép để xác nhận dynamic instances. Không coi `GestureDetector` declaration == một nút người dùng thấy; ngược lại cũng không bỏ các nút tạo runtime bằng list builder.

Cho từng **reachable control-state pair**, ghi:

`ID | route | screenshot/state | locator(key/semantics) | action | expected output & feedback | actual | owner | test modality(widget/integration/native/human) | status | evidence | bugID`.

Chia coverage rõ:

- **Source discovery**: các declarations/call sites; có thể có duplicates và helpers.
- **Runtime reachable controls**: số interactive instances/unique logical actions đã quan sát (kèm cách tạo dữ liệu và reachability).
- **Directly exercised**: tap/scroll/type/change/back được chạy và hậu quả được assert.
- **Behavioral scenario coverage**: success/invalid/empty/permission/restart/locale/gesture; KHÔNG lấy tỷ lệ direct tap chia cho declarations rồi kết luận toàn app coverage.
- **Blocked/unsupported**: không có máy/hardware/grant/P1 ready; ghi owner + entry steps; không lấp bằng synthetic PASS.

Nếu công cụ UI automation không thể tap semantic target, hãy dùng test widget/integration cho phần có thể kiểm và đánh dấu `NATIVE/HUMAN NOT RUN` rõ ràng. Không chụp màn hình rồi nói một nút đã hoạt động.

## 4. Lịch test và sửa lỗi theo thứ tự ưu tiên

### G1 — Navigation/shared UI + Settings toàn diện

1. Fresh/warm launch, splash, tab navigation/reselect scroll top, deep link external/internal, nested routes, back from root/nested and bottom sheets, interrupted navigation, rapid taps, app resume.
2. **Từng Settings row/icon/button/switch/slider/dropdown**: enter/exit, validation, explicit save vs read-only view, restart persistence, state migration, light/dark/system, App Language, shortcuts, permission manager, Notification, Q&A/Help/Guide/About. Settings Recording P1 read-only — tái xác minh R1/R2, không sửa.
3. Mỗi dialog/snackbar/toast/action sheet trong app: open, OK/Cancel, dismiss via barrier/back, outside tap, keyboard focus, duplicate submit, error text, disabled/loading and saved-after-commit semantics. Support report empty/attachment/rapid send regressions from TASK09.
4. Route warm uniqueness: media/photo/draft/Help và `Media Details` after move; root editor/photo back guard and Save/Discard. Làm regression run 2–3 lần khác state, không chỉ 1 happy path.

### G2 — P2 Library + media safety

5. Video/Photo Library: no content/one item/1000+ real synthetic rows, search/sort all 5, folder filters/scroll restoration, new media auto-observer, title wrapping and rotation thumbnails; speed/cache with controlled baseline.
6. Media details/video player/photo viewer: play/pause/seek, share/screenshot/rename/delete/Trash/Restore/move/copy, invalid URI/missing source, cross-app media read-only, retention after navigation.
7. SAF via **real DocumentsUI on authorized QA**: picker Cancel, normal Copy read-back hash, Move with actual write grant and destination commit verification before source deletion, revoked grants, disconnected destination, persisted grant after restart. Only synthetic files. Document OEM/SD `NOT RUN` if no hardware.
8. Crash/data fault: backup-only, unreadable corrupt project, UTF-8 cap, empty result, checkpoint fallback, orphan MediaStore pending, no data deletion. No run of destructive fault against QA5560.

### G3 — P3 editor/photo/audio/subtitle/export/ASR (real output)

9. Draft create/import/relink/delete/duplicate/rename/reopen after process kill on **disposable QA**; timeline still/video/source trim/split/reorder/merge, speed 0.5/1/2, crop/rotate/flip, 50 undo/redo, invalid media.
10. Editor preview: rapid effects changes, keep playhead, cancel stale generation, resource drain, SurfaceView reload, black-frame/ANR missing source (TASK09 R7 historic), no duplicate players; verify actual final selected composition, not just no exception.
11. Timed layers: text/stickers/drawings transforms/start/end, z-order and style. Preview/export parity by pixel/time oracle on fixtures; list cases not run explicitly.
12. 8 audio tracks, source in/out, output offset, volume/fades/headroom/deep/bright/robot, real RNNoise, silence, PTS/audio duration; human listening on physical remains independent gate.
13. Photo: crop/rotate/flip/paint/text/history, EXIF 1–8, sRGB/P3 conversion, PNG/JPEG/resize/quality, original bytes unchanged; save-copy feedback and Cancel.
14. Subtitles: manual/edit/split/merge/delete/overlap validation, UTF-8 SRT clipboard/ACTION_CREATE_DOCUMENT, long text/wrap/safe area/styles, retime with speed; burn-in visible vs hidden frame oracle.
15. Export: MP4/GIF options, queued/running/finalizing/saved/failed/cancelled/retry, progress guards and restart durability; 1001+ history pagination/latest matching, no stale Failed snapshot overwriting Running, no fake `Saved` before commit, no UI hanging on indeterminate progress. Decode actual files independent of app; keep PTS/audio signal/bytes/size.
16. Offline ASR: no configured model, tiny/base/small verification/download/import/remove + cancellation, no network/cloud upload, vi/en/auto/silence/music/overlong, job retention/restart and edited audio→SRT/burn-in. Test model download on an authorized disposable model store; never delete retained models in QA5560. Multilingual **accuracy** only verified on provided corpus; don't claim 99-language readiness from model metadata.

### G4 — Global UI/HCI/Accessibility

17. Cover **en, vi, es, pt_BR, fr, de, id, ja, ko, zh_Hans, hi, ar** across Home, Videos, Photos, Create, Editor, AI, Export, Settings, Q&A, alerts, permission explanations. Source resource-key validation is supporting evidence only: inspect actual runtime layout, truncated controls, line wraps, plural/date/units, back icon mirror, fonts, 200% font, 320dp/411dp and landscape where supported.
18. RTL Arabic text direction, directional icons, timing numerals, text field editing/caret, focus order and scroll direction; CJK/Vietnamese diacritics and emoji filenames. Language fallback English on missing translations, locale persisted after app cold restart. Report every hardcoded untranslated message by route/owner.
19. Accessibility: semantics labels/states for icon-only actions, keyboard focus/traversal, touch target, contrast Light/Dark, accessible drawing preset; TalkBack service smoke != human gesture/focus proof. Only mark human PASS if actual human test signed off. One-handed reach and slow/no-motion modes similarly honest.
20. HCI targets from product request: screenshot camera-like icon, no unnecessary manual Refresh, `Older first` wraps, simple back arrow, corrected Light theme, Q&A contrast, `Android` label where `Device` intended, early permission request with consent, screenshot result promptly (target ~3 s, measure not assume). Confirm intended spec before changing current design.

### G5 — Performance, APK, full regression

21. Controlled benchmark 1000+ items same corpus, mode, viewport/host conditions before/after patches (Flutter build/raster p50/p95, jank count, native memory and reload). Don't compare Flutter raster p95 with HWUI frame p95 as if equal. No 60fps claim if >16.67ms frames. AVD SwiftShader ≠ physical GPU.
22. Startup/preview load/frame/seek and long-running memory retention; measure after repeated navigation, model load/delete cycles and background resume; include native PSS and isolate variables. Report source + mode. Physical thermal/battery/leak gates outside authorized QA mark `NOT RUN`.
23. QA APK: build from current `lib/main.dart`, not stale TASK08 or integration_test target. If using compact packaging, preserve reproducible recipe, all live entries/ABI/licences/signing, validate zipalign+ELF 16KB; a smaller ZIP isn't proof of faster app. Release signed remains out of scope.
24. Re-run complete `flutter analyze`, `flutter test --no-pub` (or repo-required command), native JUnit and QA safety; don't silently skip 4 P1 failures. Separate `PASS P2/P3` from `P1 FAIL`; test failures from harness vs actual feature must be analyzed accurately.

## 5. Error handling & patch rules

For every **new P2/P3 defect**, create a bug row and reproducible failing test before patch, unless infeasible (explain). Fix root cause minimally, preserve current 7 fixes, regression-test related flows, measure outputs. Do not lower thresholds/timing to hide regressions, introduce bogus mock success or rewrite previously reported results. Bugs in P1/shared capture are documented for Person1, not patched.

Priority: P0 data corruption/unauthorized deletion → immediate stop; P1 crash/nonfunctional core/permission or false save → owned fix urgently; P2 navigation/dialog/locale/accessibility/UX; P3 cosmetics. When a test needs new authority or touches prohibited QA, stop **that subcase**, continue other safe tests, request authorization in final report.

## 6. Deliverables (new TASK09B files; no old evidence overwrite)

- `TASK_09B_SOURCE_AND_RUNTIME_INVENTORY.md`: live route graph, control identifiers/handlers and actual denominators, owner; compare TASK09 419 declaration/source entries honestly.
- `TASK_09B_INTERACTION_COVERAGE.csv` or `.md`: one row per reachable control-state action, tested/untested + locator, screenshots & expected/actual & logs; separate widget vs native vs human.
- `TASK_09B_SCENARIO_MATRIX.md`: **companion checklist** filled with success/failure/permission/restart/locale dimensions for each G1–G5 flow.
- `TASK_09B_BUG_REGISTER.md`: P2/P3 old/new issue status and red→green provenance; P1 issue handoff IDs and exact source reproduction.
- `TASK_09B_P1_HANDOFF_UPDATE.md`: status and evidence of R1/R2/R4/R5/R6; no P1 edits; explicit 4 failing tests listing.
- `TASK_09B_GLOBAL_HCI_REPORT.md`: 12-language runtime layout and human gates, comparison per route/theme/size.
- `TASK_09B_TEST_EVIDENCE.md`: tests/commands/exit codes, native QA serial consent, output validator artifacts, screenshots, failed attempts (no synthetic extrapolation).
- `TASK_09B_FINAL_REPORT_VI.md`: improved counts, remaining P2/P3 defects, P1 blockers, device gates, regression/perf, exact HEAD/dirty status, **TASK10 READY: YES/NO** with unmet criteria.

## 7. Định nghĩa nghiệm thu

`TASK09B SCOPED PASS`: mọi required P2/P3 flow reachable trên thiết bị QA được phép có behavior & assertion evidence; các bug nghiêm trọng P2/P3 xác nhận được đã sửa và regression xanh; uncovered cases được phân loại minh bạch. Nếu có lỗi P1, phone thật chưa có, hoặc UI/gesture còn chưa chạy, kết luận **FULL APP ACCEPTANCE = PARTIAL**.

`TASK10 READY = YES` chỉ khi Người1 đưa P1 fix evidence và merged source ready; không còn P0/P1 quan trọng, coverage P2/P3 đủ để khóa code, có permission/device plan. TASK10 sau đó kiểm P1→MediaStore→Library→Editor/ASR→Export→Gallery trên **real capture** (không media fixture thay recording) + release candidate/physical device checks. TASK10 PASS chỉ chứng nhận app theo **scope và device matrix đã nghiệm thu**; không tự bao gồm release signing, billing/ads, Play Store submission, hay phục hồi lịch sử QA5560 không có preincident snapshot.

**Hành động ngay:** bắt đầu bằng G1 Settings/dialog/navigation và G2 SAF/trash vì TASK09 chưa có tương tác native đủ; tiến tới G3/G4/G5, đóng lỗi P2/P3 trong từng vòng. Không dừng ở phân tích nếu patch nằm trong scope và có thể xác minh an toàn.
