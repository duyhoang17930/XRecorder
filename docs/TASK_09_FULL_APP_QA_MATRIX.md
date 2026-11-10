# TASK 09 — Coverage Matrix / Checklist khởi tạo

**Ngày soạn:** 09/11/2026. **Tất cả các ô mặc định `NOT RUN`:** đây là test plan, không phải bằng chứng đã chạy. Codex phải đọc routes/source để sửa tên và tạo từng row control thực tế. `P1` audit-only; `P2/P3` audit + fix.

## Cách điền

Một control xuất hiện ở 2 state có thể cần >1 test. Bất kỳ màn hình mới có trong source phải thêm vào inventory, kể cả onboarding/permission/help/error/overlay/debug-only visible. Mỗi row triển khai cuối phải có **ID, path/widget, event, expectation, owner, test type, status, evidence ref, issue ref**. Status: `PASS`, `FAIL`, `PARTIAL`, `NOT RUN`, `BLOCKED`, `N/A` (+lý do). Không biến `N/A` thành PASS.

| ID | Vùng / màn hình cần audit | Tương tác và biến thể phải tách test | Owner | Initial |
|---|---|---|---|---|
| NAV-01 | App launch / splash / startup | Cold/warm start, initial route, loading/error, permission state, background/resume, back-exit, forced-restart safe | Shared | NOT RUN |
| NAV-02 | Bottom Navigation | Tất cả tab, re-tap scroll top, state preservation, tab switch while loading, back stack, 320dp/411dp/text200 | Shared/P2/P3 | NOT RUN |
| NAV-03 | Create / action sheet | Mỗi capture/editor/photo/screenshot CTA, disabled guards, back/dismiss/reopen, no duplicate action | Shared/P1 audit | NOT RUN |
| NAV-04 | Shortcuts/deep links | Edit video/Photo static and pinned; cold/warm, invalid target, restore state, no unintended capture | P2/P3 | NOT RUN |
| P1-01 | Recording Home / quick actions | Start/stop/pause/resume, audio selector, no double start, display orientation changes | P1 READ-ONLY | NOT RUN |
| P1-02 | Recording setup/settings | Every resolution/FPS/codec/bitrate/quality switch, open-only mutation R1, portrait capability R2, persistence | P1 READ-ONLY | NOT RUN |
| P1-03 | Screenshot / native capture | System permission/cancel/revoke, icon, result navigation, latency, real bytes on safe QA | P1 READ-ONLY/P2 handoff | NOT RUN |
| P1-04 | Floating overlay / tool ball | Show/hide, start/pause/stop, drag, draw, overlay permission denied, overlays after background | P1 READ-ONLY | NOT RUN |
| P1-05 | Facecam & draw | Front camera permission, position/size/persistence, no camera device, preview/output parity, draw visibility | P1 READ-ONLY | NOT RUN |
| P1-06 | Region capture | x/y origin, width/height validation, pixel crop oracle, rotation/cancel/error (R4) | P1 READ-ONLY | NOT RUN |
| P1-07 | Recording fail/recover | Storage low/interrupt/file damaged/journal restart, production MP4 recovery invoked (R5), saved output ownership | P1 READ-ONLY | NOT RUN |
| MED-01 | Video Library | Empty/large, auto-index, 5 sorts, search, filter, query retention, screenshot vs video separation | P2 | NOT RUN |
| MED-02 | Photo Library | Empty/large, thumbnails rotation/cache, tap/photo editor, multi-select/actions, text200, RTL | P2 | NOT RUN |
| MED-03 | Media detail/preview | Play/pause/seek/audio, screenshot/action sheet, error if deleted, orientation/back and return scroll | P2/P3 | NOT RUN |
| MED-04 | Rename / delete / trash / restore | Confirm/cancel, owned vs external, double-submit, undo, missing source, byte integrity, content URI grants | P2 | NOT RUN |
| MED-05 | External SAF / Choose folder | Picker accept/cancel, tree and child, revoked/disconnected, copy vs move source deletion ordering, read-back SHA | P2 | NOT RUN |
| MED-06 | 1000+ items / performance | Continuous scroll, accessibility, cold/warm cache, memory/raster; 60fps only if measurements support | P2 | NOT RUN |
| EDI-01 | Editor project/list | New/import/open/rename/duplicate/delete, missing source dialog, old draft migration, process-restart recovery | P3 | NOT RUN |
| EDI-02 | Timeline | Insert still/video/audio, trim/split/reorder/merge/duplicate, relink/crop/flip/rotate/speed, drag/seek, undo/redo | P3 | NOT RUN |
| EDI-03 | Editor preview | Play/pause/scrub/update effects, keep playhead, stale loading/dispose/reload, real mixed sources, ANR R7 | P3 | NOT RUN |
| EDI-04 | Audio editor | 8 tracks, source trim/offset/fades/volume/headroom, voice deep/bright/robot, RNNoise, silent/invalid URI | P3 | NOT RUN |
| EDI-05 | Layer editor | Text/sticker/drawing add/edit/remove, transforms, start/end, order, preview/export pixel parity | P3 | NOT RUN |
| EDI-06 | Subtitle editor | Manual/add/edit/split/merge/delete, overlaps/out-range, style/wrap, speed retime, long text, SRT file/clipboard | P3 | NOT RUN |
| EDI-07 | Export UI / history | Start/progress/indeterminate, cancel/retry, queued/running/finalizing/failed/completed, actual output URI/saved notice | P3 | NOT RUN |
| EDI-08 | MP4/GIF output | Size/bitrate/FPS/repeat, full frame decode, PTS, audio sync, source unchanged, MediaStore pending ownership | P3 | NOT RUN |
| PHO-01 | Photo editor | Crop/rotate/flip/pen/shape/text/arrow/width/color, undo/redo, save copy vs source protection | P3 | NOT RUN |
| PHO-02 | Photo formats | All EXIF 1–8, sRGB/color alpha, PNG/JPEG quality, resize presets, corrupt/large input, cancel | P3 | NOT RUN |
| ASR-01 | Transcription setup | No model, tiny/base/small choice, vi/en/auto, locale distinction, duration <=10min, RAM preflight | P3 | NOT RUN |
| ASR-02 | Model manager | Download/import/hash/verify/progress/cancel/delete, blocked active-job delete, offline/no network | P3 | NOT RUN |
| ASR-03 | Recognition job UI | Start/poll/cancel/restart/interrupted, matching project only, progress, silence empty, no fake segments | P3 | NOT RUN |
| ASR-04 | ASR to subtitle/output | Edited audio extraction, timestamps/review/cue editor, SRT clipboard/file, video burn-in real bytes | P3 | NOT RUN |
| SET-01 | Settings landing | Every card, row, link, help/about/Q&A, back/re-tap, navigation and unavailable/error state | Shared/P1 audit | NOT RUN |
| SET-02 | App preferences | All existing theme/locale/switch/slider/select, save/restart/restore defaults; no implicit write on read | P2/shared | NOT RUN |
| SET-03 | Permissions/Notifications | Request/deny/permanent deny/settings-return/revoke, toast/snackbar/dialog feedback and channel settings | Shared/P1 audit | NOT RUN |
| SET-04 | Recording preferences | Every option, explicit save semantics, orientation behavior, restored value after relaunch (R1/R2) | P1 READ-ONLY | NOT RUN |
| UI-01 | Every dialog and bottom sheet | Open/confirm/cancel/outside/back/rapid re-open/error/validation; focus/keyboard and no double actions | All by owner | NOT RUN |
| UI-02 | Notifications / Snackbars | Saved after commit; warning/info/loading/cancel; appropriate timeout/action/retry; concise global text | All by owner | NOT RUN |
| UI-03 | Accessibility & HCI | Touch targets, semantics labels, one-hand reach, contrast, focus order, TalkBack gesture by human, reduced motion | All by owner | NOT RUN |
| L10N-01 | en, vi, es, pt_BR | Every route/dialog, fallback, overflow, plural, number/time formatting and settings persistence | All by owner | NOT RUN |
| L10N-02 | fr, de, id, hi | Every route/dialog, 200% text, long translation labels, system language switch | All by owner | NOT RUN |
| L10N-03 | ja, ko, zh_Hans | CJK font/line wrapping, long filenames, file picker labels, subtitles styles | All by owner | NOT RUN |
| L10N-04 | ar / RTL | Mirroring directional icons appropriately, focus/tab ordering, numeral layout, overflow, TalkBack labels | All by owner | NOT RUN |
| SYS-01 | Lifecycle & device constraints | Rotation, background, process death, low memory, storage insufficient preflight, API24–36 as available | All by owner | NOT RUN |
| SYS-02 | Data security / integrity | Original source never overwritten, SAF consent, owned checks, no orphan publication, failure logs, no cross-UID fake ownership | P2/P3 | NOT RUN |
| SYS-03 | Native/device matrix | Authorized isolated AVD, physical ARM, OEM/SD/real16KB, FPS/thermal/battery, camera/mic capture/human usability | Split P1/P2/P3 | NOT RUN |
| SYS-04 | QA5560 recovery | Read-only host verified; guest/grants/draft remain unproven. Do NOT boot/install without new permission | External gate | BLOCKED |
| SYS-05 | APK & licenses | Fresh main.dart debug/release candidate, correct target, ABI/16KB/notice, QA install only on authorized device | P2/P3/shared | NOT RUN |
| INT-01 | P1→P2→P3 E2E | Real capture→MediaStore→Library→Editor/ASR→export→gallery/reopen; requires Person1 readiness and device permit | TASK10 gate | BLOCKED |

## Coverage report phải tính đúng

- Screen inventory: discovered screen count; inspected; fully tested; unavailable.
- Control coverage: found controls; directly exercised; static-only reviewed; failed; not-run; blocked. Count by P1 and P2/P3 separately.
- Scenario coverage: success/error/permission/lifecycle/locale per feature, tránh đánh đồng control coverage với all-state coverage.
- Fix verification: issue ID → red test → source patch → green test → native evidence (nếu cần).
- Release blockers: unresolved P0/P1, P1 handoff, QA5560 guest uncertainty, physical device and final E2E.

**Không được kết luận DONE chỉ vì đã liệt kê hết rows.** Thêm mỗi route/control mới tìm được từ source và chỉ gắn PASS sau khi thực thi có bằng chứng.
