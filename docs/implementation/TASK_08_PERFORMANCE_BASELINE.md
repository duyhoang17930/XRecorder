# TASK08 — M0 baseline có raw timings

Checkpoint08/11/2026. Baseline frame workload PASS trên hai viewport; final
PERFORMANCE gate vẫn OPEN chờ đo sau sửa. Không chứng nhận60fps/máy thật.

## Corpus và môi trường

- HEADb9aea926, working tree được chụp589 SHA ở đầu task.18 protected P1/shared
  hashes không đổi. Không checkout/reset/clean/commit/push.
- Flutter3.47.8/Dart3.13.7, AGP9.1.0, Gradle9.7.1, Media3 1.11.1,
  whisper.cpp1.9.5. Profile x86_64, Impeller/OpenGLES, SwiftShader60Hz giả lập.
- Windows shared host, Ryzen5 6600H,6core/12logical. Không dừng IDE/emulator
  cá nhân để cải thiện số đo. RAM/thermal host/device và noise cần phân biệt;
  PSS bên dưới là app process, không phải RSS toàn AVD.
- AVD mới `ThreeHRecorder_TASK08_API36`, serial5566, API36,4096B page,
  RAM3072MiB,4vCPU, data16GiB. Không dùng emulator5554. AVD5560 được giữ đĩa
  sau sự cố installer; xem DATA_SAFETY_REPORT, không coi recovery là complete.
-1013 bản sao byte-exact từ QA cũ,21907104B,17 SHA payload khác nhau, gồm
  một file0byte boundary. Giữ nguồn và các bản sao, không loại file lỗi để tăng
  metric. Native ContentResolver insert/publish/readback từng file xác nhận
  owner và SHA khớp host (`m0_owned_corpus_internal.txt`,
  `m0_owned_corpus_evidence.json`, `corpus_source_manifest.json`). Native catalog
  trả1013 app-owned rows;1013 source shadow do shell tạo không thuộc catalog.
- Corpus mới có IDs/timestamps/revisions mới. **Không đồng nhất với TASK07**.
  Baseline cũ1013/final1015 thiếu full order/dimensions nên so với TASK07 vẫn
  INCONCLUSIVE. Trong TASK08, full metadata+order hash giữa320/411 giống nhau:
  `3ef335eb6b6ca72a98fca670d4bc1394f70fbe27096d21f434a45e7ba9fae04f`.

## Phương pháp

Harness `integration_test/task08_performance_test.dart` thực sự gọi native
catalog/thumbnail, mount app và route Photos; không mock native repository.
Manifest giới hạn đúng1013 identities, assert không row bị thay/thiếu. Ghi đủ
URI,size,revision,created/modified,width/height,mime theo MediaSort hiện có.

Mỗi viewport: process mới, English/dark/font1,3 warmup rồi5 measured trials.
Mỗi lượt jump0, settle, chờ500ms,30 swipes600logical px/400ms/frequency60,
settle sau từng swipe. Reset offset giống nhau; không rescan MediaStore lúc
scroll. Cache compressed giữ64entry/8MiB. API traceAction Dart/Embedder/GC,
FrameTiming build/raster/totalSpan raw µs; CPU sampled ở trial0, function table
remap chỉ giữ các stack được sample. Không giảm chất lượng thumbnail/render.

Runner `run_qa_existing_app.py` attach host Dart driver; cài riêng bằng adb-r
với backup/capacity/UID checks, không dùng Flutter install fallback. PSS đọc
dumpsys mỗi5s, cùng overhead cho A/B. CPU query truyền toàn function table trước
khi compact nên peak PSS bao gồm profiler; query ở ngoài frame window. Một raw
trace/trial0 và raw frames của cả5 trials được giữ, tránh serialize5 full traces.

Percentile: nearest-rank `sorted[ceil(n*p)-1]`, không interpolation. Analyzer
`tool/analyze_task08_performance.py` ghi p50/p90/p95/p99, >16.67/>33.33ms từng
trial cho build/raster/totalSpan. Median dưới đây là median của5 trial p95,
không phải pooled p95; chỉ mô tả5 lượt trên shared host, không formal CI claim.

## Số đo trước sửa decoded-key

| Viewport | Physical/DPR | Build p95 các trial (ms) | Raster p95 các trial (ms) | Median build/raster |
|---|---|---|---|---|
|320dp |840×1920/2.625 |13.276,15.376,12.421,11.993,14.208 |42.101,44.943,36.801,41.080,43.319 |13.276/42.101 |
|411.43dp |1080×2400/2.625 |10.380,9.504,9.317,9.491,8.543 |42.151,45.225,42.756,41.853,41.084 |9.491/42.151 |

Decoded cache cả hai chạm1000 entries, median76.20/76.40MB; compressed reads208
mỗi measured trial. Working set cần đối chiếu: corpus có17 payload, nên không
khái quát mức dedup này cho1000 ảnh thực hoàn toàn khác nhau. Same-URI re-entry
cũng có duplicate decode do MemoryImage dùng buffer identity; regression đỏ
đã chứng minh, không suy ra chỉ từ số entries. Peak profiler-inclusive PSS:
599986KiB/367482KiB, không diễn giải riêng peak này là leak.

CPU320:3046 samples,39594 functions trả về/1486 referenced giữ lại. Clock/
timer/harness chiếm nhiều samples; calendarDate/_day chỉ2 samples, chưa đủ lý
do sửa formatter. GPU/raster SwiftShader vẫn là giới hạn cần xét với trace.

## Raw paths, APK và failures giữ lại

Tất cả paths tương đối `build/verification/task08/`:

- `performance/owned_before_320_attach/{emulator_verification.json,memory.jsonl,runner.json}`
- `performance/owned_before_411/{emulator_verification.json,memory.jsonl,runner.json}`
- `performance/baseline_320_v1.json`, `performance/baseline_411_v1.json`.
- APK `M0-owned-corpus-x64-profile.apk`, SHA256
  `0806d22a77257160ca5567878b583283e6caf6ec04ead87d1c6cf5fca4a75517`.

Các failure trước baseline được giữ nguyên: driver5min timeout; JSON transfer
OOM; SDK install fallback uninstall QA5560; PID startup race; early VM attach
disconnect (VM vẫn sống/PauseStart, attach lại thành công); shell-owned source
không nằm trong owner-filtered library và scoped-storage không đọc được nguồn
ADB. Không tính các lượt đó là timing PASS. Xem `m0_*`/`performance/*`.

`testMountToContentMs` chỉ đo mount→content trong test; **không phải Android
cold launch**. Android main-entry cold/warm launch còn cần kiểm riêng. Chưa có
physical FPS, GPU hardware/OEM/thermal hoặc P1 integration acceptance.
