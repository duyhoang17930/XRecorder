# Hiệu năng — 3HRecorder

Tóm tắt Task03 và regression Task03.1 ngày 06/11/2026. [METRICS.json](METRICS.json) giữ số đo rút gọn; raw artifact/log cũ nằm trong ZIP local `.claude-local/scratchpad/docs_cleanup_20261106/original_evidence.zip`. Đây là kết quả lịch sử, không chứng nhận source sau các thay đổi mới.

## Điều kiện đo

Flutter3.47.8/Dart3.13.7, profile AOT x86_64, API36; AVD riêng ThreeHRecorder_Task021/emulator-5560,1080×2400,density420,3GiB RAM/4vCPU/GPUhost. Library30-row fixture; capture, preview, export và screenshot native thật. Task03 BEFORE/AFTER3 vòng; Task03.1 chạy lại cùng harness3 vòng và một diagnostic90s.

FrameTiming gồm settle/250ms chờ timing; duration sequence không phải tap latency thuần. p95 nearest-rank, n3 thì p95=max. CPU sampler≈5s,100%=1core; PSS/RSS/heap là snapshot. Các lượt khác warmup/corpus/host load, không phải A/B causal tuyệt đối. [Phương pháp Flutter](https://docs.flutter.dev/tools/devtools/performance), [Android profiling](https://developer.android.com/studio/profile).

## Kết quả chính

| Metric | Trước Task03 | Sau Task03 | Sau Task03.1 |
|---|---:|---:|---:|
| Heartbeat sau capabilities median/p95 ms,n9 | 25.59/150.01 | 1.70/4.16 | 2.96/10.65 |
| Capture UI builds quay tĩnh≈8.4s,median | 33 | 8 | 8 |
| Capture UI builds paused≈3.4s,median | 13 | 0 | 0 |
| exportList khi idle≈5.4s,mỗi vòng | 5 | 0 | 0 |
| Thumbnail reads12 swipe,median | 46 | 27 | 27 |
| Decoded image cache sau scroll MiB,median | 10.99 | 6.81 | Xem JSON |
| Scroll build/raster p95 ms | 2.657/23.507 | 1.746/17.029 | 1.980/16.868 |
| Editor paused build/raster p95 ms | 4.130/31.293 | 1.594/25.055 | 1.376/18.115 |
| Editor entry build/raster p95 ms | 11.247/67.315 | 10.042/49.120 | 13.080/32.425 |

Giữ mọi raw capture event; chỉ giảm notification presentation theo state/giây hiển thị. Cache compressed thumbnail LRU64 entry/8MiB, invalidation theo media/memory pressure. Export polling theo active job/visibility; preview không phát vị trí/build trùng. Dò capabilities chuyển worker, reply main và dispose pending callbacks. Không sửa encoder/audio/muxer/preset vì số FPS emulator.

## Số đo bất lợi và giới hạn

- Startup lần đo đầu Task03 median2981→4128ms; crossover cùng corpus1967→1918ms. Warm crossover23→24ms. Không gọi là tối ưu startup; Task03.1 không đo lại startup.
- CPU/RSS không đồng loạt giảm: diagnostic90s Task03 CPU57→67%,RSS278.89→300.48MiB; Task03.1 CPU64%,RSS291.32MiB. Production idle crossover Task03 CPU0% cả hai, RSS235.91→235.76MiB. FullyLive render cadence/GC/harness retention khác nhau; không suy thành giảm pin hoặc hết leak.
- Native pause RPC Task03 median32.12→71.44ms, p9556.11→93.90ms; vẫn chuyển state/lưu đúng. Không tuyên bố mọi latency cải thiện.
- Decode Task03:12 MP4; Task03.1:6 MP4, không lỗi và PTS tăng. Recording H.264720×1280,mute; export mặc định1280×720+AAC; PNG1080×2400. Vẫn có frame gap; avgFPS/track audio không bảo đảm FPS chính xác hoặc A/V sync.
- Native screenshot cleanup được xác minh. 90s không phải soak nhiều giờ; chưa kiểm OEM/máy thật,battery/thermal/protected content. Finalizing label Saving… thêm sau APK profile Task03.1, widget-tested riêng.

## Chạy lại

`tool/verify_ui.ps1 -Mode performance -BuildMode profile` và host helper dùng output mặc định `build/verification/performance/task03/`; ảnh/log UI vào `build/verification/ui/`. Host log vẫn đọc từ `.claude-local/scratchpad/task03/after-run.log` theo phase. Dùng `-ArtifactDirectory`/`--artifact-directory` để chọn đợt riêng và luôn giữ APK BEFORE trước khi sửa source. Không ghi dump mới vào docs.

Chỉ chạy trên AVD đã xác minh, giữ `--keep-app-running`, không uninstall/clear-data hay xóa media test. Sau integration cài lại APK `lib/main.dart` bằng install-r. Kết quả app/UX và kế hoạch thử máy thật: [UI docs](../ui/README.md).
