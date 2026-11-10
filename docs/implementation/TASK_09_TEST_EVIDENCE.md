# TASK 09 — Lệnh kiểm thử, output và bảo toàn dữ liệu

Ngày 09/11/2026. Root evidence duy nhất: [run_20261109T091518633188Z](../../build/verification/task09/run_20261109T091518633188Z/). Các đường dẫn log dưới đây tương đối với root này. File cũ, log lỗi, partial transfer, fixtures và APK các phiên bản đều được giữ; không có overwrite từ Git HEAD.

## Môi trường và baseline

- Branch `main`; HEAD đầu/cuối `9afcb124069d905dd4b285c890ca0709f5548b68`. Ban đầu staged/unstaged rỗng, có 5 Markdown untracked của người dùng. Snapshot SHA: `source_before.json` (1080 file), `protected_before.json` (33 file P1/shared). Không có conflict/unmerged entry.
- Flutter `D:/Android/flutter` 3.47.8, Dart 3.13.7, JBR21 `D:/Android/jbr`, Android SDK trong `C:/Users/dangh/AppData/Local/Android/Sdk`.
- Native chỉ trên AVD mới `ThreeHRecorder_TASK09_API36`, serial **emulator-5568**, API36 x86_64, page4096B, RAM3072MiB, SwiftShader, không cửa sổ, không snapshot load/save. `emulator_identity.json`/`device_boot_verified_v1.json` ghi cấu hình và app ban đầu chưa có. Không clone userdata từ AVD người dùng.
- Không có command target QA5560 hoặc emulator5554. Guard tooling bổ sung chặn serial/name recovery trước ADB; không thử guard trên dữ liệu thật.

| Lệnh / phép thử | Baseline | Sau sửa / kết quả | Log |
|---|---|---|---|
| `flutter analyze` | PASS, 4.2s | **PASS**, 2.5s analyzer / 4.36s lệnh cuối | baseline_analyze.log; final_analyze_v6.log |
| `flutter test --reporter expanded` | **271 PASS / 5 FAIL**, ~57s | **285 PASS / 4 FAIL**, 63.59s lệnh cuối | baseline_flutter.log; final_flutter_v4.log |
| `android/gradlew.bat -p android :app:testDebugUnitTest :app:assembleDebugAndroidTest --rerun-tasks --console=plain` | 137 JUnit, baseline có cache | **137/137 PASS, 22 suites, 0 skipped**, 43.92s; 90 tasks executed | final_native_v3.log; final_junit_v3/summary.json |
| `python -m unittest discover -s tool/tests -v` | Chặn recovery AVD có red mock | **10/10 PASS** | safety_recovery_red.log; qa_safety_final_v1.log |
| `python tool/check_l10n.py` | Đọc lại locale resources hiện tại | **PASS 12 locales**, keys/descriptions/Unicode/placeholders | l10n_final_v1.log |
| 49 locale/viewport host layout cases | Có trong baseline suite | **PASS** trong full cuối | global_layout_test.dart; final_flutter_v4.log |
| Portrait canonical tuple diagnostic | Lịch sử có issue | **Tái hiện** portrait disabled / landscape enabled, 2 quan sát | portrait_probe_task09_v1.log |
| `flutter build apk --profile --split-per-abi --target lib/main.dart` | Main baseline build 122s | **PASS v4**, 68.8s lệnh / 65.4s Gradle; compact v5 có cùng live payload | baseline_main_profile_build.log; final_main_build_v4.log; final_main_apk_v4.json |
| `python tool/verify_release.py <APK>` ×3 | Không lấy APK TASK08 làm mới | **PASS 3 ABI**, libs/licenses/assets/64-bit ZIP+ELF16KB alignment | TASK09-main-final-v4-app-*.apk.packaging.log |
| `git diff --check` | Không có diff | Kiểm cuối lưu riêng; không format/sửa P1 | final_diff_check.log |

4 FAIL còn lại đều trong `recording_setup_sheet_test.dart`: stale selection và layout320/360/411. R3 finalizing timeout đã sửa harness, không bỏ test. Số test cuối tăng 13: export race, preview queue, 8 route cases, Settings semantics, 2 Support cases. Không lấy chênh lệch số test làm control coverage. Các analyzer INFO phát sinh trong test mới đã sửa trước lượt cuối; log v2/v5 đỏ vẫn giữ.

## Red → patch → green

| Issue | Red evidence | Green / phạm vi |
|---|---|---|
| R3 bounded finalizing | baseline_flutter.log | r3_bounded_green_v1.log; final_flutter_v4.log |
| Export refresh race | export_refresh_race_red.log | export_surrounding_green_v1.log (25 checks liên quan) |
| Native load queue overlap | preview_load_queue_red.log | preview_queue_surrounding_green_v1.log (23); native rapidPreview |
| Warm route identity | warm_route_identity_red_v4.log (5 FAIL) | warm_route_identity_green_v2.log (43 surrounding checks); full cuối |
| Support duplicate command | support_double_command_red_v2.log (actual2/expected1) | full cuối; share chỉ mock |
| Support input + Settings semantics | settings_support_ui_red_v1.log | settings_support_ui_green_v1.log (77) |
| Root Back / move fallback | root_editor_back_red_v1.log; root_media_move_red_v4.log | root_navigation_green_v1.log (19); full cuối; native root editor/photo |
| Protected QA identity guard | safety_recovery_red.log | qa_safety_final_v1.log (10) |

Các lần fixture/harness sai giữ nguyên: warm-route teardown double-dispose; lệnh Flutter thiếu quyền ghi cache SDK tạo log rỗng; tên test file không tồn tại trong `warm_route_identity_green_v1.log`; import/curly-brace INFO ở test mới; move tap ngoài viewport/chờ spinner; source probe v1 dùng nhầm key `uri` thay `mediaId`. Chúng không được tính thành bug sản phẩm hoặc PASS. Chỉ dừng các process host xác minh đúng command/task temp; không kill IDE/ADB/emulator cá nhân.

## Native backend và kiểm file thực

Target: [task09_backend_regression_test.dart](../../integration_test/task09_backend_regression_test.dart), reuse bốn suite hiện có, bổ sung rapid-preview/600s stress. Build flags:

```text
flutter build apk --profile --split-per-abi
  --target integration_test/task09_backend_regression_test.dart
  --dart-define=QA_PRIVATE_FIXTURES=true
  --dart-define=ASR_MODELS=tiny,base,small-q5_1
  --dart-define=MODEL_FAULTS=true
  --dart-define=TASK08_EIGHT_TRACKS=true
  --dart-define=P2_P3_ADVANCED=true
```

Chạy bằng `tool/run_qa_existing_app.py --serial emulator-5568 --avd ThreeHRecorder_TASK09_API36 --apk <TASK09-backend-x64-profile-v1.apk> --output <backend_native_v1> --sample-memory` và Dart driver attach, không dùng Flutter installer. [Raw kết quả](../../build/verification/task09/run_20261109T091518633188Z/backend_native_v1/emulator_verification.json), `backend_native_v1/driver.log`, `runner.json`, `memory.jsonl`.

**6 ca native đạt**, khoảng10m07s; runner có thêm teardownAll nhưng không gọi đó là tính năng thứ7:

1. Speech real model import/inference/benchmark/cancel/fault/silence.
2. Audio/layers thực, gồm 8 track.
3. Photo/EXIF/profile/JPEG/subtitles/ASR burn-in.
4. Media observer/rename/draft/native preview/MP4/GIF/cancel/retry.
5. Rapid edit → latest speed2×, real surface first frame, preview duration2000ms, export MP4, drain active0/releaseFailures0.
6. Whisper Tiny xử lý 600000ms thật; 57 cue đến600000ms; 600001ms bị từ chối. Input là FLEURS lặp cho stress, không phải hội thoại tự nhiên10 phút.

Đưa **60 retained fixtures** từ host vào app QA bằng tên mới/no-clobber; provenance/SHA nằm trong `native_fixtures_manifest_v1.json`. Hai probe nguồn có tên UUID riêng. `native_fixture_integrity_after_v1.json`: **62/62 SHA exact** sau native suite/update. Không thay media/draft người dùng thành fixture.

Tải **22 output** mới về `decoded_outputs_v1/`, đối chiếu device/host SHA từng file trong `download_manifest.json`: 19MP4, 1GIF, 1PNG, 1JPEG. Chạy:

```text
python tool/validate_editor_audio.py --offline --directory <audio>
python tool/validate_p2_p3_outputs.py <audio> --ffmpeg-directory build/task03/ffmpeg
python tool/validate_p2_p3_outputs.py <photo> --ffmpeg-directory build/task03/ffmpeg --check-subtitle-speed
python tool/validate_p2_p3_outputs.py <media> --ffmpeg-directory build/task03/ffmpeg
python tool/validate_p2_p3_outputs.py <rapidPreview> --ffmpeg-directory build/task03/ffmpeg
```

- **20/20 MP4/GIF** full decode + strictly increasing PTS. Audio signal validator riêng đo trim/offset/fades/mixing/voice/noise và layer timing. Sai lệch thời lượng A/V13 audio output tối đa30.708ms; đây không phải chứng nhận lip-sync bằng người nghe.
- 8-track RMS giữa clip0.007871, toàn bộ sample finite; fade onset thấp hơn giữa clip. Robot có sidebands405/475Hz; deep330Hz; mix440/880Hz.
- SI-SDR noisy speech −5.0026→3.0373dB, cải thiện8.0398dB trong fixture. Không suy hiệu quả cho mọi tiếng nói/mic.
- GIF90×160, 10 frame×200ms=2000ms, loop2; JPEG480×240. EXIF1–8/wide native mean pixel error0. Subtitle2× có khác biệt pixel đúng cửa sổ thời gian.
- Lượt audio validator đầu thiếu bản clean WAV so sánh đã được giữ tại `output_validation_1_v1.log`; thêm đúng fixture có SHA/provenance rồi chạy `output_validation_audio_v2.log`. Không giảm threshold.
- `previewParity` trong báo cáo audio là mảng rỗng: **không** tuyên bố đã đo pixel parity mọi audio/layer composition từ mảng này.

Speech [metrics](../../build/verification/task09/run_20261109T091518633188Z/asr_metrics_v1.json): một JFK English và một FLEURS Vietnamese; WER en0 ở3 model, vi Tiny0.4783/Base0.1739/Small-q5_1=0 theo normalization đã ghi. Đây chỉ một utterance/model/lang, không chứng nhận accuracy toàn dân số. VI elapsed Tiny6579ms/Base15639ms/Small33378ms; auto VI11945/28587/62753ms. Cancel request17ms, drain+next decode531ms. Stress600s elapsed268423ms, inference248570ms. 113 mẫu memory toàn suite: peak sampled PSS541084KiB (~528.4MiB), RSS645708KiB, max69 thread; không có controlled memory A/B hoặc leak proof.

## Native source recovery, UI và SAF

- Missing video→valid surface: `source_recovery_native_baseline_report_v2.json`: error980ms, recovery1000ms, active0/releaseFailures0.
- Missing photo→valid surface: `source_recovery_photo_native_report_v1.json`: error1217ms, recovery553ms, active0/releaseFailures0. Probe dùng actual EditorPreview/CompositionPlayer/Dialog SurfaceView; local messenger chỉ chuyển command, không mock engine.
- Không tái hiện ANR lịch sử. Sequence stale draft→Trash→relink và OEM/hardware conditions chưa khép; R7 vẫn PARTIAL.
- Main v4: `ui_walk_e04db7be9d22450eb07058d852403f4d/trace.json` 7PASS/3FAIL; retest `ui_walk_d543d5c891434102a59f98a8cf7518fe/trace.json` 3PASS sau sửa label fixture/cancel back-stack. Tổng10 nhóm phân biệt đạt; 3 FAIL giữ nguyên và không quy thành lỗi sản phẩm. **41 PNG cuối decode hợp lệ** trong `final_ui_screenshot_validation_v1.json`.
- Native focus5/5 target: `native_focus_navigation_v1.json` và ảnh cùng tên thư mục. Không có human TalkBack listening/gesture acceptance.
- SAF: `saf_copy_verified_v1.json`: tạo `P2P3_QA_TASK09_1794220578199418800` qua New folder→USE THIS FOLDER→ALLOW; copy3285B, SHA nguồn/bản copy exact. Không shell-grant; không thực hiện move/delete nguồn. Bản copy và folder giữ nguyên. Picker cancel sau đó đã kiểm trên v4.
- [13 control-source mappings](../../build/verification/task09/run_20261109T091518633188Z/native_control_tap_mapping_v1.json), [AST419 entries](../../build/verification/task09/run_20261109T091518633188Z/control_inventory_final_v7.json). Không coi số test là số nút đã click.

## Update APK giữ dữ liệu và lỗi truyền backup

Tool an toàn luôn kiểm identity, active jobs/capture, storage margin và UID; cấm uninstall fallback. Backup v3 có ADB raw transfer trả thiếu byte dù có lúc exit0; runner **abort trước install**. Giữ `final_main_install_v3/private_chunk_failure_v1.json`/partials, `final_update_backup_pull_v1/` và `backup_transport_probe_v1/`. Lượt pull cũng thất bại; không coi exit0 hoặc file tar tồn tại là backup đủ.

Dùng archive đầy đủ **đã có SHA và tar validation** ở `final_main_install_v1/backup_private_manifest_v1.json` làm base; so danh sách và SHA **từng file hiện tại**. File không đổi trỏ đúng archive member; file mới/thay đổi có host copy khớp SHA; re-scan stopped app trước install. Không bỏ qua model, cache hoặc evidence để lách check. Incremental backup v2 gặp transfer thiếu ở PNG, chưa được coi là verified; v3 đối chiếu thêm các bản PNG host đã giữ có SHA đúng và tải phần còn thiếu.

- [Backup trước update cuối](../../build/verification/task09/run_20261109T091518633188Z/incremental_backup_verified_v3/verified_manifest.json): **97/97 file current có byte-exact backup**.
- [Update cuối](../../build/verification/task09/run_20261109T091518633188Z/final_main_install_v4_verified_incremental/runner.json): một lần `adb install -r` v4, main UID10217/test UID10218 giữ nguyên; **97/97 file SHA exact sau install, trước launch**. Không dùng checkpoint QA5560 hoặc xin quyền destructive.
- [Sau walkthrough](../../build/verification/task09/run_20261109T091518633188Z/final_native_state_v1.json): vẫn97 file, **0 file mất**; chỉ `files/profileInstalled` đổi theo profile installer của Flutter/Android. Settings/drafts/journals/models/fixtures/evidence hiện có giữ hash. Installed APK SHA trùng v4.
- Installed base APK allocation49148KiB; private QA allocation844612KiB (~824.8MiB), gồm3 installed models, model import inputs, fixtures và evidence. APK download49–50 triệu byte khác private data/cache/build/AVD/workspace. Không gọi workspace106GB là dung lượng app.

## Compact QA APK v5 — đo trước/sau và verify

Raw incremental v4 còn dữ liệu ZIP không được central directory tham chiếu. Đã đo offsets/kích thước ở `apk_size_delta_v1.json` và `apk_alignment_padding_delta_v1.json`, giữ nguyên raw APK. Chạy `python <run>/compact_qa_apks_v1.py`: fresh ZIP từ live entries, Android SDK36 zipalign16KB, apksigner dùng cùng **debug** cert; không production signing. **231/231 payload entry SHA exact ở mỗi ABI**, signature verify và `verify_release.py` đều đạt.

| ABI | Raw v4 bytes | Compact v5 bytes | Giảm |
|---|---:|---:|---:|
| ARM64 | 48,538,842 | 36,368,722 | 25.07% |
| ARMv7 | 46,687,140 | 33,386,844 | 28.49% |
| x86_64 | 50,472,139 | 38,170,947 | 24.37% |

[Manifest](../../build/verification/task09/run_20261109T091518633188Z/compact_qa_v1_30c4fe01e8834da983f97937d07a2074/manifest.json), [backup + update giữ97/97 hash](../../build/verification/task09/run_20261109T091518633188Z/compact_v5_update_v1/runner.json), [native smoke3/3](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_6ecb079b491a42dd9f942718e147b930/trace.json). Main tabs/Create Back, real Editor native preview/Back và PhotoTools/Back hoạt động. Full host/native/output evidence v4 được reuse với proof live payload không đổi, không giả là chạy lại toàn bộ trên v5. Script smoke v1 đọc JSON bằng cp1252 thất bại trước thao tác; v2 dùng explicit UTF-8 và đạt, file v1 giữ nguyên.

[State cuối v5](../../build/verification/task09/run_20261109T091518633188Z/final_native_state_v2.json): APK SHA khớp compact manifest, main UID10217/test10218 giữ;97 file private,0 mất, chỉ framework profileInstalled đổi sau launch.3 model installed còn đủ;19 ASR jobs (16 completed/1 expected failed/2 cancelled),3 export jobs (2 completed/1 cancelled), không job active. Installed APK allocation37128KiB, private QA844612KiB. Không gộp models/fixtures/evidence vào download size.

## Performance và điều chưa thể kết luận

Cold main v4 native `am start -W`: TotalTime3582ms, WaitTime3600ms trong AVD/host này; không có controlled startup A/B để công bố tăng tốc. [HWUI gfxinfo](../../build/verification/task09/run_20261109T091518633188Z/final_native_gfxinfo_v1.log) chỉ có17 native frames,16 janky, p50=32ms/p95=150ms trên SwiftShader sau chuỗi start/navigation. Đây là **quan sát xấu cần giữ lại**, chưa đo được Flutter build/raster distributions hoặc native1k library. Không chuyển thành claim60fps, không gán percent regression/cải thiện từ hai workload khác nhau.

`final_native_exit_info_v1.log` ghi9 recent exits đều USER REQUESTED/FORCE STOP do QA/instrumentation; không thấy crash/ANR trong cửa sổ exit-info đó. Không suy ra toàn app không thể crash/ANR. Physical ARM/OEM/SD/real16KB, thermal/battery, camera/mic/capture, hard kill giữa save/export và human usability còn gate.

QA5560 tiếp tục giữ nguyên theo [TASK08 recovery status](TASK_08_DATA_RECOVERY_FINAL_STATUS.md). Không claim đã xác nhận lại guest ownership/grants/draft hoặc phục hồi transcript thiếu. Cần snapshot gốc/ủy quyền cụ thể mới để thao tác guest; SAF cần người dùng chọn lại folder thật khi được phép.
