# TASK 08 — Performance & Reliability QA Acceptance Matrix

**Ngày:** 08/11/2026 · **Dự án:** 3HRecorder / P2+P3 · **Scope:** kỹ thuật và nghiệm thu có evidence; P1 read-only.

## 1. Trạng thái ban đầu

Các giá trị từ báo cáo TASK07 (chỉ tham chiếu, **không tự coi là PASS của TASK08**):

| Thông số | Baseline / Reported | Điều cần TASK08 xác nhận |
|---|---|---|
| Library build p95 | 4.636 → 8.202 ms | Có thể so sánh cùng dataset & profile mode không? |
| Library raster p95 | 41.426 → 45.602 ms | Nguyên nhân thay đổi là code hay host/SwiftShader? |
| Media count | 1013 baseline / 1015 final-query | Thống nhất manifest để phép đo có giá trị |
| QA Flutter / JUnit | 228 / 10 pass | Chạy lại trong đúng source TASK08 |
| ASR history | Old cap20 từng làm mất QA jobs; latest77 jobs retained | No silent prune ở 21, 100, 1000+ jobs |
| ASR low RAM | 2GiB 16KB từng LOW_MEMORY kill | Controlled reject/success, không fake PASS |
| Output | 12 audio/layer MP4 + 4 subtitle MP4 đã được test | Không hồi quy sau refactor |
| APK unsigned universal / arm64 split | 66.456 / 23.746 MiB | Size delta và ABI correctness |
| Android devices | API36, API34, 16KB x86_64 | API24–35, ARM/OEM/SD thật chưa chứng nhận |
| P1 capture | Không được sửa trong TASK07 | TASK08 không sửa và không tự nghiệm thu |

## 2. A — Performance profile

| ID | Workload | Metric / oracle | Evidence |
|---|---|---|---|
| PERF01 | Library cold first open, 1000+ assets | startup-to-content, first-thumbnail, count, non-blocked controls | profile trace + screenshot |
| PERF02 | Library warm reopen | p50/p95/p99 build/raster, dropped/janky frames | raw frame json |
| PERF03 | 30 swipes, same 320dp corpus, 5 trials | p50/p95/p99 and >16.67/>33.33ms counts | manifest + trace |
| PERF04 | Same at 411dp | No severe regressions relative to own baseline | trace + device flags |
| PERF05 | Query, sort ×5, folder toggle, empty states | Stable state, response latency, no repeated full scan | UI integration + CPU |
| PERF06 | Dark/Light, text 200%, `ar` RTL | Correct layout; performance measured for slow locale case | screenshots + trace |
| PERF07 | Rapid tabs/reselect + scroll | No stale result, duplicate search or repeated load | logs + widget tests |
| PERF08 | Open editor 10x, preview/scrub/pause | Cold/warm latency, active native resource bounded | native trace + PSS |
| PERF09 | Audio effects and timed layers | Preview/export parity + latency | MP4/pixel/signal |
| PERF10 | 20 native export cancel/retry | No orphan, duplicate, callback-after-dispose, leak | export queue logs |

**Interpretation:** Flutter profile is required for UI frame timing; software GPU/AVD cannot certify physical FPS. Distinguish p95 calculation and warm-up; if baseline mismatched, mark `INCONCLUSIVE`, do not claim fixed regression.

## 3. B — Memory, CPU, thermal

| ID | Test | PASS expectation / decision |
|---|---|---|
| MEM01 | 10 Library open/scroll/close cycles | No unexplained retained thumbnail/native heap growth |
| MEM02 | 10 Editor open/close cycles | Player/SurfaceView resources released; active previews return to baseline |
| MEM03 | 30 preview reload and 20 cancel export | No late callbacks/ANR/release failure/duplicate files |
| MEM04 | Whisper Tiny/Base/Small sequential jobs | Report PSS/USS/CPU, model load vs inference, RTF and model isolation |
| MEM05 | 2GiB low-memory trial | If insufficient, reject before JNI; if runs, show real completed inference. OS kill is FAIL evidence |
| MEM06 | 3GiB+ inference and 10min bound | Bounded memory and cancel/resume; thermal only with physical device |
| MEM07 | RNNoise 8 tracks, voice filters | Source timing/audio sample count preserved; buffers released |
| MEM08 | Background / foreground / process stop | Draft/job consistency; no fake completed after interruption |

## 4. C — Data integrity / history

| ID | Test | Expected |
|---|---|---|
| DATA01 | New jobs 20→21→100→1000 | No automatic history deletion, stable IDs/pagination |
| DATA02 | 77 existing jobs (QA fixture) + app restart | Exact metadata/segments/readable order retained |
| DATA03 | Legacy vi/en/auto, model/language migration | Backward-compatible, untouched old values |
| DATA04 | Missing/corrupt/future-version history | Isolate/read-only/recover valid data; no overwrite |
| DATA05 | AtomicFile/journal write denied | Fail safely with warning; preserve prior file |
| DATA06 | Native export finalizing restart | One published URI, no duplicate, no Saved before commit |
| DATA07 | Restore/Trash with SHA256 | Original exact bytes, missing-source failure safe |
| DATA08 | Cancel/stalled model import | Existing verified model remains; no partial installed weights |
| DATA09 | SAF grant revoked/disconnected | Fail before destructive move; source survives |
| DATA10 | UTF-8/RTL/CJK project, SRT, filename | Exact read-back; no replacement/missing characters |

## 5. D — Device / API matrix

| Runtime | State before TASK08 | Required evidence to mark PASS |
|---|---|---|
| API36 x86_64 SwiftShader QA | Previously tested | Actual TASK08 app install, profile/media/ASR/current file integrity |
| API34 x86_64 QA | Previously subset tested | Current app native and restart regression |
| 16KB x86_64 QA | Previously runtime tested | Current native JNI/MP4/SAF/RTL restart; actual page size |
| ARM64 real | NOT RUN | Package/runtime, scroll and ASR PSS/thermal/battery |
| ARMv7 / older API | NOT RUN | Native library availability, codecs, MediaStore permissions |
| OEM with SD/removable provider | NOT RUN | SAF copy/move/read-back/revoked permission |
| Device with poor RAM/network | NOT RUN | Offline AI and rejection states; network not required after model install |

**Do not touch user personal emulator `emulator-5554`; do not simulate physical measurements.**

## 6. E — Source protection & release hygiene

- [ ] Record `git status` and protected P1 file hashes at TASK08 start and end.
- [ ] No `git checkout --`, `git restore`, `git clean`, `flutter clean`, HEAD-overwrite scripts.
- [ ] No unapproved deletion/cleanup of ~40GiB workspace, QA fixtures, user media/drafts/models.
- [ ] `flutter analyze --no-pub`, `flutter test --no-pub`, native JUnit — actual exit codes.
- [ ] H264/AAC/HEVC/MP4/GIF/SRT/EXIF test corpus decodes; no visual mock counted as native PASS.
- [ ] Android 16KB ELF/ZIP static check and *separate* runtime status.
- [ ] APK split per ABI and universal sizes/hashes, no Whisper weights bundled.
- [ ] All post-fix measurements compared to same-workload/current baseline.
- [ ] Current P2/P3 settings, 12 locales, Flutter ARB, Arabic RTL and ASR language catalog remain functional.
- [ ] No change to P1 native recording/Create/recording settings semantics.
- [ ] No commit, push, PR or release signing.

## 7. Quy tắc nghiệm thu

Each row must report:

```
Test ID / source SHA / APK hash:
Feature/owner and exact changed file(s):
Device API / ABI / RAM / GPU / renderer / profile mode:
Corpus manifest & source SHA or media fixture provenance:
Command / iterations / warm-up:
Before raw metrics / After raw metrics / p95 method:
Result: PASS | FAIL | PARTIAL | INCONCLUSIVE | NOT RUN
Evidence paths (trace/log/pixel/SRT/MP4/JSON):
No source deletion/data loss proof:
Known limitations / next owner:
```

**TASK08 DONE** chỉ khi các implementation lỗi rõ ràng được xử lý, no new regressions, checks có bằng chứng và perf issue được kết luận hợp lệ. Nếu SwiftShader/physical gate không thể đóng, báo PARTIAL đúng thực tế và bàn giao sang TASK09/human QA, không chạy vòng lặp tối ưu vô hạn.

**TASK09 sau đó:** exhaustive screen/button/dialog/Settings flows + manual usability/TalkBack.  
**TASK10 sau P1-ready:** capture→Library→Editor→Export native end-to-end.
