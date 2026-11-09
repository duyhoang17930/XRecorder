# TASK08 — Memory / native lifecycle / thermal

## Final GC soak — loại observer retention của harness

`memory/library_ar_light_200_v2/emulator_verification.json`:10vòng×30swipe,
1013rows frozen,Arabic/Light;MediaQuery đo textScale **2.0** thực. Full allocation
profiles được ghi ra file riêng,driver chỉ giữ compact nonzero class summaries.
3raw profiles đã copy với SHA device/host exact tại
`m6_allocation_raw_20261109T061022400657Z/summary_v1.json`.

Sau GC vòng1/5/10,heap **21767408→22313216→22727072B**;external356592B
không đổi. Delta959664B gồm compact summaries và270test pointer records;
không còn mức tăng~27MB do giữ full profilerDTO của v1. Không so đây là
production optimization A/B:đã sửa measurement harness và xác nhận textScale.
Decoded **16entries/1557056B** ở cả10vòng;compressed64/269248B. Retained
ResizeImageKey17,ThumbnailImage25,ImageInfo26,_Image16 đều giữ nguyên tại1/5/10.
PASS bounded images trong workload;không chứng nhận whole-app/native leak-free.
V1 và giới hạn native/physical bên dưới vẫn được giữ đầy đủ.

## Currentv5 — preview vàRAM đã kiểm lại

Native preview phát hiện endpoint guard trả duration clamp khiến Media3 xem
là speed effect không hỗ trợ;SDK dùng probe1000000000us. Giữ identity time
mapping của các sample hợp lệ,cap chỉ tail vượt timeline;unit gọi actual
`TransformerUtil.containsSpeedChangingEffects` bảo vệ contract này.
Primary source: [Media3 TransformerUtil 1.11.1](https://github.com/androidx/media/blob/1.11.1/libraries/transformer/src/main/java/androidx/media3/transformer/TransformerUtil.java).

`m2_preview_reload_16kb_v3_report.json`:synchronous reload fail sau4cycles,
2release failures. Refactor shared asynchronous drain/release cho reload và
dispose,guard loading/disposed,không lấy late error của player cũ gán sang
player mới. `m2_preview_reload_16kb_v4_report.json`:**30reload/seek thật**,
8tracks/RNNoise,actualSurfaceframes,0active/0failures. Median load→frame+seek
1165.5ms,p952972ms;không so như isolated speed A/B vì baseline fail sớm.
`m6_preview_dispose_race_v1_report.json`:overlap bị reject,pending load sau
dispose bị reject,không resurrect player,callback nhận đủ,timeline4000ms.
API34/API36 currentv5 kiểm lại cùng lifecycle cases.

`m2_tiny_ten_cycles_report_v1.json`:10JNI inference/unload completed;
boundary PSS81408–84147KiB,native allocated5724752–5737168B. Đây là bounded
native observations ở workload này,không phải mọi flow leak-free.

16KB currentv5 actualforeground3GiB Tiny PASS.2GiB configured,OS2061701120B:
`m4_16kb_foreground_2g_v2_report.json`,Flutter content verified,available
949915648B vsrequired765475328B;load339ms/inference3354ms,completed thật.
Không gọi đây là low-memory rejection. Cold-boot attempt trước đó bị LMK
importance400/RSS130MB trước tạo speech fixture;raw exit-info giữ nguyên.
Đưa Activity foreground trước UiAutomation và boot đã ổn định cho lượt sau.
Không xóa failure cũ hoặc chứng nhận mọi2GiB cold-start/ASR workflow.

Final13audio outputs từuniversalv5 được decode/signals/PTS lại:
`m6_audio_final_v5/`,8trackdrift30.708ms,RNNoise SI-SDR+8.040dB,
flash/tone0ms tại độ phân giải oracle. Edited composition→ASR currentv5 PASS.
Các checkpoint phía dưới giữ nguyên để truy vết thời điểm trước các sửa này.

## Cập nhật sau kiểm tra độc lập audio

`m2_audio_limit_native_v2.log`:13 native re-exports PASS trên main QA v3.
`m2_outputs_audio_v2/signal_validation.json`:8-track A/V duration difference
**80.708→30.708ms**, không đổi tolerance80ms; PCM192960 decoded samples
(AAC padding được báo riêng, không gọi bit-exact192000). RNNoise SI-SDR
−5.003→3.037dB, cải thiện8.040dB; fade/volume/voice/trim/offset và timed-layer
pixel gates PASS. Flash/tone cùng1.000s, difference0ms ở độ phân giải10ms
window/30fps; không phải human lip-sync. Tất cả13 file full-decode/strictPTS
PASS. Bản fix xử lý EMPTY_BUFFER alias trong mixer drain, có unit regression.
Native failure trước đó giữ tại `m2_audio_limit_native_failure_v1.log`.

Các đoạn phía dưới là checkpoint trước revalidation; trạng thái audio hiện
đã PASS ở môi trường này. Native allocation leak/physical/RAM gates vẫn riêng.

Checkpoint09/11/2026. Actual API36 x86_64,4096B pages,3072MiB configured RAM,
SwiftShader/Impeller, profile AOT. Shared Windows host; không thay máy thật.

## Library / preview

- `memory/library_ar_light_200_v1/`: Arabic/Light/text200,10 vòng×30swipe.
  Decoded15entries/1481248B ở cả10 vòng. SauGC tại1/5/10: ResizeImageKey16,
  ThumbnailImage24,ImageInfo24,_Image15, không tăng. Heap21.5→35.0→48.4MB;
  harness giữ3 allocation profiles lớn và pointer records, nên **whole-app
  leak verdict INCONCLUSIVE**. Không dùng peakPSS301002KiB để gọi leak.
- `memory/editor_soak_v2/` và `editor_soak_without_profiler_v1/`: Media3
  release timeout tái hiện cả có/không sampler. Drain playback looper trước
  release trong dispose đã PASS30preview/20export-cancel ở
  `editor_soak_v3_offline_checkpoint_v1/`: active0,releaseFailures0,
  sourcePreserved=true. Dispose median605ms,p954462ms,max4520ms.
- V3 editor PSS first/peak/last88552/136866/117577KiB; threads29/50/38.
  Sampled process observations, không phải native allocation snapshot hoặc
  bằng chứng mọi reload/SurfaceView/OEM đã leak-free. Latency dài vẫn OPEN.

## Whisper thật —9 multilingual jobs + cancel +10min

Raw: `memory/combined_media_memory_v3/emulator_verification.json`,
`memory.jsonl`; input SHA ở `fixture_manifest_v2.json` và
`m2_long_input_device_v1.json`. `m2_asr_memory_summary_v2.json` dùng **duration
waveform thực**: JFK11s,VI11.34s. Summaryv1 dùng request-bound16s choVI nên RTF
cũ không dùng; evidencev1 được giữ.

| Model | Model load EN/VI/Auto(ms) | Inference EN/VI/Auto(ms) | Sampled peakPSS(MiB) |
|---|---|---|---|
| Tiny |1297/539/193|15197/7541/11441|243.82|
| Base |345/500/304|16340/15054/29034|330.45|
| Small-q5_1 |652/596/455|32322/34226/63286|440.33|

Model load tách inference, mỗi job tạo/hủy native context; OS page cache đã
ấm ở các lượt sau. Không gọi đây là benchmark giữ model resident. Sampler5s
có overhead và bỏ lỡ peak giữa samples. PrivateDirty+Clean/CPU/thread samples
được giữ trong JSON; không diễn giải chúng thành retained-allocation proof.

- Import checksum, invalid import, cancel mid-copy giữ Tiny đã verified:
  PASS; không xóa model đang dùng; silence không transcript.
- Cancel request14ms; cancel-drain + next decode601ms; cancelled job không
  hồi sinh. Đây là thực thi JNI, không mock/paid API.
- Input600000ms lặp waveform FLEURS licensed để stress memory, không phải
  hội thoại tự nhiên10min. Tiny hoàn tất: modelLoad136ms,inference166443ms,
  elapsed178325ms,57cue,lastEnd600000ms; request600001ms bị reject.
  RTF0.277 trên waveform này; có Gradle compile trên shared host trong lượt
  dài. Không ngoại suy accuracy/RTF/thermal cho nội dung hoặc máy khác.

## Audio / remaining gates

13 output đã export và full-decode/PTS PASS, nhưng independent signal gate
phát hiện8-track audio4.080708s so với video4.000000s, vượt80ms. Không tăng
tolerance. Thử PCM endpoint limit chung preview/export/ASR; native re-export
phát hiện empty-buffer alias lúc mixer drain. Targeted guard + unit regression
đã thêm; native revalidation đang tiếp tục, chưa gọi audio gate DONE tại đây.
Các failure và APKv1/v2 giữ nguyên.

2GiB/16KB LOW_MEMORY kill của TASK07 vẫn là failure lịch sử. TASK08 chưa chạy
lại đúng2GiB tại checkpoint này; không lấy3GiB thành PASS2GiB. ARM64/ARMv7,
real thermal/battery/OEM vẫn NOT RUN. Nhiệt emulator không đại diện thiết bị
thật. Memory toàn task **PARTIAL**, kể cả khi bounded thumbnail/player cases
đạt; xem TEST_EVIDENCE và FINAL_REPORT cho checkpoint nghiệm thu cuối.
