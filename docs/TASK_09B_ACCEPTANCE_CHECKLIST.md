# TASK 09B — Acceptance Checklist / Kịch bản bắt buộc

**Mục đích:** companion cho `TASK_09B_FULL_COVERAGE_COMPLETION_PROMPT.md`. Mọi status dưới đây là **NOT RUN hoặc BLOCKED** tại thời điểm soạn, không phải kết quả QA mới. Codex phải mở rộng từng hàng thành controls + states dựa trên source thực tế và evidence, không xóa dòng khó test.

| Priority | Case ID | Screen / feature | Yêu cầu nghiệm thu cụ thể | Owner | Tình trạng đầu |
|---|---|---|---|---|---|
| P0 | S-01 | Settings all rows | Từng row/switch/slider/dropdown/Restore/Help/About navigation; open/back no side effects; restart persistence | Shared/P1 read-only | NOT RUN |
| P0 | S-02 | Settings/Recording | Reproduce R1/R2; 4 failing tests; handoff Person1, không tự sửa P1 | P1 | BLOCKED P1 |
| P1 | N-01 | App + bottom tabs | Cold/warm routes, rapid switches, reselect scroll-top, nested back, Android back, state retention | Shared | NOT RUN |
| P1 | N-02 | Deep links | Edit/Photo/Draft/Help, root back, saved/discard guard, stale route identity, shortcut warm/cold | P2/P3 | NOT RUN |
| P1 | N-03 | Support / Help | Rapid double tap, invalid report vs attachment error, permission and retry/dialog feedback | Shared/P2 | NOT RUN |
| P1 | N-04 | Every dialog/menu/toast | Confirm/Cancel, back/barrier, keyboard, fast tap, no duplicate action, correct error and saved timing | Each owner | NOT RUN |
| P1 | M-01 | Library | Empty, 1, 1000+, search, all 5 sorts, new media observer, scroll/query retention | P2 | NOT RUN |
| P1 | M-02 | Media details | Preview/play/seek, rename/screenshot/photo editor, lost source, move exit, stale nav | P2/P3 | NOT RUN |
| P0 | M-03 | Trash/Restore | Owned PNG+video fixture byte exact, cancel/missing/unsupported external, recover backup, no foreign cleanup | P2 | NOT RUN |
| P0 | M-04 | SAF Copy | Real DocumentsUI picker with permission, SHA read-back, failed/revoked destination, no source loss | P2 | NOT RUN |
| P0 | M-05 | SAF Move | Delete source **only** after target committed+byte verified+real grant; disconnected path fail-safe | P2 | NOT RUN |
| P1 | M-06 | Large library | 1000+ scroll both widths/text200; cache collision key/decodes, Flutter p95 baseline, memory | P2 | NOT RUN |
| P1 | D-01 | Draft timeline | Create/save/reopen/duplicate/relink, trim/split/merge/undo/redo, mixed photo/video and invalid source | P3 | NOT RUN |
| P1 | D-02 | Preview reliability | Rapid effects updates final composition, stale generation, playhead preserve, resource release, R7 ANR | P3 | NOT RUN |
| P1 | D-03 | Audio/effects | 8 tracks trim/offset/fade/gain/headroom, voice 3 presets, RNNoise with actual signal oracles | P3 | NOT RUN |
| P1 | D-04 | Overlays | Timed text/stickers/drawing/z-order/transform; output pixels match timeline time | P3 | NOT RUN |
| P1 | D-05 | Photo | EXIF1–8, ICC, crop/marks/undo/history, JPEG quality and resize, source exact bytes | P3 | NOT RUN |
| P1 | D-06 | Subtitles | Add/split/merge/delete/style/retime/overlap validation; SRT UTF-8 picker and burn-in oracle | P3 | NOT RUN |
| P0 | X-01 | Export state machine | queued/running/finalizing/saved/failed/cancel/retry; after commit Saved, no phantom URI | P3 | NOT RUN |
| P1 | X-02 | Export outputs | Real MP4/GIF full decode/PTS/audio/pixels; repeat/FPS/bitrate and pending publication | P3 | NOT RUN |
| P1 | X-03 | Export history | 0/20/21/77/100/1001 jobs, project latest filtering, cursor ties, no stale failure overriding retry | P3 | NOT RUN |
| P0 | X-04 | Recovery & faults | Journal/write fail, draft backup, process restart during save/encode on disposable QA, no duplicate media | P3 | NOT RUN |
| P1 | A-01 | ASR models | Tiny/Base/Small checksum/download/import/cancel/remove; no delete active model, no hidden server upload | P3 | NOT RUN |
| P1 | A-02 | ASR jobs | vi/en/auto, silence, timeout/10min limit, edited-audio timestamp, restart/review/SRT/burn-in | P3 | NOT RUN |
| P1 | L-01 | Global common | 12 locales on real UI, all tabs+dialogs+Settings, fallback/plurals/date units, cold restart | Each owner | NOT RUN |
| P1 | L-02 | Arabic/RTL + CJK | RTL icons/focus, no clipping/text200, Japanese/Korean/Chinese filenames and editor text | Each owner | NOT RUN |
| P2 | H-01 | Accessibility | Semantics labels, focus, keyboard numeric fields, touch targets, Light/Dark contrast | Each owner | NOT RUN |
| P1 | H-02 | Human usability | Real human TalkBack/gestures/one-hand, listening, media scrub and preferences comprehension | External QA | BLOCKED human |
| P1 | P-01 | P1 native capture | Real recording/Facecam/region/audio+permissions/pixel and recovery; R1/R2/R4/R5/R6 | P1 | BLOCKED P1 |
| P1 | P-02 | Merged E2E | Real P1 capture → MediaStore → Library → Editor/AI → export → Gallery/reopen | TASK10 | BLOCKED P1/device |
| P0 | Q-01 | Data integrity | No uninstall/wipe/clear, no false ownership, no delete user data, no old evidence overwrite | Entire task | NOT RUN |
| P1 | Q-02 | QA device gates | ARM64/ARMv7/OEM/SD/real16KB/physical FPS/thermal/battery; static alignment not runtime | External QA | BLOCKED device |
| P1 | Q-03 | Complete test suite | Flutter analyzer, all Flutter tests with 4 P1 failures visible, 137 JUnit baseline, post-fix runs | Each owner | NOT RUN |
| P1 | Q-04 | QA APK | Fresh main.dart package, verified ABI+ZIP+ELF16KB+licenses/cert and reproducible recipe | P2/P3 | NOT RUN |
| P0 | Q-05 | TASK08/QA5560 | Preserve offline AVD; guest restoration/SAF/owner history not proven, independent permission gate | External | BLOCKED |

## Evidence bắt buộc cho từng test

```
test_id:
route/control_id:
preconditions/disposable_fixture:
owner: P1 | P2 | P3 | SHARED | EXTERNAL
environment: host/widget/native/physical, device serial/API/ABI (nếu có)
steps:
expected_behavior:
actual_behavior:
status: PASS | FAIL | PARTIAL | NOT RUN | BLOCKED | N/A
evidence_uri_or_relative_path:
failure_log_or_bug_id:
fixed_in_files_if_owned:
regression_test_before_after:
```

## Báo cáo coverage và stop-condition

- `runtime controls found`, `uniquely tested`, `unreachable`, `untested`, `blocked`, `N/A` cùng *phương pháp đếm*; source declarations thống kê riêng.
- Không cho P1 FAIL được tính vào `P2/P3 all green`, nhưng cũng không giấu 4 P1 test đang đỏ.
- Không gọi `FULL APP PASS` nếu chưa nghiệm thu human/device; TASK09B có thể `SCOPED PASS` trong khi full app vẫn `PARTIAL`.
- P0 data safety source mutation/installer incident → dừng test có nguy cơ, giữ dữ liệu và yêu cầu quyền mới; không làm lại incident QA5560.
- Sau mỗi fix: chạy lại smoke màn hình liên quan, full Flutter/native nếu phù hợp và kiểm giữ nguyên 7 TASK09 fixes.
- Khi P1 Person1 ready và nguồn merged ổn định, tạo báo cáo `TASK10 READY YES/NO` dựa trên evidence thật, không đoán.
