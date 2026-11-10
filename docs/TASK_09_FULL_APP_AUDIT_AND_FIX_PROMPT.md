# TASK 09 — Full-App Functional, HCI & Regression Audit + P2/P3 Fixes

**Dành cho Codex Astra (high/extra-high).** Ngày soạn: 09/11/2026.

## 0. Mục tiêu và quy tắc quyết định

Audit **toàn bộ 3HRecorder/XRecorder** sau khi pull code team: P1 Capture/Recording, P2 Library/Media/Platform và P3 Editor/Photo/Export/AI, cộng mọi shared UI (Home/Create/Settings/Navigation/Help/Dialogs). Không được chỉ audit các tính năng P2/P3 hoặc lấy số lượng unit test làm bằng chứng cho từng nút.

1. Lập bản đồ screen → control → action → trạng thái → owner → bằng chứng, bao gồm mọi button/icon, tap/long-press, menu, switch, slider, checkbox, picker, dialog, snackbar, overlay, navigation, gesture và system permission flow có trong source hiện tại.
2. **P2/P3:** tìm nguyên nhân, sửa các lỗi xác nhận được trong phạm vi ownership, thêm regression test, chạy lại test/native chứng minh trước–sau. Không chỉ báo cáo.
3. **P1:** audit source và test được phép, ghi bug và handoff chi tiết cho Người 1; không chỉnh code P1/recording settings/shared capture semantics. Không nhận lỗi P1 là DONE chỉ vì code P2/P3 không đổi.
4. **Cross-boundary:** ghi rõ owner, interface contract và test cần chạy lại hai phía. Chỉ chỉnh adapter thuộc P2/P3 nếu không làm đổi P1 semantics; mọi thay đổi hành vi P1 cần Người 1 phụ trách.
5. Phân biệt `IMPLEMENTED`, `PASS`, `FAIL`, `PARTIAL`, `NOT RUN`, `BLOCKED`, `P1 HANDOFF`. Không tuyên bố 100% đã test nếu một màn hình/trạng thái chưa được chạm tới. Kiểm thử tự động ≠ nghiệm thu UX bằng người thật.

## 1. Đầu vào bắt buộc trước khi sửa

- Đọc `AGENTS.md`, toàn bộ báo cáo TASK07/TASK08 hiện có, `POST_PULL_TEAM_INTEGRATION_AUDIT.md`, `P2_P3_CONTRACTS.md`, `P2_P3_CURRENT_AUDIT.md`, `P2_P3_MASTER_PROGRESS.md`, `P2_P3_TEST_EVIDENCE.md`, `TASK_08_DATA_SAFETY_REPORT.md`, `TASK_08_PERFORMANCE_BEFORE_AFTER.md`, và `TASK_09_FULL_APP_QA_MATRIX.md` đi kèm. Chỉ dùng các file thực sự tồn tại; ghi rõ nếu không tìm thấy.
- Đọc source hiện tại để đối chiếu mọi claim của báo cáo. **Không giả định HEAD còn là `9afcb124069d905dd4b285c890ca0709f5548b68`**; ghi lại `git status --short`, branch/HEAD, staged+unstaged+untracked, commit/team merge liên quan trước khi thao tác.
- Làm snapshot kiểm kê read-only của các file có diff; tài liệu, artifact, media, AVD và QA data là tài sản người dùng. Không restore/copy file từ HEAD lên dirty worktree, không tự rebase/merge/commit/push.
- Chạy baseline compile/analyze/tests để phân loại lỗi **trước sửa**. Tại post-pull audit trước đây: **271 Flutter PASS/5 FAIL; 137 native JUnit PASS**. Đây chỉ là mốc lịch sử, không ép kết quả mới phải trùng.
- Inventorize routes/widget tree, settings store, navigation shells, native channels, launcher/deep links, system Activities và mọi tính năng ẩn sau permission/tình trạng dữ liệu. So sánh với source thay vì tự bịa màn hình.

## 2. Vùng ownership bất biến

**P1: đọc/kiểm thử/ghi bug, tuyệt đối không sửa** trừ khi người dùng cấp phép riêng sau khi phối hợp Người 1:

```
lib/features/recording/**
android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**
lib/features/settings/recording_settings_form.dart
lib/features/settings/audio_video_settings_screen.dart
```

`lib/core/widgets/studio_create_sheet.dart` chứa shared capture UI: chỉ đọc/audit, không extract/sửa capture semantics. `MainActivity` nếu cần P2/P3 registration thì chỉ additive, giữ P1 channel/permissions. Không sửa P1 `MediaOutput`/`RecordingMuxer` implementation. P1 request codes 702–706 (và overlay 707), P2/P3 1701–1705; tránh collision với SupportBridge 704.

Không dùng thay đổi từ HEAD để lấp/ghi đè trạng thái settings/locale chưa commit. Trước mọi edit, xét diff cụ thể, patch hẹp bằng `apply_patch`; nếu file trùng phần team đang thay, báo blocker và đề xuất merge thủ công. Không xóa, gộp hoặc đổi tên feature chỉ nhằm pass test.

## 3. Gate an toàn QA, AVD và evidence

- **QA5560 `ThreeHRecorder_Task021` đang OFFLINE:** đã xảy ra SDK uninstall/UID change trong TASK08. TASK08 `PARTIAL`; dữ liệu host đã hash, nhưng guest permissions/ownership và toàn bộ draft chưa xác nhận. **KHÔNG boot, install-r, reinstall, uninstall, clear-data, wipe, run-as, mount, root, chmod, sửa grants, xóa private/MediaStore/AVD** ở đây nếu chưa có ủy quyền mới, rõ ràng, cho từng bước.
- **Emulator 5554 là emulator cá nhân**: không gửi ADB/Flutter install/test, không sử dụng như QA mặc định.
- Chỉ native UI test/đưa APK lên **QA device/AVD riêng, đã xác minh danh tính, có backup/UID/storage-margin preflight, được người dùng cho phép**. Nếu không có, làm static/widget/host tests và đánh dấu native `NOT RUN`. Không tự fallback sang thiết bị khác khi install thất bại.
- Không overwrite artifact cũ: cấm dùng `>` lên tên evidence hiện có; tạo thư mục checkpoint **mới, duy nhất, no-clobber** dưới `build/verification/task09/`. Duy trì failed logs và evidence TASK07/TASK08. Không xóa backup hoặc dữ liệu để tối ưu 106 GB workspace trong TASK này.
- Không tự grant SAF bằng shell hay sửa owner MediaStore. `Choose folder` / DocumentsUI/consent và relink phải là thao tác người dùng hoặc QA được ủy quyền.
- Không commit/push/PR/sign-release/publish/Billing/Ads.

## 4. Quy trình bắt buộc: audit trước, fix P2/P3, retest

### A. Inventory đầy đủ

Đọc và điền `TASK_09_FULL_APP_QA_MATRIX.md` cho **mọi route thực tế**. Mỗi control cần: `testID`, screen/path, text/icon/semantics, visible/disabled condition, default state, tap/change/back/dismiss behavior, success & failure feedback, persistence/relaunch, source file/handler, P1/P2/P3/shared owner, test type, PASS/FAIL/NOT RUN, evidence, bugID.

Đối với mỗi màn hình, test các mức: dữ liệu rỗng/ít/rất nhiều, loading, success, validation fail, permission denied/permanently denied/revoked, offline/network lỗi nếu liên quan, rotation, background/resume, app restart, light/dark, scale 100/200%, small/large width, RTL. Chỉ mark khi có evidence tương ứng; biến thể không hỗ trợ thì `N/A + lý do`.

### B. P1 audit và handoff, không sửa

Đọc toàn bộ capture UI và backend; xem recording/Facecam/screenshot/audio/source/overlay/draw/region/shortcut paths. Kiểm tra từng button và các setting tác động ghi hình; đối chiếu UI với khả năng native và state persistence. Nếu chưa có hardware/permission, phân loại rõ static/unit/native NOT RUN; không dùng fixture editor để chứng nhận P1 capture.

Ưu tiên tái hiện và cập nhật các issue từ **post-pull**:

| Bug | Mức | Tình trạng lịch sử cần xác minh lại trên HEAD mới |
|---|---|---|
| R1 | HIGH P1 | Chỉ mở Recording Settings có thể `settings.update` resolution/FPS/codec/bitrate qua `_normalizeSelection` khi chưa bấm lưu, làm mất ý định người dùng. |
| R2 | HIGH P1 | Portrait capability biểu diễn landscape/canonical nhưng UI kiểm width/height trực tiếp, vô hiệu 720p portrait dù preflight/recorder chấp nhận. |
| R4 | HIGH P1 | Region `cropX/cropY` đi qua validation nhưng pixel output không apply origin, VirtualDisplay cấp full encoder surface. |
| R5 | MEDIUM P1 | MP4 RecoveryEngine có unit test nhưng chưa thấy production startup/journal caller. |
| R6 | MEDIUM P1/shared | Facecam, drawing, overlay options, audio ducking, crop custom args có backend/options nhưng UI/settings/persistence chưa đầy đủ. Chia rõ P1 và P2/P3 adapter. |

Tạo `TASK_09_P1_HANDOFF.md` với bước tái hiện, input/expected/actual, source references, minimal fix direction, regression acceptance và impact từng lỗi; không phát lệnh sửa P1 từ agent này.

### C. P2/P3 sửa tất cả bug được xác nhận trong scope

Kiểm Library: auto refresh, 5 sort/search, large datasets 1k+, thumbnail equality/cache, MediaStore owned/external, copy/move hash, Trash/Restore, SAF revoked/disconnected, older/empty folder, screenshot Photo action, static/pinned shortcuts, preview/relink. Kiểm editor: create/open/draft process-restart, undo/redo, 8 audio tracks, trim/split/merge/reorder/duplicate, layers/text/sticker/drawing, crop/rotate/flip/speed, parity preview/export, subtitle time/style/SRT clipboard/file, MP4/GIF cancel/retry/queue/failed/finalizing, storage/history faults, metadata 1001+ jobs. Kiểm offline ASR whisper tiny/base/small, vi/en/auto, silence, progress/cancel, model verify/download/import/delete, retention/checkpoint, consent and 10-minute limit, edited audio→ASR→SRT/burn-in.

**R3 MEDIUM P3:** old `export_screen.dart` indeterminate `LinearProgressIndicator` khiến widget test dùng `pumpAndSettle()` timeout. Xác định test đỏ vì animation luôn chạy hay app hang thực; nếu là harness, thay bằng bounded frames/target condition và kiểm `Saving/Finalizing` + Cancel guard. Giữ nguyên mục tiêu regression, không bỏ test hoặc xóa progress UI cho xanh.

**R7 runtime:** stale-source draft black preview/ANR, GIF writer/thumbnail/progress sau pull: tái hiện trên môi trường an toàn, phân biệt P2/P3/P1. Nếu không có thiết bị authorized thì STATIC/TEST ONLY + `NATIVE NOT RUN`, không kết luận đã fix ANR từ unit alone.

Mỗi bug P2/P3: (1) red regression trước, (2) root cause, (3) patch hẹp, (4) test green, (5) re-run surrounding paths, (6) kết quả artifact. Không chỉnh benchmark thresholds cho đẹp hoặc giả dữ liệu. Stop/escalate nếu test cần chạm user data, P1 hoặc quyền mới.

### D. Whole-app interactions và UX

- Từng bottom-tab/reselect-to-top, back/Android back, cold/warm/deep link, multi-tap debounce, overlays, modal dismissal, keyboard focus, scroll restoration, pop state, app lifecycle.
- Settings: **mọi** switch/slider/select/navigation/restore settings/theme/language/permissions/help/about/guide và Recording Settings ở chế độ P1 read-only. Verify persistence qua app restart và system changes; chỉ mở màn hình không được ghi âm thầm preference. Không sửa user Settings document để test.
- Dialogs/notification: confirm/cancel, destructive confirmation, double-tap guard, loading/saved/error/warning, retry, overlay, dialog barrier/back, error specifics; text ngắn, dễ hiểu, không false `Saved` khi MediaStore chưa commit; Help & Guide link hợp lệ.
- Global/i18n: 12 locales dự kiến `en, vi, es, pt_BR, fr, de, id, ja, ko, zh_Hans, hi, ar`. Test fallback English, no raw key/untranslated hardcode, plural/date/number/units, right-to-left layout Arabic, CJK truncation, semantic labels. Nhận dạng giọng nói vi/en được benchmark nhưng **không** suy thành support ASR accuracy cho toàn thế giới.
- UI requests chỉ là checklist cần xác minh nguồn: screenshot icon ≠ scan, auto-index không cần nút Refresh thủ công, `Older first` không tràn, back arrow style, Light theme, Q&A contrast, `Android`→`Device`, permission timing/denial, screenshot result delay (~3s target), một tay/touch targets. Không tự coi thiếu là bug nếu product spec đã đổi; nêu evidence và owner.
- Accessibility: semantics/name/hint, hit target, switch/slider announcements, form errors, TalkBack focus/gesture (không nói human PASS nếu chỉ bật service), reduced motion, text200, contrast.

### E. Quality/performance/safety

- Re-run `flutter analyze`, complete `flutter test`, native JUnit, `git diff --check` and plugin/packaging sanity after fixes. Record exact command/time/exit and remaining failures; **271/5 & 137 are prior checkpoint only**.
- On authorized AVD only: native tap coverage traces/video screenshots, background/restart, output MP4/GIF full decode+PTS+audio signals, real ASR outputs, UX focus, loading/scroll trace. Avoid unbounded expensive runs or destructive disk-full injection. No claims about ARM/OEM/SD/physical battery/FPS absent physical measurement.
- Check data protection: no overwrite source media, no premature source deletion on SAF move, no orphan pending publication, restore exact bytes, fail-safe if history/journal not writable; don't simulate ENOSPC by filling user disk.
- Measure APK installed/download size separately from 106 GB workspace/build/cache/AVDs; do not say app is 106 GB. New APK must originate current `lib/main.dart`; Task08 v5 APK is stale post-pull.

## 5. Phân quyền sửa và thứ tự ưu tiên

1. **P0** data loss/source overwrite/uninstall/crash while saving → stop unsafe scenario, preserve evidence, report and patch only if P2/P3 authority.
2. **P1** app startup/navigation broken, P2/P3 save/export incorrectly `Saved`, broken core editor/library or permission bypass → fix in owned scope + retest.
3. **P2** dialogs/locale/RTL/accessibility/UX state bugs, stalls, unhandled exception → fix owned scope + retest.
4. **P3** cosmetic, text spacing, noncritical icons → refine only after core passes.
5. P1 bugs are prioritized and handed off, never silently fixed in protected paths. If R1/R2/R4/R5 unresolved, `TASK10 READY = NO` even if P2/P3 checks pass.

## 6. Deliverables bắt buộc (không gộp mơ hồ)

1. `TASK_09_SCREEN_CONTROL_INVENTORY.md`: **every actual screen and control**, handlers, owner and count; coverage numerator/denominator, unknowns.
2. `TASK_09_FULL_APP_QA_MATRIX.md`: filled testID rows and PASS/FAIL/PARTIAL/NOT RUN/N/A by screen + variants, links to artifacts.
3. `TASK_09_BUG_REGISTER.md`: P0–P3, P1/P2/P3/shared, reproduction, expected/actual, fix commit? (không commit), changed files, test proof.
4. `TASK_09_P1_HANDOFF.md`: P1 defects isolated incl R1/R2/R4/R5/R6; send to Người 1, mark unresolved or verified fixed.
5. `TASK_09_HCI_ACCESSIBILITY_REPORT.md`: navigation, UI copy, 12 locales, TalkBack/human gaps.
6. `TASK_09_TEST_EVIDENCE.md`: command+logs, fixtures, recordings, screenshots; keep failed attempts; no bogus PASS.
7. `TASK_09_FINAL_QA_REPORT_VI.md`: separate **P1**, **P2/P3**, **shared**, **device gates**; counts PASS/FAIL/BLOCKED; source HEAD before/after and diff; remaining issues, `TASK10 READY: YES/NO + conditions`, no full-app DONE without gates.

## 7. Exit criteria

**TASK09 audit complete** = inventory traceable, P2/P3 confirmed bugs fixed and safely re-tested, P1 handoff complete, all unrun conditions transparent. `TASK09 ALL APP PASS` **chỉ khi** mọi required test/interaction pass; nếu P1 lỗi hoặc physical gap thì ghi `PARTIAL` chính xác.

**TASK10 chỉ bắt đầu sau khi Người 1 đã báo code P1 ready** và owner xác nhận phạm vi native/device testing. TASK10 có trách nhiệm merged P1→P2→P3 end-to-end on new HEAD, record→MediaStore observer→Library→Editor/ASR→export→Gallery/reopen; crash/process/data/restart/consent/permissions across appropriate Android versions and physical devices; final regression and release candidate. TASK10 PASS không tự động bao gồm signing/Ads/Billing/Play publication và không biến gate máy thật còn mở thành DONE.

**Cuối phiên:** ưu tiên sửa P2/P3 thật sự và báo cáo có số liệu; không chỉ trả lời một bản kế hoạch. Nếu cần quyền/thiết bị mới, dừng đúng gate và xin người dùng quyết định, tiếp tục những phép thử khác không đụng dữ liệu.
