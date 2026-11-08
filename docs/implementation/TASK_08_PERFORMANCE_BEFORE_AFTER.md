# TASK08 — Measured decoded thumbnail reuse

Checkpoint M1: hai viewport A/B PASS; đối chứng drift đang chạy. Overall task
vẫn PARTIAL vì các gates M2–M6 và sự cố dữ liệu QA chưa được nghiệm thu.

## Root cause và patch

Compressed thumbnail LRU đã giới hạn64entry/8MiB, nhưng mỗi reload sau eviction
trả một Uint8List mới. Image.memory/MemoryImage so buffer identity; Flutter
decoded cache giữ các bản decoded trùng, tới1000entry/~73MiB khi lặp cùng
working set. Native CPU trace và counters không chứng minh formatter ngày là
hot path (2/3046 CPU samples), nên không sửa sort/format/calendar/P1.

Regression đỏ `m1_decoded_key_red_v1.log` bắt chính xác ResizeImageKey khác nhau
với cùng PNG sau compressed eviction. `ThumbnailImage` giữ decoder MemoryImage
và ResizeImage hiện có, hash nội dung một lần khi future trả bytes, equality
kiểm exact bytes để tránh hash collision/stale pixel khi metadata URI thô.
Không tăng cache, không giảm resolution/filter quality, không predecode1000
ảnh, không thay native thumbnail/export/audio hoặc recording semantics.

Changed production: `lib/core/presentation/thumbnail_image.dart` và targeted
MediaThumbnail state trong `lib/features/media/media_library_screen.dart`.
Fixture consumer nhận provider trong future, tránh hash bytes mỗi build.
Các consumer thumbnail khác dùng cùng widget; regression kiểm revision và đổi
repository vẫn đọc lại bytes. Native pipeline và output fidelity kiểm tiếp M6.

## A/B cùng corpus/profile/workload

M0 method/device/raw paths được mô tả đầy đủ trong
[PERFORMANCE_BASELINE](TASK_08_PERFORMANCE_BASELINE.md). Cả hai cặp assert full
metadata/order hash giống nhau, native1013 rows, viewport/DPR/theme/locale
giống nhau;3warmup+5measured,30swipe mỗi lượt. CPU/PSS profiler overhead giữ cùng
phương pháp. P95 nearest-rank; bảng dùng median5 trial p95.

| Viewport | Build before→after ms | Raster before→after ms | Raster thay đổi | Decoded median entries / bytes |
|---|---|---|---|---|
|320dp |13.276→7.454 |42.101→22.856 |-45.71% |1000/76198208→15/1481248 |
|411.43dp |9.491→8.227 |42.151→26.242 |-37.74% |1000/76402976→15/1481248 |

Corpus có1013 identities nhưng17 payload byte khác nhau,15 payload decoded
trong working set. Mức giảm98% decoded bytes **chỉ áp dụng corpus này**; không
khái quát cho1000 ảnh thực khác nhau. Same-URI re-entry cũng có duplicate key
được test riêng, nên patch không chỉ tối ưu artificial filename duplicates.
Raster p95 còn trên16.67ms. Không gọi60fps hay hardware/GPU/OEM PASS.

Raw p50/p90/p95/p99 và >16.67/>33.33 counts từng trial đầy đủ trong:

- `build/verification/task08/performance/comparison_320_v1.json`
- `build/verification/task08/performance/comparison_411_v1.json`
- Before: `owned_before_320_attach/`, `owned_before_411/` dưới performance/.
- After: `owned_after_320_v1/`, `owned_after_411_v1/`, mỗi folder có raw frames,
  trial0 Dart/Embedder/GC trace, sampled CPU stack, memory.jsonl và runner.json.

APK before `M0-owned-corpus-x64-profile.apk`; after
`M1-decoded-cache-x64-profile-v1.apk`. Đây là benchmark entrypoints, không phải
main-entry delivery APK. APK trước được giữ nguyên để chạy drift control, không
dựng lại source từ HEAD/restore dirty file.

## Tests và giới hạn tại checkpoint

12 focused Flutter performance tests PASS (`m1_thumbnail_green_v2.log`). Test
decoded key thực hiện10 lần reload/eviction, đợi decoder hoàn tất rồi kiểm một
decoded entry; bytes/scale và symmetric equality với MemoryImage được kiểm.
Lượt green_v1 lỗi test do chưa đợi codec async (currentSize0), giữ log; sửa test
bằng ImageStream completion, không nới expectation. Thêm test RGBA resize parity
đang chờ chạy cùng regression sau đo, chưa đánh PASS trước bằng chứng.

Analyzer clean3.0s `m1_analyze_v2.log`; APK build-only PASS67.6s
`m1_profile_build_v1.log`. M1 không dùng Flutter install fallback; backup trước
adb-r, UID được giữ; source datasets và historical artifacts không xóa.

A/B chạy thứ tự theo phase trên shared Windows host, chưa randomize từng trial.
Đối chứng thêm baseline411 đang chạy `owned_drift_control_411_v1/` để xét host
drift. Five trials không đủ formal causal/thermal/physical FPS certification.
Peak PSS bao gồm VM CPU function-table transfer, không dùng riêng để claim leak
hoặc memory speedup. TASK07 comparison vẫn INCONCLUSIVE vì dataset/method khác.

## Checkpoint đối chứng drift hoàn tất

`performance/drift_control_411_v1.json`: baseline APK nguyên bản chạy lại đầy
đủ3warmup+5trial, cùng hash/order/native count/viewport. Median build/raster
p95 =7.124/40.104ms; decoded1000entry/76533792B. Baseline raster ban đầu42.151ms
chỉ drift−4.86%, trong khi bản sửa26.242ms. Điều này củng cố giữ patch cho giảm
redundant decode/raster, không chứng minh mọi GPU/thiết bị hoặc toàn bộ jank.

Build p95 baseline tự giảm24.94% theo thời gian, thậm chí thấp hơn bản sửa.
Vì vậy **không quy toàn bộ mức giảm build trong bảng A/B cho code**; riêng
build-speed effect là INCONCLUSIVE. Raster/decoded-cache có cải thiện đo được;
frame budget16.67ms vẫn chưa đóng. M1 chuyển sang M2, không tối ưu tiếp formatter
hoặc source P1 theo biến thiên shared host.
