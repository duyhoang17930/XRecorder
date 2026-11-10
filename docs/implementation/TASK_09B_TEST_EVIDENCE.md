# TASK 09B — Bằng chứng triển khai và kiểm thử

HEAD `9afcb124069d905dd4b285c890ca0709f5548b68`, branch `main`, dirty work được giữ. Evidence mới tạo độc quyền dưới [run_20261109T113727956224Z_f64203](../../build/verification/task09b/run_20261109T113727956224Z_f64203/), không ghi đè TASK07/08/09. Các path ngắn trong bảng tính từ run này.

## Môi trường và an toàn

Native target duy nhất: **emulator-5570 / ThreeHRecorder_TASK09B_API36 / API36 / x86_64 / SwiftShader**, UID app **10217**, package `com.xrecorder.xrecorder`. Không target emulator5554 hoặc QA5560, không boot QA5560, không root/chmod/grant/bypass permission. Corpus và mọi item bị Rename/Move/Trash/Restore là fixture QA mới, có backup. Không uninstall/clear/wipe, commit/push hoặc xóa evidence.

Safe installer: [tool/run_qa_existing_app.py](../../tool/run_qa_existing_app.py), chỉ `adb install -r`, kiểm serial/AVD/UID/active capture+jobs/storage margin và backup private/external/hash trước update. Không gọi Flutter installer fallback. Driver attach vào app đã cài; `--require-complete-report` yêu cầu final PASS, không tin exit0 khi JSON vẫn IN_PROGRESS. `--keep-app-running` là quy tắc cho các Flutter drive flows khác, không phải lệnh cài đặt đã dùng ở đây.

## Host và native regression

| Check | Kết quả / exit | Evidence |
|---|---|---|
| Full `flutter test --no-pub --machine` trên candidate được giữ | **317 PASS / 4 FAIL P1**, exit1; không skip. Sau đó chỉ sửa braces trong native harness mới và docs, không đổi behavior sản phẩm | [summary](../../build/verification/task09b/run_20261109T113727956224Z_f64203/flutter_full_summary_v3.json), [raw](../../build/verification/task09b/run_20261109T113727956224Z_f64203/flutter_full_v3_boundary_candidate.jsonl) |
| Final `flutter analyze --no-pub` | **No issues**, exit0, 4,7s | `final_analyze_v2.log`, `final_analyze_v2_result.json` |
| Native `testDebugUnitTest` + androidTest build, `--rerun-tasks` | **137/137**, 22 suites, 0 fail/error/skip; exit0, 90 tasks executed | [JUnit summary](../../build/verification/task09b/run_20261109T113727956224Z_f64203/junit_final_v6/summary.json), `native_final_junit_and_process_build_v6.log` |
| `python -m unittest discover -s tool/tests -p test_run_qa_existing_app.py -v` | **12 PASS**, exit0 | `final_python_safety_v2.log`, result JSON |
| History/crop locale focused widget/layout tests | **80 PASS**; actual PhotoTools controls, không chỉ key existence | `history_localization_green_v2.log`, `crop_localization_green_v1.log` |
| ExportScreen history UI | **6 PASS**, sizes0/20/21/77/100/1001; explicitly mocked method channel | [test](../../test/task09b_export_history_ui_test.dart); included full317 |
| Source AST current | **419 entries, 0 parse diagnostics**, exit0; 292 controls/41 helpers/86 surfaces | [inventory JSON](../../build/verification/task09b/run_20261109T113727956224Z_f64203/source_inventory_final_v3.json), `final_source_inventory_v3.log` |

Four P1 failures và exact names/repro nằm tại [handoff](TASK_09B_P1_HANDOFF_UPDATE.md). Không cộng teardown, retries, benchmark samples hoặc JUnit helpers thành unique UI acceptance cases.

Final analyzer lần1 bắt một `curly_braces_in_flow_control_structures` trong harness MediaUI; thêm braces, giữ log đỏ `final_analyze_v1.log`. AST tool lần2 dùng app package config không có analyzer nên exit254; lần3 dùng **SDK analyzer đã có**, không thêm dependency ứng dụng. Build chưa chạy ở hai lần bị chặn. Các lỗi này không phải app runtime crash.

## Native tương tác và output mới

| Flow | Thao tác/oracle | Kết quả và evidence |
|---|---|---|
| G1 Settings + editor dialogs | Actual app/bridges, double-action regression, Add drawing và model flows | `native_editor_v2` PASS; không tính tearDown |
| G2 Copy/Move/Trash/Restore | Real DocumentsUI grant; chỉ fixture; source/destination SHA, full MP4 decode | G2 completed trong `native_interactions_v3`; independent `g2_independent_e8d467f3a7a441ecb2552547001a73fa` **5 files SHA exact, 2 MP4 full decode**. G1 harness FAIL trong cùng run không được giấu; G1 chạy sau PASS |
| Drawing real gesture→draft→export | 480px fixture, stroke separators/null, output timed pixel + PTS/full decode | `native_output_model_v1`; `drawing_output_480_d4f68c22f2684be6935871b52981fc39/verification.json` PASS, white pixels1752/1751, duration drift0,033401s |
| Media UI native | Rename Cancel/invalid/Unicode; Copy Cancel/Allow; Move Cancel; Trash Cancel/Confirm; Delete Cancel; Restore; Photo Rotate/KeepEditing/JPEG Save copy | `native_media_ui_v3/emulator_verification.json` PASS. Source1060→restored1062 byte exact; JPEG1063 **360×480**, 2.895B. DocumentsUI trace `native_ui_ef3575837053450a903d77c241848f81` |
| UTF-8 SRT system Save | Manual cue125–3125ms→Save SRT→ACTION_CREATE_DOCUMENT Cancel then Save→verified read-back→Apply | `native_document_v2` PASS; trace `native_ui_b2532bc911bf452b921872baf74747d0`. File131B, SHA256 `bdd72fb9f262a723a8cf6774331240769e1a043a0e2ece96dd15a4498bb4f717`. Flutter text entry simulated test IME; picker là system UI thật |
| Paused still preview | Native ready/paused/renderedFirstFrame; screenshot actual pixels | `native_still_preview_v2` PASS; `still_pixels_b0c6616777034c6ba580b022993e2e62/verification.json`: 4.482 center pixels100% teal. Không suy từ screenshot chụp trước readiness |
| Native export history/faults | Six history sizes, malformed URI, published empty URI, valid publication, corrupt backup, AtomicFile obstruction | `native_export_recovery_green_v4`: **11 cases PASS**, live journal SHA exact. Published empty fixture giữ lại, không xóa row để che lỗi |
| Models | Tiny checksum import, wrong model reject, remove/reimport only new model, busy remove reject; download/cancel thật | Native model scenarios PASS trong scope local; full download **BLOCKED DNS** trên AVD sau attempts. Không server/paid API/transcript giả |

Real Unicode Copy file SHA256: `f7d881653f5f6aeae67c0978aa315c4a11173b7cdd69ac29c1770119ada3dd20` (4.938B). Destination có prefix `3H_<8hex>_TASK09B_...`, tên chứa Tiếng Việt/日本語/العربية/emoji; không giả định tên bắt đầu TASK09B. Journal trong native report lưu content URI đầy đủ.

## Process death thật và publication

New [instrumentation](../../android/app/src/androidTest/java/com/xrecorder/xrecorder/qa/Task09BExportProcessInstrumentation.java) dùng **production ExportQueue/Media3** trong context queue riêng; production draft mới lưu qua EditorBridge. Host chỉ force-stop app UID10217 sau khi encoder đang running, progress0..100 và partialMP4 >32B; backup context dở dang trước recover. Main export/ASR histories không bị thay bằng fixture.

- [Run640×480](../../build/verification/task09b/run_20261109T113727956224Z_f64203/export_process_19e26e3d3525480b990a3dcaf0771501/verification.json): restart → Failed/noURI → **explicit Retry** → đúng một MediaStore publication. Source/draft/main journals byte exact; SAF persisted tree còn grant và target đọc lại đúng SHA sau process death. Retry21.854ms; MP4 URI1065, 1.467.946B, SHA256 `3ad590640e1c1eb2a650ab55dbec448e2541b88ef1c20ae95347dcef065bdfaa`.
- [Independent verification](../../build/verification/task09b/run_20261109T113727956224Z_f64203/export_process_19e26e3d3525480b990a3dcaf0771501/independent_validation_v2_c50a529f176849fca724168e1e186101/verification.json): **full decode MP460s/640×480, monotonic packet PTS, pixels tại0,5/30/59,5s**, A/V duration drift0,033401s. JPEG360×480 full decode và bốn góc xoay clockwise đúng màu.
- Run trước `export_process_538e2bee4a724a2b94002ba730f8856c` cũng PASS recovery/retry, output96×64. Fixture dùng hai key không thuộc contract; failed640×480 oracle được giữ, validator v2 xét source/effects hợp lệ rồi xác nhận96×64. Fixture mới dùng effects.height480/aspect4:3, không hạ threshold để lấp lỗi.

Đây là **retry encode từ source**, không phải vá partialMP4 hoặc seamless resume. Log “Process crashed” ở start instrumentation là fault cố ý, không phải spontaneous crash. Fixture still/silence chỉ kiểm timeline/duration, **không chứng minh audible synchronization**.

## G4 global và coverage

**12locale × 2portrait widths320/411dp/font200 + 4locale landscape920×411** có completed per-locale assertions và PNG/XML. Có raw runs FAIL do harness sau khi các locale trước hoàn tất; chỉ các phần đã hoàn tất được tính, và phần còn lại có run PASS riêng. Đọc [G4 report](TASK_09B_GLOBAL_HCI_REPORT.md) để biết union và exact paths.

[CSV](TASK_09B_INTERACTION_COVERAGE.csv): 15.156 rows, 241 unique asserted action groups; 12.098 Flutter node-state observations, 2.802 Android node-state observations, 435 XML; **không phải**15.156unique buttons. Chưa có exhaustive unique-control denominator; không công bố full-app coverage percentage.

## G5 performance đo trước → sửa → đo lại

Corpus giữ nguyên **1.013 real MediaStore PNGs**, 1.013 distinct SHA; [source archive verification](../../build/verification/task09b/run_20261109T113727956224Z_f64203/library_source_archive_0c4ac8d90dcf40a28609a47c20465ba8/verification.json) full-decode tất cả. Mỗi A/B run so bytes với snapshot riêng có từ trước workload. Size/quality/hình ảnh không bị giảm để cải thiện kết quả.

Method: profile/SwiftShader, density160, 320 hoặc411dp/font200; fixed corpus; **2warmups + 3measured trials**, mỗi trial30swipes500px/350ms/60Hz. Đo Flutter FrameTiming build/raster/totalSpan; native PSS mỗi sampler interval. Không so Flutter raster với HWUI như cùng metric. Baseline và candidate giữ `_InkSparkleFactory`; candidate chỉ bọc thumbnail row bằng RepaintBoundary.

| Viewport | Median build p95 trước→sau | Median raster p95 trước→sau | Raster >16,67ms trước→sau | PSS max MiB trước→sau |
|---|---|---|---|---|
| 320dp | 4,809→4,542ms | **19,437→18,572ms (−4,45%)** | 173/1.874→146/1.839frames | 190,64→187,47 |
| 411dp | 4,651→4,503ms | **19,985→19,248ms (−3,69%)** | 222/1.786→180/1.844frames | 192,75→187,81 |

**Giữ tối ưu nhỏ**, không có regression đo được ở build/memory trong workload này. Cache bounded≤64entries/8MiB, scroll không rescan MediaStore, source1013 byte exact ở cả4runs. [Raw summary](../../build/verification/task09b/run_20261109T113727956224Z_f64203/profile_ab_summary_v1.json), [decision/memory](../../build/verification/task09b/run_20261109T113727956224Z_f64203/profile_ab_decision_v1.json), [recipe](../../build/verification/task09b/run_20261109T113727956224Z_f64203/profile_ab_v1.py).

Ba trial/fixed-order A/B chưa có randomized confidence interval. Raster p95 vẫn >16,67ms; **không claim60FPS**. SwiftShader không chứng nhận phone GPU; sampled PSS không chứng minh không leak/thermal/battery.

Startup được đo riêng, không gộp với raster benchmark: first main launch sau cài5.992ms; ba process-cold lần sau6.141/5.137/5.064ms. [A/B main APK TASK09/current](../../build/verification/task09b/run_20261109T113727956224Z_f64203/main_startup_ab_e0f130a1d7d448c88a1972f1e90153a3/startup_ab.json) trên cùng QA/corpus: baseline8.412/5.375/4.986ms (median5.375); current5.060/5.630/5.502ms (median5.502). Cùng versionCode/debug cert, backup mỗi install-r, Settings/draft/live histories SHA exact; **đã trả lại current main APK**. Đây là Android `am start -W TotalTime`, không phải Flutter first-frame/raster. Chênh median+2,36% trong3samples không đủ kết luận regression mới; startup vẫn chậm và **chưa chứng minh tối ưu**, cần profiling sâu/physical gate. P2 media worker và lazy export/ASR init đã đọc, không sửa P1 để thay số đo.

## QA APK chính và recipe

[Build manifest](../../build/verification/task09b/run_20261109T113727956224Z_f64203/final_main_apks_v1.json): `flutter build apk --profile --no-pub --target=lib/main.dart --target-platform=android-arm,android-arm64,android-x64 --split-per-abi`, exit0,118,9s. Ba ABI có Flutter engine/app/whisper/c++ đầy đủ. Nonfatal CupertinoIcons font warning giữ trong raw build log; không thêm dependency chỉ để tắt warning.

[Compaction manifest](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/manifest.json), [recipe](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_main_qa_v1.py): mỗi APK **231live payload entries SHA exact**, same public debug cert `71e23e330d606237f63f66aa7f24929160038551b468be497bf8229fa28669cf`; zipalign/apksigner/tool verify_release.py exit0. Raw APK vẫn giữ. Đây là QA debug signing, không release signing/publish. ZIP/ELF64 16KB checks **không thay real16KB runtime**.

| ABI | QA APK | Bytes / SHA256 |
|---|---|---|
| arm64-v8a | [QA ARM64](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-arm64-v8a.apk) | 36.438.354 / `7bf40d34b84a3be4c2a7e383ff3f8a80d0d3582949461e6da876559144db7f6f` |
| armeabi-v7a | [QA ARMv7](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-armeabi-v7a.apk) | 33.390.940 / `b701840dcfd798d63a1f097dd753c076c7ff6facc348ca66018f5ac3af222e87` |
| x86_64 | [QA emulator](../../build/verification/task09b/run_20261109T113727956224Z_f64203/compact_qa_v1_c7f8e140201d4d81b9687000f5538cfb/TASK09B-main-QA-v2-x86_64.apk) | 38.175.043 / `dceb92fe354314dda6b3e095ab18864a11224173639802cd6834906d4673e88f` |

[Safe main update](../../build/verification/task09b/run_20261109T113727956224Z_f64203/final_main_safe_update_v1/runner.json): install-r SUCCESS, UID không đổi, backups/chunk hashes giữ lại; APK main đang được giữ cài trên5570.

Native package smoke **6nhóm PASS** theo union5completed cases ở [trace v2](../../build/verification/task09b/run_20261109T113727956224Z_f64203/native_ui_7a2beb51da9f41059a58bfecd12dd4b7/main_package_smoke.json) và Photo riêng ở [trace v3](../../build/verification/task09b/run_20261109T113727956224Z_f64203/native_ui_1f7a83f5795d4fe78749cc400b85fa7a/main_package_smoke.json): cold launch, tabs/Create/Back, Photo Preview actual teal pixels + PhotoTools root Back, Settings Reset Cancel, Android keyboard Help no-match/warm-topic, actual launcher shortcut dialog/Cancel. Preferences trước/sau exact; không Reset Confirm/Pin Confirm/capture. V2 whole-run FAIL do locator `Photo Preview` khác chữ hoa với actual `Photo preview`; v3 chỉ chạy lại ca này, thêm pixel oracle, không sửa app. V1 preflight parser UID dừng vì package-prefix query trả thêm androidTest; chọn exact package line rồi vẫn bắt UID10217. Cả hai lỗi harness được giữ, không tính product fix.

**Bổ sung2shortcut flows PASS**: Photo và Video **Pin Confirm qua launcher thật**, tap icon Home khi app warm và sau force-stop app idle; Photo mở Photo Library, Video mở Editing Studio, PID cold khác warm. [Trace cuối](../../build/verification/task09b/run_20261109T113727956224Z_f64203/native_ui_93462000268b4c759a1bbd688e746d9d/shortcuts.json), `main_shortcuts_v2.log`. Preferences exact, hai shortcut QA mới giữ lại. V1 đã Confirm pin nhưng Home xảy ra trong transition khiến locator còn thấy app; giữ [raw trace](../../build/verification/task09b/run_20261109T113727956224Z_f64203/native_ui_7cd8864ad0d340f89a29491849b08db8/shortcuts.json). V2 chờ launcher foreground rồi tiếp tục **icon đã tạo**, không pin lại hoặc xóa shortcut/evidence. Hai flow bổ sung tách khỏi6package smoke và241CSV groups.

## Preservation và cleanup có giới hạn

[Preservation manifest](../../build/verification/task09b/run_20261109T113727956224Z_f64203/preservation_final_v1_8a2a65dc5c05469daf3e38dfa69559e3.json): **1.095original files còn**, không file gốc mất; **569oldTASK09evidence/2.548.967.105B** và **60retained host fixtures** hash exact. **32/33protected files byte exact**; shared models.dart chỉ helper P3 drawing, mọi text ngoài helper khớp snapshot. SettingsController exact. HEAD giữ nguyên, staged/unmerged rỗng.

21file ban đầu được thay có scope TASK09B, gồm13ARB + product/QA harness; không nói toàn bộ source byte exact. Các patch TASK09 ngoài phần mở rộng có chủ đích giữ nguyên; full regression hiện các regression tests vẫn đạt.

Refactor dùng lại helpers modal/reveal/frames/probe; bỏ **một driver screenshot TASK09B mới, không có consumer**, sau khi archive/hash vào `unused_task09b_driver_archived_v1.dart` và `cleanup_own_unused_driver_v1.json`. Không xóa docs/task inputs/evidence cũ hoặc test có ý nghĩa để giảm số file.

## Những lần thất bại vẫn lưu và gate ngoài

Raw G4 screenshot timeout/partial exit0, Arabic Close/lazy Undo locators, empty request/ACK race, MediaUI spinner wait, SRT IME/notice timing, DTO optional revision, sort locator, first96px drawing oracle và first output-dimension assumption đều được giữ trong run. Fix harness không được tính thành product fix, không dùng run incomplete làm whole-run PASS. [Register](TASK_09B_BUG_REGISTER.md) liên kết red→green.

Reuse TASK09 actual22outputs/19MP4+GIF decode,13audio variants (8tracks/RNNoise signal oracle), real vi/en/auto/silence/600s ASR có provenance tại [evidence cũ](TASK_09_TEST_EVIDENCE.md); không chạy lại các engine case đã đạt khi chưa đổi engine behavior liên quan. Chưa có human listening/TalkBack/one-hand, ARM/OEM/SD/real16KB/thermal/battery hoặc P1 real capture. QA5560 recovery vẫn PARTIAL theo hồ sơ riêng, không phát sinh guest thao tác trong TASK09B.

Sau các phép đối chiếu APK/shortcut, [preservation cuối](../../build/verification/task09b/run_20261109T113727956224Z_f64203/preservation_final_v1_7929eb3d28a54024a61c275b8bdec6c9.json) vẫn PASS cùng1095/569/60/32-of-33counts. Git HEAD giữ nguyên, staged/unmerged rỗng; main QA mới nhất được giữ cài. Tài liệu UTF-8/relative links/checklist IDs được kiểm riêng, không sửa raw logs để làm đẹp kết quả.
