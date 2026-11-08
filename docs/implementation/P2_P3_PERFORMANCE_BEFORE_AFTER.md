# P2/P3 — đo trước và sau, 07/11/2026

Baseline source `b9aea926c1ab024dd32a139e5ab43b0e0e584908`. Kết quả dưới đây
được đo trên source đang sửa, không phải chứng nhận production hay máy thật.

## Library: cùng workload, ba lượt mỗi phía

Flutter3.47.8 profile, API36 x86_64, AVD ThreeHRecorder_Task021, SwiftShader,
1080×2400, density420, 1009 ảnh giữ nguyên fingerprint. Mỗi lượt 30 drag400ms
ở60Hz. Host giữ các raw FrameTiming và VM timeline Dart/Embedder/GC.

| Lượt | Frames | Build p95 ms | Raster p50 ms | Raster p95 ms | Raster >16,67ms |
|---|---:|---:|---:|---:|---:|
| Trước1 |621|7,181|20,348|43,711|401|
| Trước2 |635|6,268|20,535|40,386|396|
| Trước3 |612|12,088|23,474|45,366|421|
| Sau1 |616|6,864|19,481|40,196|362|
| Sau2 |635|7,288|18,144|41,250|346|
| Sau3 |628|6,001|18,297|40,515|355|

Thay đổi: `media_library_screen.dart` bỏ outer clip của card ở list view;
thumbnail vẫn tự clip và InkWell có borderRadius khớp card. Không đổi dữ liệu,
observer, cache limits, typography hay P1. Trace tập trung thời gian tại
GPURasterizer::Draw / SurfaceFrame::Submit trên software GPU; không có bằng chứng
để rewrite renderer hay thay recording encoder.

Median của **p95 từng lượt**:43,711→40,515ms, giảm khoảng7,3%. Range trước
40,386–45,366ms và sau40,196–41,250ms chồng lấn. Thứ tự trước→sau, cache warm,
host scheduling và software GPU là confounders; ba lượt không đủ tách causal
effect khỏi mọi nhiễu. **Chưa đạt budget60fps trên AVD.** Không so causal với
benchmark lịch sử1006 ảnh hoặc test instant drag/pumpAndSettle khác workload.

Decoded image cache cả sáu lượt:21.189.216bytes; compressed cache giữ bounds
64entry/8MiB. Việc bỏ clip không làm decoded cache tăng trên workload này.
VM timeline là ring buffer; counts Draw có thể ít hơn FrameTiming đã thu.

Evidence local: `build/verification/final_p2_p3/performance/` gồm
`before_1..3/emulator_verification.json`, `after_1..3/emulator_verification.json`,
`before_summary.json`, `comparison.json`; logs `profile_before_*.log`,
`profile_after_*.log`. Baseline binary giữ tại `baseline-profile.apk`.
Harness: `integration_test/p2_p3_library_profile_test.dart`.

## Correctness và thời gian AI

Không tối ưu bằng cách cắt transcript hay dùng mock. JNI đo riêng model load
và inference bằng monotonic clock; native progress phân biệt loading/recognizing.
38 job corpus hoàn thành, trong đó35 inference và3 silence fast-path. Xem
[AI evaluation](P2_P3_AI_SUBTITLE_EVALUATION.md) cho subset và cách tính.

Sampled PSS cao nhất610.099KiB trong222 samples, gồm cả allocator/cache của
process. Tiny/base/small-q5_1 phase peaks421.845/494.785/610.099KiB;
đây không phải incremental model RAM hoặc allocation peak chính xác. Median
model-load173/320/424ms là các lượt đã warm file cache, không phải cold boot.
Sampler dumpsys/VM có overhead và có thể kích GC. Không đo thermal/battery.

## Preview và vòng đời

Tái hiện trước: player position500ms, error=null nhưng screenshot preview đen.
Thử transparent shutter không sửa được, đã bỏ thay đổi đó. Đổi Flutter platform
view từ virtual-display fallback sang `initSurfaceAndroidView` để SurfaceView
fallback hybrid composition đã hiện đúng frame. Media3 composition/DSP giữ nguyên.

Portrait display dimensions được lấy qua catalog worker (EXIF/video rotation đã
normalize), rồi áp crop/clip rotation hoặc project aspect. Không dựa vào
CompositionPlayer1.11 default graph videoSize0×0. Có generation guard cho
metadata/poll cũ. Preview cao tối đa40% viewport, giữ không gian cho controls.
Ở411dp, portrait view231,43px logical cao trước→365,71 sau, aspect9:16;
ảnh trước/sau dưới `matrix/portrait_*.png`. `portrait_before.png` có System UI
ANR che nên **không dùng** làm ảnh UI đạt; `portrait_before_clean.png` là before.

API34 warm native preview cũng hiện đúng portrait frame ở500ms. Capture đầu sau
async resize có overlay cũ; harness chờ real wall-clock frames/pump-settle cho ảnh
sạch, không đổi product code để làm đẹp ảnh. `api34_preview.png` giữ attempt đầu,
`api34_preview_settled.png`/`api34/preview_settled` là steady-state proof.

Soak trước khi đổi platform-view:30 preview create/play/seek/dispose và20
Transformer export/cancel PASS, source bytes giữ nguyên.35 memory samples,
PSS130.796→164.633KiB, peak170.817KiB. Mức tăng gồm codec/allocator warm-up;
không đủ kết luận không leak. Report `soak/native/emulator_verification.json`,
`soak_memory.json`.

Regression hybrid đầu: assertions activeViews/cancel đạt nhưng log có một lần
player release timeout, max dispose5132ms. Chỉ đếm view0 **không đủ** để xác nhận
release đúng. Thử đảo release/detach vẫn FAIL native release assertion, giữ log
`soak_release_order.log`. Bản sửa cuối pause+stop trước detach/release, và chỉ
allocate CompositionPlayer khi có composition hợp lệ (tránh upstream never-loaded
release path):30 preview/20 export-cancel PASS, releaseFailures0, median/max
dispose489,5/741ms. Evidence `soak/stopped/`, `soak_stopped.log`.

Sampled current-process PSS254949→358975KiB, peak376231KiB trong21 samples;
không dùng2 sample của PID cũ để so. Debug retained heap sau explicit development
GC104291264→95156992bytes. Class/instance inspection thấy139 UTF-16 strings,
11.471.970 ký tự;11.436.969 ký tự thuộc chuỗi có prefix copyright/source Dart/Flutter.
Đây là một phần chi phí debug VM, không phải chứng minh mọi native allocation
đều không leak. Raw `soak_stopped_memory.json`, `soak_stopped_retained.json`,
`soak_retained_strings.json`. Sampler đã sửa chọn host-forwarded VM port thay
device port; retained-heap snapshot được thu riêng khi endpoint còn sống.

ASR cancel: cùng QA task đo request/worker drain+next silence decode trước
2/9616ms, sau8/518ms. Callback trước chỉ được kiểm sau cả encoder graph; local
whisper.cpp patch truyền abort callback tới CPU graph nodes. Chín job vi/en/auto
trên cả ba model vẫn PASS sau patch. Một cặp observations không phải p95 latency
trên máy thật; model load trước khi abort vẫn cần hoàn tất. Evidence
`asr/faults/` và `asr/faults_after/`, source/provenance trong third_party/UPSTREAM.md.

## Phân loại còn lại

- **Implemented and verified now:** bounded list clipping, frame/cache comparison,
  stale poll/metadata guard, native frame hiển thị và portrait geometry.
- **Implemented but not independently verified:** performance ở các GPU/OEM khác;
  hỗ trợ giải phóng resources ngoài các workload đã chạy.
- **Not implemented:** không tạo renderer mới hay memory profiler trong product;
  không cần để sửa các lỗi đã tái hiện.
- **External gates:** máy thật60Hz, sustained10-minute inference, thermal/battery,
  human perception và TalkBack gesture. Cần máy thử được cấp quyền, không dùng
  emulator cá nhân thay thế.
